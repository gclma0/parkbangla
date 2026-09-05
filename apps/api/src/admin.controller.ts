import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { BookingStatus, KycStatus, Prisma, VerifiedStatus } from '@prisma/client';
import { AuthGuard } from './auth.guard';
import { PrismaService } from './prisma.service';
import { commissionOn } from './booking-rules';

type AdminUser = { id?: string; isAdmin: boolean; adminRole?: string };

@Controller('admin')
@UseGuards(AuthGuard)
export class AdminController {
  constructor(private prisma: PrismaService) {}

  private assertAdmin(user: { isAdmin: boolean }) {
    if (!user.isAdmin) throw new UnauthorizedException('Admin only');
  }

  private search(q?: string) {
    const value = q?.trim();
    return value ? value : undefined;
  }

  private async audit(adminId: string, action: string, targetType: string, targetId: string, metadata?: Record<string, unknown>) {
    await this.prisma.adminAuditLog.create({
      data: { adminId, action, targetType, targetId, metadata: metadata === undefined ? undefined : (metadata as Prisma.InputJsonValue) },
    });
  }

  @Get('stats')
  async stats(@Req() req: { user: AdminUser }) {
    this.assertAdmin(req.user);
    const [users, spots, bookings, revenue, openDisputes, openTickets] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.parkingSpot.count({ where: { active: true } }),
      this.prisma.booking.count(),
      this.prisma.transaction.aggregate({ where: { type: 'COMMISSION', status: 'SUCCESS' }, _sum: { amount: true } }),
      this.prisma.dispute.count({ where: { status: 'OPEN' } }),
      this.prisma.supportTicket.count({ where: { status: { not: 'RESOLVED' } } }),
    ]);
    return { users, activeSpots: spots, bookings, commissionRevenue: revenue._sum.amount ?? 0, openDisputes, openTickets };
  }

  @Get('users')
  users(@Req() req: { user: AdminUser }, @Query('q') q?: string) {
    this.assertAdmin(req.user);
    const search = this.search(q);
    return this.prisma.user.findMany({
      where: search ? { OR: [{ name: { contains: search, mode: 'insensitive' } }, { phone: { contains: search } }] } : undefined,
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  @Get('users/:id')
  async userDetail(@Req() req: { user: AdminUser }, @Param('id') id: string) {
    this.assertAdmin(req.user);
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: {
        vehicles: true,
        spots: { select: { id: true, area: true, address: true, verifiedStatus: true, riskFlags: true, createdAt: true } },
        bookings: { orderBy: { createdAt: 'desc' }, take: 20 },
        ledger: { orderBy: { createdAt: 'desc' }, take: 20 },
      },
    });
    const [cancelledBookings, reports, disputes, notes, audit] = await Promise.all([
      this.prisma.booking.count({ where: { renterId: id, status: 'CANCELLED' } }),
      this.prisma.report.count({ where: { reporterId: id } }),
      this.prisma.dispute.count({ where: { raisedById: id } }),
      this.prisma.moderationNote.findMany({ where: { targetType: 'USER', targetId: id }, orderBy: { createdAt: 'desc' } }),
      this.prisma.adminAuditLog.findMany({ where: { targetType: 'USER', targetId: id }, orderBy: { createdAt: 'desc' } }),
    ]);
    return { ...user, computedRiskFlags: this.userRiskFlags(user, cancelledBookings, reports, disputes), notes, audit };
  }

  @Get('spots')
  spots(@Req() req: { user: AdminUser }, @Query('q') q?: string) {
    this.assertAdmin(req.user);
    const search = this.search(q);
    return this.prisma.parkingSpot.findMany({
      where: search
        ? {
            OR: [
              { area: { contains: search, mode: 'insensitive' } },
              { address: { contains: search, mode: 'insensitive' } },
              { host: { phone: { contains: search } } },
            ],
          }
        : undefined,
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

  @Get('spots/:id')
  async spotDetail(@Req() req: { user: AdminUser }, @Param('id') id: string) {
    this.assertAdmin(req.user);
    const spot = await this.prisma.parkingSpot.findUnique({
      where: { id },
      include: {
        host: true,
        availability: true,
        blocks: { orderBy: { startAt: 'asc' } },
        bookings: { orderBy: { createdAt: 'desc' }, take: 20, include: { renter: { select: { name: true, phone: true } } } },
      },
    });
    const duplicateCount = spot
      ? await this.prisma.parkingSpot.count({ where: { id: { not: id }, area: spot.area, address: spot.address } })
      : 0;
    const [notes, audit] = await Promise.all([
      this.prisma.moderationNote.findMany({ where: { targetType: 'SPOT', targetId: id }, orderBy: { createdAt: 'desc' } }),
      this.prisma.adminAuditLog.findMany({ where: { targetType: 'SPOT', targetId: id }, orderBy: { createdAt: 'desc' } }),
    ]);
    return { ...spot, computedRiskFlags: this.spotRiskFlags(spot, duplicateCount), notes, audit };
  }

  @Patch('users/:id/verify-id')
  async verifyId(@Req() req: { user: AdminUser }, @Param('id') id: string, @Body() body: { verified: boolean; rejectionReason?: string }) {
    this.assertAdmin(req.user);
    const updated = await this.prisma.user.update({
      where: { id },
      data: {
        idVerified: body.verified,
        kycStatus: body.verified ? KycStatus.VERIFIED : KycStatus.REJECTED,
        kycRejectionReason: body.verified ? null : body.rejectionReason?.trim() || 'Rejected by admin review.',
      },
    });
    await this.audit(req.user.id ?? 'admin', 'VERIFY_ID', 'USER', id, { verified: body.verified });
    return updated;
  }

  @Patch('users/:id/admin-role')
  async adminRole(@Req() req: { user: AdminUser }, @Param('id') id: string, @Body() body: { adminRole: string; isAdmin?: boolean }) {
    this.assertAdmin(req.user);
    const role = body.adminRole?.trim().toUpperCase();
    if (!['USER', 'SUPPORT', 'OPS', 'SUPER_ADMIN'].includes(role)) throw new BadRequestException('Invalid admin role.');
    const updated = await this.prisma.user.update({ where: { id }, data: { adminRole: role, isAdmin: body.isAdmin ?? role !== 'USER' } });
    await this.audit(req.user.id ?? 'admin', 'UPDATE_ADMIN_ROLE', 'USER', id, { adminRole: role });
    return updated;
  }

  @Patch('spots/:id/verify')
  async verifySpot(
    @Req() req: { user: AdminUser },
    @Param('id') id: string,
    @Body() body: { status: VerifiedStatus; rejectionReason?: string; checklist?: string[]; notes?: string },
  ) {
    this.assertAdmin(req.user);
    if (!Object.values(VerifiedStatus).includes(body.status)) throw new BadRequestException('Invalid verification status.');
    if (body.status === VerifiedStatus.REJECTED && !body.rejectionReason?.trim()) {
      throw new BadRequestException('Rejection reason is required.');
    }
    const checklist = Array.isArray(body.checklist) ? body.checklist.map((item) => item.trim()).filter(Boolean) : undefined;
    const updated = await this.prisma.parkingSpot.update({
      where: { id },
      data: {
        verifiedStatus: body.status,
        verificationChecklist: checklist,
        verificationNotes: body.notes?.trim(),
        rejectionReason: body.status === VerifiedStatus.REJECTED ? body.rejectionReason?.trim() : null,
        verifiedAt: body.status === VerifiedStatus.VERIFIED ? new Date() : null,
      },
    });
    await this.audit(req.user.id ?? 'admin', 'VERIFY_SPOT', 'SPOT', id, { status: body.status });
    return updated;
  }

  @Get('bookings')
  bookings(@Req() req: { user: AdminUser }, @Query('q') q?: string) {
    this.assertAdmin(req.user);
    const search = this.search(q);
    return this.prisma.booking.findMany({
      where: search
        ? {
            OR: [
              { id: { contains: search } },
              { renter: { phone: { contains: search } } },
              { spot: { area: { contains: search, mode: 'insensitive' } } },
            ],
          }
        : undefined,
      include: { renter: { select: { name: true, phone: true } }, spot: { select: { area: true, address: true, host: { select: { name: true, phone: true } } } } },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  @Get('bookings/:id')
  async bookingDetail(@Req() req: { user: AdminUser }, @Param('id') id: string) {
    this.assertAdmin(req.user);
    const [booking, transactions, disputes, messages, notes, audit] = await Promise.all([
      this.prisma.booking.findUnique({ where: { id }, include: { renter: true, spot: { include: { host: true } }, vehicle: true, checkIns: true } }),
      this.prisma.transaction.findMany({ where: { bookingId: id }, orderBy: { createdAt: 'desc' } }),
      this.prisma.dispute.findMany({ where: { bookingId: id }, orderBy: { createdAt: 'desc' } }),
      this.prisma.message.findMany({ where: { bookingId: id }, orderBy: { createdAt: 'desc' } }),
      this.prisma.moderationNote.findMany({ where: { targetType: 'BOOKING', targetId: id }, orderBy: { createdAt: 'desc' } }),
      this.prisma.adminAuditLog.findMany({ where: { targetType: 'BOOKING', targetId: id }, orderBy: { createdAt: 'desc' } }),
    ]);
    return { booking, transactions, disputes, messages, notes, audit };
  }

  @Post('bookings/:id/cancel-adjust')
  async cancelAdjust(
    @Req() req: { user: AdminUser },
    @Param('id') id: string,
    @Body() body: { refundAmount?: number; reason?: string },
  ) {
    this.assertAdmin(req.user);
    if (!body.reason?.trim()) throw new BadRequestException('Cancellation reason is required.');
    const refundAmount = Number(body.refundAmount ?? 0);
    if (Number.isNaN(refundAmount) || refundAmount < 0) throw new BadRequestException('Refund amount must be zero or greater.');
    const booking = await this.prisma.booking.update({
      where: { id },
      data: { status: BookingStatus.CANCELLED, decisionReason: body.reason.trim() },
    });
    if (refundAmount > 0) {
      await this.prisma.user.update({ where: { id: booking.renterId }, data: { walletBalance: { increment: refundAmount } } });
      await this.prisma.walletLedger.create({
        data: { userId: booking.renterId, amount: refundAmount, reason: `Admin refund: ${body.reason.trim()}`, bookingId: id },
      });
      await this.prisma.transaction.create({
        data: { bookingId: id, userId: booking.renterId, amount: refundAmount, method: 'ADMIN_ADJUSTMENT', type: 'REFUND' },
      });
    }
    await this.audit(req.user.id ?? 'admin', 'CANCEL_BOOKING_ADJUST_REFUND', 'BOOKING', id, { refundAmount, reason: body.reason.trim() });
    return { booking, refundAmount };
  }

  @Get('transactions')
  transactions(@Req() req: { user: AdminUser }, @Query('q') q?: string) {
    this.assertAdmin(req.user);
    const search = this.search(q);
    return this.prisma.transaction.findMany({
      where: search
        ? { OR: [{ userId: { contains: search } }, { bookingId: { contains: search } }, { method: { contains: search, mode: 'insensitive' } }] }
        : undefined,
      include: { booking: { select: { id: true, status: true } } },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  @Get('disputes')
  disputes(@Req() req: { user: AdminUser }, @Query('q') q?: string) {
    this.assertAdmin(req.user);
    const search = this.search(q);
    return this.prisma.dispute.findMany({
      where: search
        ? { OR: [{ notes: { contains: search, mode: 'insensitive' } }, { resolution: { contains: search, mode: 'insensitive' } }, { bookingId: { contains: search } }] }
        : undefined,
      include: { booking: true, raisedBy: { select: { name: true, phone: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  @Get('disputes/:id')
  async disputeDetail(@Req() req: { user: AdminUser }, @Param('id') id: string) {
    this.assertAdmin(req.user);
    const [dispute, evidence, notes, audit] = await Promise.all([
      this.prisma.dispute.findUnique({ where: { id }, include: { booking: true, raisedBy: true } }),
      this.prisma.disputeEvidence.findMany({ where: { disputeId: id }, orderBy: { createdAt: 'desc' } }),
      this.prisma.moderationNote.findMany({ where: { targetType: 'DISPUTE', targetId: id }, orderBy: { createdAt: 'desc' } }),
      this.prisma.adminAuditLog.findMany({ where: { targetType: 'DISPUTE', targetId: id }, orderBy: { createdAt: 'desc' } }),
    ]);
    return { dispute, evidence, notes, audit };
  }

  @Post('disputes/:id/evidence')
  async addDisputeEvidence(@Req() req: { user: AdminUser }, @Param('id') id: string, @Body() body: { fileUrl?: string; notes?: string }) {
    this.assertAdmin(req.user);
    if (!body.fileUrl?.trim() && !body.notes?.trim()) throw new BadRequestException('Evidence file or notes are required.');
    const evidence = await this.prisma.disputeEvidence.create({
      data: { disputeId: id, submittedById: req.user.id ?? 'admin', fileUrl: body.fileUrl?.trim(), notes: body.notes?.trim() },
    });
    await this.audit(req.user.id ?? 'admin', 'ADD_DISPUTE_EVIDENCE', 'DISPUTE', id, { evidenceId: evidence.id });
    return evidence;
  }

  @Patch('disputes/:id')
  async resolve(
    @Req() req: { user: AdminUser },
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
      await this.prisma.user.update({ where: { id: d.booking.renterId }, data: { walletBalance: { increment: d.booking.amount } } });
    }
    await this.audit(req.user.id ?? 'admin', 'RESOLVE_DISPUTE', 'DISPUTE', id, { status: body.status, refund: body.refund === true });
    return d;
  }

  @Get('reports')
  reports(@Req() req: { user: AdminUser }, @Query('q') q?: string) {
    this.assertAdmin(req.user);
    const search = this.search(q);
    return this.prisma.report.findMany({
      where: search
        ? { OR: [{ targetType: { contains: search, mode: 'insensitive' } }, { targetId: { contains: search } }, { reason: { contains: search, mode: 'insensitive' } }] }
        : undefined,
      include: { reporter: { select: { name: true, phone: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  @Patch('reports/:id/action')
  async reportAction(
    @Req() req: { user: AdminUser },
    @Param('id') id: string,
    @Body() body: { status?: string; actionTaken?: string; flagTarget?: boolean; deactivateSpot?: boolean },
  ) {
    this.assertAdmin(req.user);
    const report = await this.prisma.report.findUnique({ where: { id } });
    if (!report) throw new BadRequestException('Report not found.');
    const actionTaken = body.actionTaken?.trim();
    if (!actionTaken) throw new BadRequestException('Action taken is required.');

    if (body.flagTarget) {
      if (report.targetType === 'USER') {
        const user = await this.prisma.user.findUnique({ where: { id: report.targetId }, select: { riskFlags: true } });
        await this.prisma.user.update({
          where: { id: report.targetId },
          data: { riskFlags: [...new Set([...(user?.riskFlags ?? []), report.category])] },
        });
      }
      if (report.targetType === 'SPOT') {
        const spot = await this.prisma.parkingSpot.findUnique({ where: { id: report.targetId }, select: { riskFlags: true } });
        await this.prisma.parkingSpot.update({
          where: { id: report.targetId },
          data: { riskFlags: [...new Set([...(spot?.riskFlags ?? []), report.category])] },
        });
      }
    }
    if (body.deactivateSpot && report.targetType === 'SPOT') {
      await this.prisma.parkingSpot.update({ where: { id: report.targetId }, data: { active: false } });
    }

    const updated = await this.prisma.report.update({
      where: { id },
      data: { status: body.status?.trim() || 'RESOLVED', actionTaken },
    });
    await this.audit(req.user.id ?? 'admin', 'ACTION_REPORT', 'REPORT', id, {
      status: updated.status,
      actionTaken,
      flagTarget: body.flagTarget === true,
      deactivateSpot: body.deactivateSpot === true,
    });
    return updated;
  }

  @Get('messages')
  messages(@Req() req: { user: AdminUser }, @Query('q') q?: string) {
    this.assertAdmin(req.user);
    const search = this.search(q);
    return this.prisma.message.findMany({
      where: search
        ? { OR: [{ bookingId: { contains: search } }, { senderId: { contains: search } }, { content: { contains: search, mode: 'insensitive' } }] }
        : undefined,
      include: { booking: { select: { id: true, status: true } } },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  @Get('support-tickets')
  tickets(@Req() req: { user: AdminUser }, @Query('q') q?: string) {
    this.assertAdmin(req.user);
    const search = this.search(q);
    return this.prisma.supportTicket.findMany({
      where: search
        ? { OR: [{ subject: { contains: search, mode: 'insensitive' } }, { message: { contains: search, mode: 'insensitive' } }, { userId: { contains: search } }] }
        : undefined,
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  @Patch('support-tickets/:id')
  async updateTicket(
    @Req() req: { user: AdminUser },
    @Param('id') id: string,
    @Body() body: { status?: string; priority?: string; assignedAdminId?: string; resolution?: string },
  ) {
    this.assertAdmin(req.user);
    const ticket = await this.prisma.supportTicket.update({
      where: { id },
      data: {
        status: body.status?.trim(),
        priority: body.priority?.trim(),
        assignedAdminId: body.assignedAdminId?.trim() || undefined,
        resolution: body.resolution?.trim() || undefined,
      },
    });
    await this.audit(req.user.id ?? 'admin', 'UPDATE_SUPPORT_TICKET', 'SUPPORT_TICKET', id, body);
    return ticket;
  }

  @Post('moderation-notes')
  async note(@Req() req: { user: AdminUser }, @Body() body: { targetType: string; targetId: string; note: string }) {
    this.assertAdmin(req.user);
    if (!body.targetType?.trim() || !body.targetId?.trim() || !body.note?.trim()) throw new BadRequestException('Target and note are required.');
    const note = await this.prisma.moderationNote.create({
      data: { adminId: req.user.id ?? 'admin', targetType: body.targetType.trim(), targetId: body.targetId.trim(), note: body.note.trim() },
    });
    await this.audit(req.user.id ?? 'admin', 'ADD_MODERATION_NOTE', body.targetType.trim(), body.targetId.trim(), { noteId: note.id });
    return note;
  }

  @Patch('risk-flags')
  async riskFlags(@Req() req: { user: AdminUser }, @Body() body: { targetType: 'USER' | 'SPOT'; targetId: string; flags: string[] }) {
    this.assertAdmin(req.user);
    const flags = Array.isArray(body.flags) ? body.flags.map((f) => f.trim()).filter(Boolean) : [];
    if (body.targetType === 'USER') {
      const updated = await this.prisma.user.update({ where: { id: body.targetId }, data: { riskFlags: flags } });
      await this.audit(req.user.id ?? 'admin', 'UPDATE_RISK_FLAGS', 'USER', body.targetId, { flags });
      return updated;
    }
    if (body.targetType === 'SPOT') {
      const updated = await this.prisma.parkingSpot.update({ where: { id: body.targetId }, data: { riskFlags: flags } });
      await this.audit(req.user.id ?? 'admin', 'UPDATE_RISK_FLAGS', 'SPOT', body.targetId, { flags });
      return updated;
    }
    throw new BadRequestException('Invalid risk flag target.');
  }

  @Get('commission-preview')
  preview(@Req() req: { user: AdminUser }, @Body() _b: unknown) {
    this.assertAdmin(req.user);
    return { rate: 0.15, sample: commissionOn(10000) };
  }

  private userRiskFlags(user: unknown, cancelledBookings: number, reports: number, disputes: number) {
    const flags = new Set<string>((user as { riskFlags?: string[] } | null)?.riskFlags ?? []);
    if (cancelledBookings >= 3) flags.add('REPEATED_CANCELLATIONS');
    if (reports >= 3) flags.add('FREQUENT_REPORTER');
    if (disputes >= 2) flags.add('REPEATED_DISPUTES');
    if (((user as { walletBalance?: number } | null)?.walletBalance ?? 0) < 0) flags.add('NEGATIVE_WALLET');
    return [...flags];
  }

  private spotRiskFlags(spot: unknown, duplicateCount: number) {
    const typed = spot as { riskFlags?: string[]; duplicateCandidateIds?: string[] } | null;
    const flags = new Set<string>(typed?.riskFlags ?? []);
    if ((typed?.duplicateCandidateIds ?? []).length > 0 || duplicateCount > 0) flags.add('DUPLICATE_SPOT_REVIEW');
    return [...flags];
  }
}
