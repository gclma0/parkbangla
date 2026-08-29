import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { IsArray, IsDateString, IsOptional, IsString, IsBoolean, IsNumber } from 'class-validator';
import { AuthGuard } from './auth.guard';
import { BookingsService } from './bookings.service';
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
  @IsString()
  comment?: string;
}

@Controller()
@UseGuards(AuthGuard)
export class BookingsController {
  constructor(
    private bookings: BookingsService,
    private prisma: PrismaService,
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
  list(@Req() req: { user: { id: string } }, @Query('role') role?: string) {
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
  one(@Param('id') id: string) {
    return this.prisma.booking.findUnique({
      where: { id },
      include: {
        spot: { include: { host: true } },
        renter: true,
        checkIns: true,
        reviews: true,
        transactions: true,
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
    @Body() body: { approve: boolean },
  ) {
    return this.bookings.decide(req.user.id, id, body.approve);
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
    const review = await this.prisma.review.create({
      data: {
        bookingId: id,
        fromUserId: req.user.id,
        toUserId: dto.toUserId,
        rating: Number(dto.rating),
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
    return review;
  }

  @Post('bookings/:id/disputes')
  dispute(
    @Req() req: { user: { id: string } },
    @Param('id') id: string,
    @Body() body: { notes: string },
  ) {
    return this.prisma.dispute.create({
      data: { bookingId: id, raisedById: req.user.id, notes: body.notes },
    });
  }

  @Post('bookings/:id/messages')
  async sendMessage(
    @Req() req: { user: { id: string } },
    @Param('id') id: string,
    @Body() body: { content: string },
  ) {
    return this.prisma.message.create({
      data: {
        bookingId: id,
        senderId: req.user.id,
        content: body.content,
      },
    });
  }

  @Get('bookings/:id/messages')
  async getMessages(
    @Param('id') id: string,
  ) {
    return this.prisma.message.findMany({
      where: { bookingId: id },
      orderBy: { createdAt: 'asc' },
    });
  }
}
