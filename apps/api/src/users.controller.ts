import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { IsOptional, IsString } from 'class-validator';
import { AuthGuard } from './auth.guard';
import { FcmService } from './fcm.service';
import { PrismaService } from './prisma.service';

class VehicleDto {
  @IsString()
  plate!: string;
  @IsString()
  type!: string;
  @IsString()
  sizeClass!: string;
}

class PatchMeDto {
  @IsOptional()
  @IsString()
  name?: string;
  @IsOptional()
  @IsString()
  locale?: string;
  @IsOptional()
  @IsString()
  nidDocUrl?: string;
  @IsOptional()
  @IsString()
  dlDocUrl?: string;
  @IsOptional()
  @IsString()
  fcmToken?: string;
  @IsOptional()
  @IsString()
  payoutMethod?: string;
  @IsOptional()
  @IsString()
  payoutDestination?: string;
}

@Controller()
@UseGuards(AuthGuard)
export class UsersController {
  constructor(
    private prisma: PrismaService,
    private fcm?: FcmService,
  ) {}

  @Get('me')
  me(@Req() req: { user: { id: string } }) {
    return this.prisma.user.findUnique({
      where: { id: req.user.id },
      include: { vehicles: true },
    });
  }

  @Patch('me')
  patch(@Req() req: { user: { id: string } }, @Body() dto: PatchMeDto) {
    return this.prisma.user.update({ where: { id: req.user.id }, data: dto });
  }

  @Get('me/notification-preferences')
  async notificationPreferences(@Req() req: { user: { id: string } }) {
    const user = await this.prisma.user.findUnique({ where: { id: req.user.id }, select: { notificationPrefs: true } });
    return this.normalizeNotificationPrefs(user?.notificationPrefs);
  }

  @Patch('me/notification-preferences')
  async updateNotificationPreferences(
    @Req() req: { user: { id: string } },
    @Body() body: { pushEnabled?: boolean; inAppEnabled?: boolean; disabledTypes?: string[] },
  ) {
    const prefs = {
      ...this.normalizeNotificationPrefs(null),
      pushEnabled: body.pushEnabled !== false,
      inAppEnabled: body.inAppEnabled !== false,
      disabledTypes: Array.isArray(body.disabledTypes) ? body.disabledTypes.map((t) => t.trim()).filter(Boolean) : [],
    };
    await this.prisma.user.update({ where: { id: req.user.id }, data: { notificationPrefs: prefs } });
    return prefs;
  }

  @Get('host/summary')
  async hostSummary(@Req() req: { user: { id: string } }) {
    const [spots, upcoming, pending, completed, cancelled, payouts] = await Promise.all([
      this.prisma.parkingSpot.findMany({
        where: { hostId: req.user.id },
        include: { availability: true, blocks: { orderBy: { startAt: 'asc' } } },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.booking.count({
        where: { spot: { hostId: req.user.id }, status: { in: ['PENDING', 'CONFIRMED', 'ACTIVE'] } },
      }),
      this.prisma.booking.count({ where: { spot: { hostId: req.user.id }, status: 'PENDING' } }),
      this.prisma.booking.count({ where: { spot: { hostId: req.user.id }, status: 'COMPLETED' } }),
      this.prisma.booking.count({ where: { spot: { hostId: req.user.id }, status: 'CANCELLED' } }),
      this.prisma.transaction.aggregate({
        where: { userId: req.user.id, type: 'PAYOUT', status: 'SUCCESS' },
        _sum: { amount: true },
      }),
    ]);
    return {
      spots,
      upcomingBookings: upcoming,
      pendingRequests: pending,
      completedBookings: completed,
      cancelledBookings: cancelled,
      earnings: payouts._sum.amount ?? 0,
    };
  }

  @Post('me/vehicles')
  addVehicle(@Req() req: { user: { id: string } }, @Body() dto: VehicleDto) {
    return this.prisma.vehicle.create({ data: { ...dto, userId: req.user.id } });
  }

  @Delete('me/vehicles/:id')
  async delVehicle(@Req() req: { user: { id: string } }, @Param('id') id: string) {
    await this.prisma.vehicle.deleteMany({ where: { id, userId: req.user.id } });
    return { ok: true };
  }

  @Get('me/favorites')
  favorites(@Req() req: { user: { id: string } }) {
    return this.prisma.favoriteSpot.findMany({
      where: { userId: req.user.id },
      include: { spot: { include: { host: { select: { id: true, name: true, ratingAvg: true, ratingCount: true, idVerified: true } } } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  @Post('me/favorites/:spotId')
  async addFavorite(@Req() req: { user: { id: string } }, @Param('spotId') spotId: string) {
    const spot = await this.prisma.parkingSpot.findFirst({ where: { id: spotId, active: true }, select: { id: true } });
    if (!spot) throw new BadRequestException('Spot not found.');
    return this.prisma.favoriteSpot.upsert({
      where: { userId_spotId: { userId: req.user.id, spotId } },
      create: { userId: req.user.id, spotId },
      update: {},
    });
  }

  @Delete('me/favorites/:spotId')
  async removeFavorite(@Req() req: { user: { id: string } }, @Param('spotId') spotId: string) {
    await this.prisma.favoriteSpot.deleteMany({ where: { userId: req.user.id, spotId } });
    return { ok: true };
  }

  @Get('notifications')
  async notifications(@Req() req: { user: { id: string } }) {
    await this.createDueReminders(req.user.id);
    return this.prisma.notification.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  @Post('notifications/:id/read')
  async readNotification(@Req() req: { user: { id: string } }, @Param('id') id: string) {
    await this.prisma.notification.updateMany({
      where: { id, userId: req.user.id },
      data: { read: true },
    });
    return { ok: true };
  }

  @Get('messages/unread-count')
  async unreadMessages(@Req() req: { user: { id: string } }) {
    const bookings = await this.prisma.booking.findMany({
      where: { OR: [{ renterId: req.user.id }, { spot: { hostId: req.user.id } }] },
      select: { id: true },
    });
    const bookingIds = bookings.map((b) => b.id);
    if (bookingIds.length === 0) return { count: 0 };
    const count = await this.prisma.message.count({
      where: { bookingId: { in: bookingIds }, senderId: { not: req.user.id }, readAt: null },
    });
    return { count };
  }

  @Post('reports')
  report(
    @Req() req: { user: { id: string } },
    @Body() body: { targetType: string; targetId: string; reason: string; category?: string; evidenceUrls?: string[] },
  ) {
    if (!body.targetType?.trim() || !body.targetId?.trim() || !body.reason?.trim()) {
      throw new BadRequestException('Report target and reason are required.');
    }
    return this.prisma.report.create({
      data: {
        reporterId: req.user.id,
        targetType: body.targetType.trim(),
        targetId: body.targetId.trim(),
        category: body.category?.trim() || 'GENERAL',
        reason: body.reason.trim(),
        evidenceUrls: Array.isArray(body.evidenceUrls) ? body.evidenceUrls.map((url) => url.trim()).filter(Boolean).slice(0, 5) : [],
      },
    });
  }

  @Get('blocked-users')
  blockedUsers(@Req() req: { user: { id: string } }) {
    return this.prisma.userBlock.findMany({
      where: { blockerId: req.user.id },
      include: { blocked: { select: { id: true, name: true, phone: true, ratingAvg: true, ratingCount: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  @Post('blocked-users/:id')
  blockUser(@Req() req: { user: { id: string } }, @Param('id') id: string, @Body() body: { reason?: string }) {
    if (id === req.user.id) throw new BadRequestException('You cannot block yourself.');
    return this.prisma.userBlock.upsert({
      where: { blockerId_blockedId: { blockerId: req.user.id, blockedId: id } },
      create: { blockerId: req.user.id, blockedId: id, reason: body.reason?.trim() || undefined },
      update: { reason: body.reason?.trim() || undefined },
    });
  }

  @Delete('blocked-users/:id')
  async unblockUser(@Req() req: { user: { id: string } }, @Param('id') id: string) {
    await this.prisma.userBlock.deleteMany({ where: { blockerId: req.user.id, blockedId: id } });
    return { ok: true };
  }

  @Get('safety-center')
  safetyCenter() {
    return {
      emergencyContacts: [
        { label: 'National emergency service', value: '999' },
        { label: 'Police', value: '999' },
        { label: 'Fire service', value: '999' },
      ],
      support: {
        endpoint: '/support-tickets',
        categories: ['SAFETY', 'HARASSMENT', 'MISLEADING_LISTING', 'PAYMENT', 'ACCESS_PROBLEM'],
      },
      reportCategories: ['SAFETY', 'HARASSMENT', 'MISLEADING_LISTING', 'NO_SHOW', 'ACCESS_PROBLEM', 'PAYMENT', 'OTHER'],
    };
  }

  @Post('support-tickets')
  supportTicket(
    @Req() req: { user: { id: string } },
    @Body() body: { subject: string; message: string; priority?: string },
  ) {
    if (!body.subject?.trim() || !body.message?.trim()) {
      throw new BadRequestException('Subject and message are required.');
    }
    return this.prisma.supportTicket.create({
      data: {
        userId: req.user.id,
        subject: body.subject.trim(),
        message: body.message.trim(),
        priority: body.priority?.trim() || 'NORMAL',
      },
    });
  }

  private normalizeNotificationPrefs(raw: unknown) {
    const prefs = raw as { pushEnabled?: boolean; inAppEnabled?: boolean; disabledTypes?: string[] } | null;
    return {
      pushEnabled: prefs?.pushEnabled !== false,
      inAppEnabled: prefs?.inAppEnabled !== false,
      disabledTypes: Array.isArray(prefs?.disabledTypes) ? prefs.disabledTypes : [],
    };
  }

  private async createDueReminders(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { notificationPrefs: true } });
    if (!this.normalizeNotificationPrefs(user?.notificationPrefs).inAppEnabled) return;
    const now = new Date();
    const soon = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const bookings = await this.prisma.booking.findMany({
      where: {
        OR: [{ renterId: userId }, { spot: { hostId: userId } }],
        status: { in: ['PENDING', 'CONFIRMED', 'ACTIVE'] },
        startDate: { lte: soon },
      },
      include: { spot: true },
      take: 20,
    });

    for (const booking of bookings) {
      const isHost = booking.spot.hostId === userId;
      const type =
        booking.status === 'PENDING'
          ? 'PENDING_APPROVAL_REMINDER'
          : booking.status === 'ACTIVE'
            ? 'CHECKOUT_REMINDER'
            : 'UPCOMING_BOOKING_REMINDER';
      const exists = await this.prisma.notification.findFirst({ where: { userId, bookingId: booking.id, type } });
      if (exists) continue;
      const title =
        type === 'PENDING_APPROVAL_REMINDER'
          ? 'Pending booking request'
          : type === 'CHECKOUT_REMINDER'
            ? 'Checkout reminder'
            : 'Upcoming parking';
      const body =
        type === 'PENDING_APPROVAL_REMINDER'
          ? isHost
            ? `Review the request for ${booking.spot.area}.`
            : `Your request for ${booking.spot.area} is waiting for host approval.`
          : type === 'CHECKOUT_REMINDER'
            ? `Remember to check out when leaving ${booking.spot.area}.`
            : `Your parking at ${booking.spot.area} starts soon.`;
      if (this.fcm) {
        await this.fcm.sendNotification({ userId, title, body, bookingId: booking.id, type });
      } else {
        await this.prisma.notification.create({ data: { userId, title, body, bookingId: booking.id, type, route: `/bookings/${booking.id}` } });
      }
    }
  }
}

export class SuggestDto {
  @IsOptional()
  @IsString()
  area?: string;
}
