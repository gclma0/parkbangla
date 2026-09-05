import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { BookingStatus } from '@prisma/client';
import { IsArray, IsDateString, IsOptional, IsString, IsBoolean, IsNumber } from 'class-validator';
import { AuthGuard } from './auth.guard';
import { BookingsService } from './bookings.service';
import { FcmService } from './fcm.service';
import { PrismaService } from './prisma.service';

class CreatePassDto {
  @IsString()
  spotId!: string;
  @IsOptional()
  @IsString()
  vehicleId?: string;
  @IsDateString()
  startDate!: string;
  @IsDateString()
  endDate!: string;
  @IsArray()
  weekdays!: number[];
  @IsString()
  startTime!: string;
  @IsString()
  endTime!: string;
}

class CreateInstantDto {
  @IsString()
  spotId!: string;
  @IsOptional()
  @IsString()
  vehicleId?: string;
  @IsDateString()
  startDate!: string;
  @IsDateString()
  endDate!: string;
  @IsString()
  startTime!: string;
  @IsString()
  endTime!: string;
  @IsBoolean()
  isHourly!: boolean;
  @IsNumber()
  hoursEstimated!: number;
  @IsNumber()
  daysEstimated!: number;
}

class ReviewDto {
  @IsString()
  toUserId!: string;
  @IsNumber()
  rating!: number;
  @IsOptional()
  @IsNumber()
  spotRating?: number;
  @IsOptional()
  @IsNumber()
  hostRating?: number;
  @IsOptional()
  @IsNumber()
  renterRating?: number;
  @IsOptional()
  @IsArray()
  tags?: string[];
  @IsOptional()
  @IsString()
  comment?: string;
}

@Controller()
@UseGuards(AuthGuard)
export class BookingsController {
  constructor(
    private bookings: BookingsService,
    private prisma: PrismaService,
    private fcm?: FcmService,
  ) {}

  @Post('bookings/commuter-pass')
  create(@Req() req: { user: { id: string } }, @Body() dto: CreatePassDto) {
    return this.bookings.createPass({
      renterId: req.user.id,
      spotId: dto.spotId,
      vehicleId: dto.vehicleId,
      startDate: new Date(dto.startDate),
      endDate: new Date(dto.endDate),
      weekdays: dto.weekdays,
      startTime: dto.startTime,
      endTime: dto.endTime,
    });
  }

  @Post('bookings/instant')
  createInstant(@Req() req: { user: { id: string } }, @Body() dto: CreateInstantDto) {
    return this.bookings.createInstant({
      renterId: req.user.id,
      spotId: dto.spotId,
      vehicleId: dto.vehicleId,
      startDate: new Date(dto.startDate),
      endDate: new Date(dto.endDate),
      startTime: dto.startTime,
      endTime: dto.endTime,
      isHourly: dto.isHourly,
      hoursEstimated: dto.hoursEstimated,
      daysEstimated: dto.daysEstimated,
    });
  }

  @Get('bookings')
  async list(@Req() req: { user: { id: string } }, @Query('role') role?: string) {
    await this.bookings.expirePendingBookings();
    if (role === 'host') {
      return this.prisma.booking.findMany({
        where: { spot: { hostId: req.user.id } },
        include: { spot: true, renter: { select: { id: true, name: true, phone: true, ratingAvg: true } } },
        orderBy: { createdAt: 'desc' },
      });
    }
    return this.prisma.booking.findMany({
      where: { renterId: req.user.id },
      include: { spot: { include: { host: { select: { id: true, name: true, ratingAvg: true } } } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  @Get('bookings/:id')
  async one(@Req() req: { user: { id: string; isAdmin?: boolean } }, @Param('id') id: string) {
    await this.bookings.expirePendingBookings();
    return this.prisma.booking.findFirst({
      where: req.user.isAdmin ? { id } : { id, OR: [{ renterId: req.user.id }, { spot: { hostId: req.user.id } }] },
      include: {
        spot: { include: { host: { select: { id: true, name: true, phone: true, ratingAvg: true, ratingCount: true } } } },
        renter: { select: { id: true, name: true, phone: true, ratingAvg: true, ratingCount: true } },
        checkIns: true,
        reviews: true,
        transactions: req.user.isAdmin === true,
      },
    });
  }

  @Post('bookings/:id/cancel')
  cancel(@Req() req: { user: { id: string } }, @Param('id') id: string) {
    return this.bookings.cancel(req.user.id, id);
  }

  @Post('bookings/:id/decide')
  decide(
    @Req() req: { user: { id: string } },
    @Param('id') id: string,
    @Body() body: { approve: boolean; reason?: string },
  ) {
    return this.bookings.decide(req.user.id, id, body.approve, body.reason);
  }

  @Post('bookings/:id/check')
  async check(
    @Req() req: { user: { id: string } },
    @Param('id') id: string,
    @Body() body: { kind: 'in' | 'out'; pin?: string; qrToken?: string },
  ) {
    return this.bookings.checkInOrOut(
      req.user.id,
      id,
      body.kind,
      body.pin,
      body.qrToken,
    );
  }

  @Post('bookings/:id/reviews')
  async review(
    @Req() req: { user: { id: string } },
    @Param('id') id: string,
    @Body() dto: ReviewDto,
  ) {
    const booking = await this.requireBookingParty(id, req.user.id);
    if (booking.status !== BookingStatus.COMPLETED) {
      throw new BadRequestException('Reviews are allowed only after completed bookings.');
    }
    const allowedTargets = [booking.renterId, booking.spot.hostId].filter((userId) => userId !== req.user.id);
    if (!allowedTargets.includes(dto.toUserId)) {
      throw new BadRequestException('Review target must be the other booking participant.');
    }
    const rating = Number(dto.rating);
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      throw new BadRequestException('Rating must be between 1 and 5.');
    }
    const spotRating = this.optionalRating(dto.spotRating, 'Spot rating');
    const hostRating = this.optionalRating(dto.hostRating, 'Host rating');
    const renterRating = this.optionalRating(dto.renterRating, 'Renter rating');
    const tags = Array.isArray(dto.tags) ? dto.tags.map((tag) => tag.trim()).filter(Boolean).slice(0, 8) : [];
    const review = await this.prisma.review.create({
      data: {
        bookingId: id,
        fromUserId: req.user.id,
        toUserId: dto.toUserId,
        rating,
        spotRating,
        hostRating,
        renterRating,
        tags,
        comment: dto.comment,
      },
    });
    const agg = await this.prisma.review.aggregate({
      where: { toUserId: dto.toUserId },
      _avg: { rating: true },
      _count: true,
    });
    await this.prisma.user.update({
      where: { id: dto.toUserId },
      data: { ratingAvg: agg._avg.rating ?? 0, ratingCount: agg._count },
    });
    if (spotRating != null) {
      const spotAgg = await this.prisma.review.aggregate({
        where: { booking: { spotId: booking.spotId }, spotRating: { not: null } },
        _avg: { spotRating: true },
        _count: true,
      });
      await this.prisma.parkingSpot.update({
        where: { id: booking.spotId },
        data: { ratingAvg: spotAgg._avg.spotRating ?? 0, ratingCount: spotAgg._count },
      });
    }
    return review;
  }

  @Post('bookings/:id/disputes')
  async dispute(
    @Req() req: { user: { id: string } },
    @Param('id') id: string,
    @Body() body: { notes: string },
  ) {
    if (!body.notes?.trim()) throw new BadRequestException('Dispute notes are required.');
    await this.requireBookingParty(id, req.user.id);
    return this.prisma.dispute.create({
      data: { bookingId: id, raisedById: req.user.id, notes: body.notes.trim() },
    });
  }

  @Post('bookings/:id/messages')
  async sendMessage(
    @Req() req: { user: { id: string } },
    @Param('id') id: string,
    @Body() body: { content: string; attachmentUrl?: string; attachmentType?: string },
  ) {
    const booking = await this.requireBookingParty(id, req.user.id);
    if (!body.content?.trim()) throw new BadRequestException('Message content is required.');
    const message = await this.prisma.message.create({
      data: {
        bookingId: id,
        senderId: req.user.id,
        content: body.content.trim(),
        attachmentUrl: body.attachmentUrl?.trim() || undefined,
        attachmentType: body.attachmentType?.trim() || undefined,
      },
    });
    const recipientId = booking.renterId === req.user.id ? booking.spot.hostId : booking.renterId;
    if (this.fcm) {
      await this.fcm.sendNotification({
        userId: recipientId,
        title: 'New booking message',
        body: body.attachmentUrl?.trim() ? 'A message with an attachment was sent.' : body.content.trim(),
        bookingId: id,
        type: 'MESSAGE_RECEIVED',
        route: `/bookings/${id}/chat`,
        data: { messageId: message.id },
      });
    }
    return message;
  }

  @Get('bookings/:id/messages')
  async getMessages(
    @Req() req: { user: { id: string } },
    @Param('id') id: string,
  ) {
    await this.requireBookingParty(id, req.user.id);
    await this.prisma.message.updateMany({
      where: { bookingId: id, senderId: { not: req.user.id }, readAt: null },
      data: { readAt: new Date() },
    });
    return this.prisma.message.findMany({
      where: { bookingId: id },
      orderBy: { createdAt: 'asc' },
    });
  }

  private async requireBookingParty(bookingId: string, userId: string) {
    const booking = await this.prisma.booking.findFirst({
      where: {
        id: bookingId,
        OR: [{ renterId: userId }, { spot: { hostId: userId } }],
      },
      include: { spot: true },
    });
    if (!booking) throw new BadRequestException('Booking not found');
    await this.assertNotBlocked(userId, booking.renterId, booking.spot.hostId);
    return booking;
  }

  private optionalRating(value: number | undefined, label: string) {
    if (value == null) return undefined;
    const rating = Number(value);
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) throw new BadRequestException(`${label} must be between 1 and 5.`);
    return rating;
  }

  private async assertNotBlocked(actorId: string, renterId: string, hostId: string) {
    const otherId = actorId === renterId ? hostId : renterId;
    const block = await this.prisma.userBlock.findFirst({
      where: {
        OR: [
          { blockerId: actorId, blockedId: otherId },
          { blockerId: otherId, blockedId: actorId },
        ],
      },
      select: { id: true },
    });
    if (block) throw new BadRequestException('This user interaction is blocked.');
  }
}
