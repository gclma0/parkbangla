import {
  Body,
  BadRequestException,
  Controller,
  Get,
  Param,
  Patch,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { BookingStatus, KycStatus, VerifiedStatus } from '@prisma/client';
import { AuthGuard } from './auth.guard';
import { PrismaService } from './prisma.service';
import { commissionOn } from './booking-rules';

@Controller('admin')
@UseGuards(AuthGuard)
export class AdminController {
  constructor(private prisma: PrismaService) {}

  private assertAdmin(user: { isAdmin: boolean }) {
    if (!user.isAdmin) throw new UnauthorizedException('Admin only');
  }

  @Get('stats')
  async stats(@Req() req: { user: { isAdmin: boolean } }) {
    this.assertAdmin(req.user);
    const [users, spots, bookings, revenue] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.parkingSpot.count({ where: { active: true } }),
      this.prisma.booking.count(),
      this.prisma.transaction.aggregate({
        where: { type: 'COMMISSION', status: 'SUCCESS' },
        _sum: { amount: true },
      }),
    ]);
    return {
      users,
      activeSpots: spots,
      bookings,
      commissionRevenue: revenue._sum.amount ?? 0,
    };
  }

  @Get('users')
  users(@Req() req: { user: { isAdmin: boolean } }) {
    this.assertAdmin(req.user);
    return this.prisma.user.findMany({ orderBy: { createdAt: 'desc' }, take: 200 });
  }

  @Get('spots')
  spots(@Req() req: { user: { isAdmin: boolean } }) {
    this.assertAdmin(req.user);
    return this.prisma.parkingSpot.findMany({
      include: {
        host: {
          select: {
            name: true,
            phone: true,
            idVerified: true,
            kycStatus: true,
            acceptanceRate: true,
            cancellationRate: true,
            responseMinutesAvg: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  @Patch('users/:id/verify-id')
  async verifyId(
    @Req() req: { user: { isAdmin: boolean } },
    @Param('id') id: string,
    @Body() body: { verified: boolean; rejectionReason?: string },
  ) {
    this.assertAdmin(req.user);
    return this.prisma.user.update({
      where: { id },
      data: {
        idVerified: body.verified,
        kycStatus: body.verified ? KycStatus.VERIFIED : KycStatus.REJECTED,
        kycRejectionReason: body.verified ? null : body.rejectionReason?.trim() || 'Rejected by admin review.',
      },
    });
  }

  @Patch('spots/:id/verify')
  async verifySpot(
    @Req() req: { user: { isAdmin: boolean } },
    @Param('id') id: string,
    @Body() body: { status: VerifiedStatus; rejectionReason?: string; checklist?: string[]; notes?: string },
  ) {
    this.assertAdmin(req.user);
    if (!Object.values(VerifiedStatus).includes(body.status)) {
      throw new BadRequestException('Invalid verification status.');
    }
    if (body.status === VerifiedStatus.REJECTED && !body.rejectionReason?.trim()) {
      throw new BadRequestException('Rejection reason is required.');
    }
    const checklist = Array.isArray(body.checklist)
      ? body.checklist.map((item) => item.trim()).filter(Boolean)
      : undefined;
    return this.prisma.parkingSpot.update({
      where: { id },
      data: {
        verifiedStatus: body.status,
        verificationChecklist: checklist,
        verificationNotes: body.notes?.trim(),
        rejectionReason: body.status === VerifiedStatus.REJECTED ? body.rejectionReason?.trim() : null,
        verifiedAt: body.status === VerifiedStatus.VERIFIED ? new Date() : null,
      },
    });
  }

  @Get('disputes')
  disputes(@Req() req: { user: { isAdmin: boolean } }) {
    this.assertAdmin(req.user);
    return this.prisma.dispute.findMany({
      include: { booking: true, raisedBy: { select: { name: true, phone: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  @Patch('disputes/:id')
  async resolve(
    @Req() req: { user: { isAdmin: boolean } },
    @Param('id') id: string,
    @Body() body: { status: 'RESOLVED' | 'REJECTED'; resolution: string; refund?: boolean },
  ) {
    this.assertAdmin(req.user);
    const d = await this.prisma.dispute.update({
      where: { id },
      data: { status: body.status, resolution: body.resolution },
      include: { booking: true },
    });
    if (body.refund && d.booking.status !== BookingStatus.CANCELLED) {
      await this.prisma.user.update({
        where: { id: d.booking.renterId },
        data: { walletBalance: { increment: d.booking.amount } },
      });
    }
    return d;
  }

  @Get('reports')
  reports(@Req() req: { user: { isAdmin: boolean } }) {
    this.assertAdmin(req.user);
    return this.prisma.report.findMany({
      include: { reporter: { select: { name: true, phone: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  @Get('commission-preview')
  preview(@Req() req: { user: { isAdmin: boolean } }, @Body() _b: unknown) {
    this.assertAdmin(req.user);
    return { rate: 0.15, sample: commissionOn(10000) };
  }
}
