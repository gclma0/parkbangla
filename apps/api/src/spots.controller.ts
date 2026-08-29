import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AccessType, VerifiedStatus } from '@prisma/client';
import {
  IsArray,
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
} from 'class-validator';
import { AuthGuard } from './auth.guard';
import { PrismaService } from './prisma.service';
import { haversineKm, suggestedPrices } from './booking-rules';

class CreateSpotDto {
  @IsNumber()
  lat!: number;
  @IsNumber()
  lng!: number;
  @IsString()
  address!: string;
  @IsString()
  area!: string;
  @IsOptional()
  @IsBoolean()
  covered?: boolean;
  @IsOptional()
  @IsNumber()
  widthM?: number;
  @IsOptional()
  @IsNumber()
  lengthM?: number;
  @IsOptional()
  @IsString()
  vehicleSizes?: string;
  @IsOptional()
  @IsString()
  accessType?: AccessType;
  @IsOptional()
  @IsString()
  accessNotes?: string;
  @IsOptional()
  @IsArray()
  photos?: string[];
  @IsOptional()
  @IsBoolean()
  autoApprove?: boolean;
  @IsNumber()
  hourlyPrice!: number;
  @IsNumber()
  dailyPrice!: number;
  @IsNumber()
  monthlyPrice!: number;
}

class AvailabilityDto {
  @IsArray()
  weekdays!: number[];
  @IsString()
  startTime!: string;
  @IsString()
  endTime!: string;
}

@Controller()
export class SpotsController {
  constructor(private prisma: PrismaService) {}

  @Get('spots/suggest-price')
  suggest(@Query('area') area = 'Dhaka') {
    return suggestedPrices(area);
  }

  @Get('spots')
  async search(
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('maxKm') maxKm?: string,
    @Query('covered') covered?: string,
    @Query('maxMonthly') maxMonthly?: string,
    @Query('q') q?: string,
  ) {
    const spots = await this.prisma.parkingSpot.findMany({
      where: {
        active: true,
        ...(covered === 'true' ? { covered: true } : {}),
        ...(covered === 'false' ? { covered: false } : {}),
        ...(maxMonthly ? { monthlyPrice: { lte: Number(maxMonthly) } } : {}),
        ...(q
          ? {
              OR: [
                { address: { contains: q, mode: 'insensitive' } },
                { area: { contains: q, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      include: {
        host: { select: { id: true, name: true, ratingAvg: true, ratingCount: true, idVerified: true } },
        availability: true,
      },
    });
    const originLat = lat ? Number(lat) : 23.7806;
    const originLng = lng ? Number(lng) : 90.4193;
    const cap = maxKm ? Number(maxKm) : 12;
    return spots
      .map((s) => ({
        ...s,
        distanceKm: Math.round(haversineKm(originLat, originLng, s.lat, s.lng) * 100) / 100,
        verified: s.verifiedStatus === VerifiedStatus.VERIFIED && s.host.idVerified,
      }))
      .filter((s) => s.distanceKm <= cap)
      .sort((a, b) => a.distanceKm - b.distanceKm);
  }

  @Get('spots/:id')
  async one(@Param('id') id: string) {
    const s = await this.prisma.parkingSpot.findUnique({
      where: { id },
      include: {
        host: { select: { id: true, name: true, ratingAvg: true, ratingCount: true, idVerified: true } },
        availability: true,
        blocks: true,
      },
    });
    if (!s) return null;

    const reviews = await this.prisma.review.findMany({
      where: {
        booking: { spotId: id },
      },
      include: {
        fromUser: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return {
      ...s,
      verified: s.verifiedStatus === VerifiedStatus.VERIFIED && s.host.idVerified,
      reviews,
    };
  }

  @UseGuards(AuthGuard)
  @Get('me/spots')
  mine(@Req() req: { user: { id: string } }) {
    return this.prisma.parkingSpot.findMany({
      where: { hostId: req.user.id },
      include: { availability: true, blocks: true, bookings: { take: 20, orderBy: { createdAt: 'desc' } } },
    });
  }

  @UseGuards(AuthGuard)
  @Post('spots')
  create(@Req() req: { user: { id: string } }, @Body() dto: CreateSpotDto) {
    return this.prisma.parkingSpot.create({
      data: {
        hostId: req.user.id,
        lat: dto.lat,
        lng: dto.lng,
        address: dto.address,
        area: dto.area,
        covered: dto.covered ?? false,
        widthM: dto.widthM,
        lengthM: dto.lengthM,
        vehicleSizes: dto.vehicleSizes ?? 'sedan,suv',
        accessType: dto.accessType ?? AccessType.GUARD,
        accessNotes: dto.accessNotes,
        photos: dto.photos ?? [],
        autoApprove: dto.autoApprove ?? true,
        hourlyPrice: dto.hourlyPrice,
        dailyPrice: dto.dailyPrice,
        monthlyPrice: dto.monthlyPrice,
        verifiedStatus: VerifiedStatus.PENDING,
      },
    });
  }

  @UseGuards(AuthGuard)
  @Patch('spots/:id')
  async patch(
    @Req() req: { user: { id: string } },
    @Param('id') id: string,
    @Body() dto: Partial<CreateSpotDto> & { active?: boolean },
  ) {
    await this.prisma.parkingSpot.updateMany({
      where: { id, hostId: req.user.id },
      data: dto as never,
    });
    return this.prisma.parkingSpot.findUnique({ where: { id } });
  }

  @UseGuards(AuthGuard)
  @Post('spots/:id/availability')
  async setAvail(
    @Req() req: { user: { id: string } },
    @Param('id') id: string,
    @Body() dto: AvailabilityDto,
  ) {
    const spot = await this.prisma.parkingSpot.findFirst({ where: { id, hostId: req.user.id } });
    if (!spot) return { error: 'not found' };
    await this.prisma.availability.deleteMany({ where: { spotId: id } });
    return this.prisma.availability.create({
      data: { spotId: id, weekdays: dto.weekdays, startTime: dto.startTime, endTime: dto.endTime },
    });
  }

  @UseGuards(AuthGuard)
  @Post('spots/:id/blocks')
  async block(
    @Req() req: { user: { id: string } },
    @Param('id') id: string,
    @Body() body: { startAt: string; endAt: string; reason?: string },
  ) {
    const spot = await this.prisma.parkingSpot.findFirst({ where: { id, hostId: req.user.id } });
    if (!spot) return { error: 'not found' };
    return this.prisma.spotBlock.create({
      data: {
        spotId: id,
        startAt: new Date(body.startAt),
        endAt: new Date(body.endAt),
        reason: body.reason,
      },
    });
  }

  @UseGuards(AuthGuard)
  @Delete('spots/:id/blocks/:blockId')
  async unblock(
    @Req() req: { user: { id: string } },
    @Param('id') id: string,
    @Param('blockId') blockId: string,
  ) {
    const spot = await this.prisma.parkingSpot.findFirst({ where: { id, hostId: req.user.id } });
    if (!spot) return { error: 'not found' };
    await this.prisma.spotBlock.delete({ where: { id: blockId } });
    return { ok: true };
  }
}
