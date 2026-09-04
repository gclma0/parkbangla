import { BadRequestException, Injectable } from '@nestjs/common';
import { BookingStatus, BookingType, Prisma } from '@prisma/client';
import { PrismaService } from './prisma.service';
import { availabilityCoversBooking, blockConflictsWithBooking, bookingsConflict, commissionOn, isValidHHMM } from './booking-rules';
import { FcmService } from './fcm.service';

const PENDING_EXPIRY_MINUTES = Number(process.env.PENDING_BOOKING_EXPIRY_MINUTES ?? 30);

@Injectable()
export class BookingsService {
  constructor(
    private prisma: PrismaService,
    private fcm: FcmService,
  ) {}

  private assertDateWindow(startDate: Date, endDate: Date) {
    if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime()) || startDate > endDate) {
      throw new BadRequestException('Invalid booking date range');
    }
  }

  private assertTimeWindow(startTime: string, endTime: string) {
    if (!isValidHHMM(startTime) || !isValidHHMM(endTime) || startTime === endTime) {
      throw new BadRequestException('Invalid booking time window');
    }
  }

  private assertWeekdays(weekdays: number[]) {
    if (!Array.isArray(weekdays) || weekdays.length === 0 || weekdays.some((d) => !Number.isInteger(d) || d < 0 || d > 6)) {
      throw new BadRequestException('Weekdays must contain values from 0 to 6');
    }
  }

  private async assertVehicleBelongsToRenter(renterId: string, vehicleId?: string) {
    if (!vehicleId) return;
    const vehicle = await this.prisma.vehicle.findFirst({ where: { id: vehicleId, userId: renterId } });
    if (!vehicle) throw new BadRequestException('Vehicle not found');
  }

  private assertAmount(amount: number) {
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('Invalid booking amount');
    }
  }

  private pendingExpiryCutoff(now = new Date()) {
    return new Date(now.getTime() - PENDING_EXPIRY_MINUTES * 60 * 1000);
  }

  private conflictWhere(spotId: string, cutoff = this.pendingExpiryCutoff()): Prisma.BookingWhereInput {
    return {
      spotId,
      OR: [
        { status: { in: [BookingStatus.CONFIRMED, BookingStatus.ACTIVE] } },
        { status: BookingStatus.PENDING, createdAt: { gte: cutoff } },
      ],
    };
  }

  async expirePendingBookings(spotId?: string) {
    const expired = await this.prisma.booking.findMany({
      where: {
        ...(spotId ? { spotId } : {}),
        status: BookingStatus.PENDING,
        createdAt: { lt: this.pendingExpiryCutoff() },
      },
      select: { id: true, renterId: true, amount: true },
    });
    if (expired.length === 0) return;

    await this.prisma.$transaction(async (tx) => {
      for (const booking of expired) {
        await tx.booking.update({
          where: { id: booking.id },
          data: { status: BookingStatus.CANCELLED },
        });
        await tx.user.update({
          where: { id: booking.renterId },
          data: { walletBalance: { increment: booking.amount } },
        });
        await tx.walletLedger.create({
          data: { userId: booking.renterId, amount: booking.amount, reason: 'Expired booking request refund', bookingId: booking.id },
        });
        await tx.transaction.create({
          data: {
            bookingId: booking.id,
            userId: booking.renterId,
            amount: booking.amount,
            method: 'wallet',
            type: 'REFUND',
          },
        });
      }
    });
  }

  private assertSpotAvailableForWindow(
    spot: {
      availability: { weekdays: number[]; startTime: string; endTime: string }[];
      blocks: { startAt: Date; endAt: Date }[];
    },
    window: { startDate: Date; endDate: Date; weekdays: number[]; startTime: string; endTime: string },
  ) {
    if (!availabilityCoversBooking(spot.availability, window)) {
      throw new BadRequestException('Spot is not available for that schedule');
    }
    if (spot.blocks.some((block) => blockConflictsWithBooking(block, window))) {
      throw new BadRequestException('Host blocked this window');
    }
  }

  private async assertNoConflictingBooking(
    tx: Pick<Prisma.TransactionClient, 'booking'>,
    params: { spotId: string; startDate: Date; endDate: Date; weekdays: number[]; startTime: string; endTime: string },
  ) {
    const existing = await tx.booking.findMany({ where: this.conflictWhere(params.spotId) });
    const clash = existing.some((b) =>
      bookingsConflict(b, {
        startDate: params.startDate,
        endDate: params.endDate,
        weekdays: params.weekdays,
        startTime: params.startTime,
        endTime: params.endTime,
      }),
    );
    if (clash) throw new BadRequestException('This spot is already booked for that window');
  }

  async createPass(params: {
    renterId: string;
    spotId: string;
    vehicleId?: string;
    startDate: Date;
    endDate: Date;
    weekdays: number[];
    startTime: string;
    endTime: string;
  }) {
    this.assertDateWindow(params.startDate, params.endDate);
    this.assertTimeWindow(params.startTime, params.endTime);
    this.assertWeekdays(params.weekdays);
    await this.assertVehicleBelongsToRenter(params.renterId, params.vehicleId);
    await this.expirePendingBookings(params.spotId);

    const spot = await this.prisma.parkingSpot.findUnique({
      where: { id: params.spotId },
      include: { availability: true, blocks: true },
    });
    if (!spot || !spot.active) throw new BadRequestException('Spot unavailable');
    if (spot.hostId === params.renterId) throw new BadRequestException('You cannot book your own spot');

    const requestedWindow = {
      startDate: params.startDate,
      endDate: params.endDate,
      weekdays: params.weekdays,
      startTime: params.startTime,
      endTime: params.endTime,
    };
    this.assertSpotAvailableForWindow(spot, requestedWindow);

    const months =
      (params.endDate.getTime() - params.startDate.getTime()) / (1000 * 60 * 60 * 24 * 30);
    const amount = Math.max(spot.monthlyPrice, Math.round(spot.monthlyPrice * Math.max(months, 0.5)));
    this.assertAmount(amount);

    const renter = await this.prisma.user.findUnique({ where: { id: params.renterId } });
    if (!renter || renter.walletBalance < amount) {
      throw new BadRequestException('Insufficient wallet balance');
    }

    const pin = String(Math.floor(1000 + Math.random() * 9000));
    const qrToken = `pb_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
    const status = spot.autoApprove ? BookingStatus.CONFIRMED : BookingStatus.PENDING;

    const booking = await this.prisma.$transaction(
      async (tx) => {
        await this.assertNoConflictingBooking(tx, { spotId: params.spotId, ...requestedWindow });
        await tx.user.update({
          where: { id: params.renterId },
          data: { walletBalance: { decrement: amount } },
        });
        const booking = await tx.booking.create({
          data: {
            spotId: params.spotId,
            renterId: params.renterId,
            vehicleId: params.vehicleId,
            startDate: params.startDate,
            endDate: params.endDate,
            weekdays: params.weekdays,
            startTime: params.startTime,
            endTime: params.endTime,
            amount,
            pin,
            qrToken,
            status,
          },
          include: { spot: { include: { host: true } } },
        });
        await tx.walletLedger.create({
          data: { userId: params.renterId, amount: -amount, reason: 'Commuter Pass', bookingId: booking.id },
        });
        await tx.transaction.create({
          data: {
            bookingId: booking.id,
            userId: params.renterId,
            amount,
            method: 'wallet',
            type: 'CHARGE',
          },
        });
        const commission = commissionOn(amount);
        const hostNet = amount - commission;
        if (status === BookingStatus.CONFIRMED) {
          await tx.user.update({
            where: { id: spot.hostId },
            data: { walletBalance: { increment: hostNet } },
          });
          await tx.walletLedger.create({
            data: { userId: spot.hostId, amount: hostNet, reason: 'Pass payout', bookingId: booking.id },
          });
          await tx.transaction.create({
            data: {
              bookingId: booking.id,
              userId: spot.hostId,
              amount: hostNet,
              method: 'wallet',
              type: 'PAYOUT',
            },
          });
          await tx.transaction.create({
            data: {
              bookingId: booking.id,
              userId: spot.hostId,
              amount: commission,
              method: 'platform',
              type: 'COMMISSION',
            },
          });
        }
        return booking;
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );

    try {
      const renter = await this.prisma.user.findUnique({ where: { id: params.renterId } });
      const spot = await this.prisma.parkingSpot.findUnique({ where: { id: params.spotId } });
      if (renter && spot) {
        await this.fcm.sendNotification({
          userId: spot.hostId,
          title: booking.status === BookingStatus.CONFIRMED ? 'New Commuter Pass' : 'Booking request',
          body: `${renter.name} booked your spot at ${spot.address}`,
          bookingId: booking.id,
          type: booking.status === BookingStatus.CONFIRMED ? 'BOOKING_ACCEPTED' : 'BOOKING_REQUESTED',
        });
        await this.fcm.sendNotification({
          userId: params.renterId,
          title: booking.status === BookingStatus.CONFIRMED ? "It's a park!" : 'Request sent',
          body:
            booking.status === BookingStatus.CONFIRMED
              ? `Your pass at ${spot.area} is confirmed`
              : 'Waiting for host approval',
          bookingId: booking.id,
          type: booking.status === BookingStatus.CONFIRMED ? 'BOOKING_ACCEPTED' : 'BOOKING_REQUESTED',
        });
      }
    } catch (e) {
      console.error('Error sending createPass notifications:', e);
    }

    return booking;
  }

  async createInstant(params: {
    renterId: string;
    spotId: string;
    vehicleId?: string;
    startDate: Date;
    endDate: Date;
    startTime: string;
    endTime: string;
    isHourly: boolean;
    hoursEstimated: number;
    daysEstimated: number;
  }) {
    this.assertDateWindow(params.startDate, params.endDate);
    this.assertTimeWindow(params.startTime, params.endTime);
    if ((params.isHourly && params.hoursEstimated <= 0) || (!params.isHourly && params.daysEstimated <= 0)) {
      throw new BadRequestException('Estimated duration is required');
    }
    await this.assertVehicleBelongsToRenter(params.renterId, params.vehicleId);
    await this.expirePendingBookings(params.spotId);

    const spot = await this.prisma.parkingSpot.findUnique({
      where: { id: params.spotId },
      include: { availability: true, blocks: true },
    });
    if (!spot || !spot.active) throw new BadRequestException('Spot unavailable');
    if (spot.hostId === params.renterId) throw new BadRequestException('You cannot book your own spot');

    const requestedWindow = {
      startDate: params.startDate,
      endDate: params.endDate,
      weekdays: params.isHourly ? [params.startDate.getUTCDay()] : [0, 1, 2, 3, 4, 5, 6],
      startTime: params.startTime,
      endTime: params.endTime,
    };
    this.assertSpotAvailableForWindow(spot, requestedWindow);

    const amount = params.isHourly
      ? params.hoursEstimated * spot.hourlyPrice
      : params.daysEstimated * spot.dailyPrice;
    this.assertAmount(amount);

    const renter = await this.prisma.user.findUnique({ where: { id: params.renterId } });
    if (!renter || renter.walletBalance < amount) {
      throw new BadRequestException('Insufficient wallet balance');
    }

    const pin = String(Math.floor(1000 + Math.random() * 9000));
    const qrToken = `pb_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
    const status = spot.autoApprove ? BookingStatus.CONFIRMED : BookingStatus.PENDING;

    const booking = await this.prisma.$transaction(
      async (tx) => {
        await this.assertNoConflictingBooking(tx, { spotId: params.spotId, ...requestedWindow });
        await tx.user.update({
          where: { id: params.renterId },
          data: { walletBalance: { decrement: amount } },
        });
        const booking = await tx.booking.create({
          data: {
            spotId: params.spotId,
            renterId: params.renterId,
            vehicleId: params.vehicleId,
            type: BookingType.INSTANT,
            startDate: params.startDate,
            endDate: params.endDate,
            weekdays: requestedWindow.weekdays,
            startTime: params.startTime,
            endTime: params.endTime,
            amount,
            pin,
            qrToken,
            status,
          },
          include: { spot: { include: { host: true } } },
        });
        await tx.walletLedger.create({
          data: { userId: params.renterId, amount: -amount, reason: 'Instant booking hold', bookingId: booking.id },
        });
        await tx.transaction.create({
          data: {
            bookingId: booking.id,
            userId: params.renterId,
            amount,
            method: 'wallet',
            type: 'CHARGE',
          },
        });
        return booking;
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );

    try {
      const renter = await this.prisma.user.findUnique({ where: { id: params.renterId } });
      const spot = await this.prisma.parkingSpot.findUnique({ where: { id: params.spotId } });
      if (renter && spot) {
        await this.fcm.sendNotification({
          userId: spot.hostId,
          title: booking.status === BookingStatus.CONFIRMED ? 'New Instant Booking' : 'Booking request',
          body: `${renter.name} booked your spot at ${spot.address}`,
          bookingId: booking.id,
          type: booking.status === BookingStatus.CONFIRMED ? 'BOOKING_ACCEPTED' : 'BOOKING_REQUESTED',
        });
        await this.fcm.sendNotification({
          userId: params.renterId,
          title: booking.status === BookingStatus.CONFIRMED ? "It's a park!" : 'Request sent',
          body:
            booking.status === BookingStatus.CONFIRMED
              ? `Your booking at ${spot.area} is confirmed`
              : 'Waiting for host approval',
          bookingId: booking.id,
          type: booking.status === BookingStatus.CONFIRMED ? 'BOOKING_ACCEPTED' : 'BOOKING_REQUESTED',
        });
      }
    } catch (e) {
      console.error('Error sending createInstant notifications:', e);
    }

    return booking;
  }

  async decide(hostId: string, bookingId: string, approve: boolean, reason?: string) {
    await this.expirePendingBookings();
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { spot: true },
    });
    if (!booking || booking.spot.hostId !== hostId) throw new BadRequestException('Not found');
    if (booking.status !== BookingStatus.PENDING) throw new BadRequestException('Already decided');
    if (booking.createdAt < this.pendingExpiryCutoff()) throw new BadRequestException('Booking request expired');
    if (!approve) {
      const rejectionReason = reason?.trim();
      if (!rejectionReason) throw new BadRequestException('Rejection reason is required.');
      await this.prisma.$transaction([
        this.prisma.booking.update({
          where: { id: bookingId },
          data: { status: BookingStatus.CANCELLED, decisionReason: rejectionReason },
        }),
        this.prisma.user.update({
          where: { id: booking.renterId },
          data: { walletBalance: { increment: booking.amount } },
        }),
        this.prisma.walletLedger.create({
          data: {
            userId: booking.renterId,
            amount: booking.amount,
            reason: 'Rejected refund',
            bookingId,
          },
        }),
      ]);

      try {
        await this.fcm.sendNotification({
          userId: booking.renterId,
          title: 'Booking declined',
          body: `Your booking request for ${booking.spot.area} was not accepted. Reason: ${rejectionReason}`,
          bookingId,
          type: 'BOOKING_REJECTED',
        });
      } catch (e) {
        console.error('Error sending decide decline notification:', e);
      }

      return { ok: true, status: 'CANCELLED' };
    }
    const isPass = booking.type === BookingType.COMMUTER_PASS;
    const commission = commissionOn(booking.amount);
    const hostNet = booking.amount - commission;
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({ where: { id: bookingId }, data: { status: BookingStatus.CONFIRMED, decisionReason: reason?.trim() || null } });
      if (isPass) {
        await tx.user.update({
          where: { id: hostId },
          data: { walletBalance: { increment: hostNet } },
        });
        await tx.walletLedger.create({
          data: { userId: hostId, amount: hostNet, reason: 'Pass payout', bookingId },
        });
        await tx.transaction.create({
          data: {
            bookingId,
            userId: hostId,
            amount: hostNet,
            method: 'wallet',
            type: 'PAYOUT',
          },
        });
        await tx.transaction.create({
          data: {
            bookingId,
            userId: hostId,
            amount: commission,
            method: 'platform',
            type: 'COMMISSION',
          },
        });
      }
    });

    try {
      await this.fcm.sendNotification({
        userId: booking.renterId,
        title: 'Booking accepted',
        body: `Your booking for ${booking.spot.area} has been accepted.`,
        bookingId,
        type: 'BOOKING_ACCEPTED',
      });
    } catch (e) {
      console.error('Error sending decide accept notification:', e);
    }

    return { ok: true, status: 'CONFIRMED' };
  }

  async cancel(userId: string, bookingId: string) {
    await this.expirePendingBookings();
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { spot: true },
    });
    if (!booking) throw new BadRequestException('Not found');
    if (booking.renterId !== userId && booking.spot.hostId !== userId) {
      throw new BadRequestException('Not allowed');
    }
    if (booking.status === BookingStatus.CANCELLED || booking.status === BookingStatus.COMPLETED) {
      throw new BadRequestException('Cannot cancel');
    }
    const refund = booking.amount * 0.8;
    await this.prisma.$transaction(async (tx) => {
      await tx.booking.update({ where: { id: bookingId }, data: { status: BookingStatus.CANCELLED } });
      await tx.user.update({
        where: { id: booking.renterId },
        data: { walletBalance: { increment: refund } },
      });
      await tx.walletLedger.create({
        data: { userId: booking.renterId, amount: refund, reason: 'Cancel refund 80%', bookingId },
      });
      if (booking.renterId !== userId) {
        // notification is created & sent by FcmService
      }
    });

    if (booking.renterId !== userId) {
      try {
        await this.fcm.sendNotification({
          userId: booking.renterId,
          title: 'Host cancelled',
          body: 'Your pass was cancelled. 80% refunded per policy.',
          bookingId: booking.id,
          type: 'BOOKING_CANCELLED',
        });
      } catch (e) {
        console.error('Error sending cancel notification:', e);
      }
    }

    return { ok: true, refund };
  }

  async checkInOrOut(
    userId: string,
    bookingId: string,
    kind: 'in' | 'out',
    pin?: string,
    qrToken?: string,
  ) {
    if (kind !== 'in' && kind !== 'out') throw new BadRequestException('Invalid check action');
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        spot: { include: { host: true } },
        checkIns: true,
      },
    });
    if (!booking) throw new BadRequestException('Booking not found');
    if (kind === 'in' && booking.status !== BookingStatus.CONFIRMED) {
      throw new BadRequestException('Only confirmed bookings can be checked in');
    }
    if (kind === 'out' && booking.status !== BookingStatus.ACTIVE) {
      throw new BadRequestException('Only active bookings can be checked out');
    }
    if (booking.checkIns.some((c) => c.kind === kind)) {
      throw new BadRequestException(`Booking already checked ${kind}`);
    }

    const okPin = pin && pin === booking.pin;
    const okQr = qrToken && qrToken === booking.qrToken;
    const isParty = userId === booking.renterId || userId === booking.spot.hostId;
    if (!isParty || (!okPin && !okQr && userId !== booking.renterId)) {
      throw new BadRequestException('Invalid PIN or QR code');
    }

    return this.prisma.$transaction(async (tx) => {
      const checkInRow = await tx.checkIn.create({
        data: { bookingId, kind },
      });

      await tx.notification.create({
        data: {
          userId: booking.spot.hostId,
          title: kind === 'out' ? 'Renter checked out' : 'Renter checked in',
          body: `Booking ${booking.id.slice(0, 8)}`,
        },
      });

      if (kind === 'in') {
        await tx.booking.update({
          where: { id: bookingId },
          data: { status: BookingStatus.ACTIVE },
        });
      } else {
        if (booking.type === BookingType.INSTANT) {
          const checkInTime = booking.checkIns.find((c) => c.kind === 'in')?.at ?? booking.createdAt;
          const checkOutTime = new Date();
          const diffMs = checkOutTime.getTime() - checkInTime.getTime();
          
          const isDaily = booking.startDate.toDateString() !== booking.endDate.toDateString();

          let actualAmount = 0;
          if (isDaily) {
            const actualDays = Math.max(1, Math.ceil(diffMs / (1000 * 60 * 60 * 24)));
            actualAmount = actualDays * booking.spot.dailyPrice;
          } else {
            const actualHours = Math.max(1, Math.ceil(diffMs / (1000 * 60 * 60)));
            actualAmount = actualHours * booking.spot.hourlyPrice;
          }

          const diff = actualAmount - booking.amount;

          if (diff > 0) {
            const renter = await tx.user.findUnique({ where: { id: booking.renterId } });
            if (!renter || renter.walletBalance < diff) {
              throw new BadRequestException('Insufficient wallet balance for extra duration');
            }
            await tx.user.update({
              where: { id: booking.renterId },
              data: { walletBalance: { decrement: diff } },
            });
            await tx.walletLedger.create({
              data: { userId: booking.renterId, amount: -diff, reason: 'Instant booking extra duration charge', bookingId },
            });
            await tx.transaction.create({
              data: {
                bookingId,
                userId: booking.renterId,
                amount: diff,
                method: 'wallet',
                type: 'CHARGE',
              },
            });
          } else if (diff < 0) {
            const refund = Math.abs(diff);
            await tx.user.update({
              where: { id: booking.renterId },
              data: { walletBalance: { increment: refund } },
            });
            await tx.walletLedger.create({
              data: { userId: booking.renterId, amount: refund, reason: 'Instant booking early checkout refund', bookingId },
            });
            await tx.transaction.create({
              data: {
                bookingId,
                userId: booking.renterId,
                amount: refund,
                method: 'wallet',
                type: 'REFUND',
              },
            });
          }

          const commission = commissionOn(actualAmount);
          const hostNet = actualAmount - commission;

          await tx.user.update({
            where: { id: booking.spot.hostId },
            data: { walletBalance: { increment: hostNet } },
          });
          await tx.walletLedger.create({
            data: { userId: booking.spot.hostId, amount: hostNet, reason: 'Instant booking payout', bookingId },
          });
          await tx.transaction.create({
            data: {
              bookingId,
              userId: booking.spot.hostId,
              amount: hostNet,
              method: 'wallet',
              type: 'PAYOUT',
            },
          });
          await tx.transaction.create({
            data: {
              bookingId,
              userId: booking.spot.hostId,
              amount: commission,
              method: 'platform',
              type: 'COMMISSION',
            },
          });

          await tx.booking.update({
            where: { id: bookingId },
            data: {
              status: BookingStatus.COMPLETED,
              amount: actualAmount,
            },
          });
        } else {
          await tx.booking.update({
            where: { id: bookingId },
            data: { status: BookingStatus.COMPLETED },
          });
        }
      }

      return checkInRow;
    });
  }
}
