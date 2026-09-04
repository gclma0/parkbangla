import {
  BadRequestException,
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
import { AccessType, BookingStatus, Prisma, VerifiedStatus } from '@prisma/client';
import {
  IsArray,
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
} from 'class-validator';
import { AuthGuard } from './auth.guard';
import { PrismaService } from './prisma.service';
import { availabilityCoversBooking, blockConflictsWithBooking, bookingsConflict, haversineKm, isValidHHMM, suggestedPrices } from './booking-rules';

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
  @IsString()
  entrancePhotoUrl?: string;
  @IsOptional()
  @IsString()
  bayPhotoUrl?: string;
  @IsOptional()
  @IsString()
  ownershipProofUrl?: string;
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

const toNumber = (value?: string) => {
  if (value == null || value.trim() === '') return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
};

const validLat = (value: number) => Number.isFinite(value) && value >= -90 && value <= 90;
const validLng = (value: number) => Number.isFinite(value) && value >= -180 && value <= 180;

function assertCoordinates(lat: number, lng: number) {
  if (!validLat(lat) || !validLng(lng)) {
    throw new BadRequestException('Valid latitude and longitude are required.');
  }
}

function assertMoney(value: number | undefined, label: string) {
  if (value !== undefined && (!Number.isFinite(value) || value <= 0)) {
    throw new BadRequestException(`${label} must be greater than 0.`);
  }
}

function assertRequiredText(value: string | undefined, label: string) {
  if (!value || value.trim().length < 3) {
    throw new BadRequestException(`${label} is required.`);
  }
}

function assertTime(value: string, label: string) {
  if (!isValidHHMM(value)) throw new BadRequestException(`${label} must use HH:mm format.`);
}

function assertWeekdays(weekdays: number[]) {
  if (!Array.isArray(weekdays) || weekdays.length === 0 || weekdays.some((day) => !Number.isInteger(day) || day < 0 || day > 6)) {
    throw new BadRequestException('Weekdays must contain values from 0 to 6.');
  }
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
    @Query('vehicleSize') vehicleSize?: string,
    @Query('accessType') accessType?: AccessType,
    @Query('verifiedOnly') verifiedOnly?: string,
    @Query('maxHourly') maxHourly?: string,
    @Query('maxDaily') maxDaily?: string,
    @Query('maxMonthly') maxMonthly?: string,
    @Query('q') q?: string,
    @Query('north') north?: string,
    @Query('south') south?: string,
    @Query('east') east?: string,
    @Query('west') west?: string,
    @Query('availableNow') availableNow?: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
    @Query('startTime') startTime?: string,
    @Query('endTime') endTime?: string,
  ) {
    const northLat = toNumber(north);
    const southLat = toNumber(south);
    const eastLng = toNumber(east);
    const westLng = toNumber(west);
    const hasBounds =
      northLat !== undefined &&
      southLat !== undefined &&
      eastLng !== undefined &&
      westLng !== undefined &&
      validLat(northLat) &&
      validLat(southLat) &&
      validLng(eastLng) &&
      validLng(westLng) &&
      northLat >= southLat;

    const filters: Prisma.ParkingSpotWhereInput[] = [{ active: true }];
    if (hasBounds) {
      filters.push({ lat: { gte: southLat, lte: northLat } });
      filters.push(
        westLng <= eastLng
          ? { lng: { gte: westLng, lte: eastLng } }
          : { OR: [{ lng: { gte: westLng } }, { lng: { lte: eastLng } }] },
      );
    }
    if (covered === 'true') filters.push({ covered: true });
    if (covered === 'false') filters.push({ covered: false });
    if (vehicleSize && vehicleSize !== 'any') filters.push({ vehicleSizes: { contains: vehicleSize, mode: 'insensitive' } });
    if (accessType && Object.values(AccessType).includes(accessType)) filters.push({ accessType });
    if (verifiedOnly === 'true') filters.push({ verifiedStatus: VerifiedStatus.VERIFIED, host: { idVerified: true } });
    if (maxHourly) filters.push({ hourlyPrice: { lte: Number(maxHourly) } });
    if (maxDaily) filters.push({ dailyPrice: { lte: Number(maxDaily) } });
    if (maxMonthly) filters.push({ monthlyPrice: { lte: Number(maxMonthly) } });
    if (q) {
      filters.push({
        OR: [
          { address: { contains: q, mode: 'insensitive' } },
          { area: { contains: q, mode: 'insensitive' } },
        ],
      });
    }

    const spots = await this.prisma.parkingSpot.findMany({
      where: { AND: filters },
      include: {
        host: { select: { id: true, name: true, ratingAvg: true, ratingCount: true, idVerified: true } },
        availability: true,
        blocks: true,
        bookings: {
          where: { status: { in: [BookingStatus.PENDING, BookingStatus.CONFIRMED, BookingStatus.ACTIVE] } },
          select: { startDate: true, endDate: true, weekdays: true, startTime: true, endTime: true, status: true, createdAt: true },
        },
      },
      take: 250,
    });
    const originLat = toNumber(lat);
    const originLng = toNumber(lng);
    const cap = maxKm ? Number(maxKm) : 12;
    const availabilityWindow = this.availabilityWindow({ availableNow, startDate, endDate, startTime, endTime });
    return spots
      .filter((s) => (availabilityWindow ? this.spotIsAvailable(s, availabilityWindow) : true))
      .map((s) => {
        const { bookings: _bookings, blocks: _blocks, ...publicSpot } = s;
        return {
          ...publicSpot,
          distanceKm:
            originLat !== undefined && originLng !== undefined
              ? Math.round(haversineKm(originLat, originLng, s.lat, s.lng) * 100) / 100
              : null,
          verified: s.verifiedStatus === VerifiedStatus.VERIFIED && s.host.idVerified,
        };
      })
      .filter((s) => (hasBounds || s.distanceKm == null ? true : s.distanceKm <= cap))
      .sort((a, b) => (a.distanceKm ?? Number.MAX_VALUE) - (b.distanceKm ?? Number.MAX_VALUE));
  }

  @Get('spots/suggestions')
  async suggestions(@Query('q') q?: string, @Query('lat') lat?: string, @Query('lng') lng?: string) {
    const term = q?.trim();
    if (!term || term.length < 2) return [];

    const originLat = toNumber(lat);
    const originLng = toNumber(lng);
    const matches = await this.prisma.parkingSpot.findMany({
      where: {
        active: true,
        OR: [
          { address: { contains: term, mode: 'insensitive' } },
          { area: { contains: term, mode: 'insensitive' } },
        ],
      },
      select: {
        id: true,
        address: true,
        area: true,
        lat: true,
        lng: true,
        monthlyPrice: true,
      },
      take: 50,
    });

    const byArea = new Map<string, { area: string; count: number; lat: number; lng: number; distanceKm: number | null }>();
    for (const spot of matches) {
      const key = spot.area.toLowerCase();
      const distanceKm =
        originLat !== undefined && originLng !== undefined
          ? Math.round(haversineKm(originLat, originLng, spot.lat, spot.lng) * 100) / 100
          : null;
      const current = byArea.get(key);
      if (!current) {
        byArea.set(key, { area: spot.area, count: 1, lat: spot.lat, lng: spot.lng, distanceKm });
      } else {
        current.count += 1;
        current.lat += (spot.lat - current.lat) / current.count;
        current.lng += (spot.lng - current.lng) / current.count;
        if (distanceKm != null && (current.distanceKm == null || distanceKm < current.distanceKm)) {
          current.distanceKm = distanceKm;
        }
      }
    }

    const areas = [...byArea.values()].map((area) => ({
      type: 'parking_area',
      title: area.area,
      subtitle: `${area.count} parking ${area.count === 1 ? 'spot' : 'spots'}`,
      count: area.count,
      lat: area.lat,
      lng: area.lng,
      zoom: 15,
      distanceKm: area.distanceKm,
    }));

    const listings = matches.slice(0, 8).map((spot) => ({
      type: 'parking_spot',
      title: spot.address,
      subtitle: `${spot.area} · ৳${spot.monthlyPrice}/mo`,
      spotId: spot.id,
      count: 1,
      lat: spot.lat,
      lng: spot.lng,
      zoom: 17,
      distanceKm:
        originLat !== undefined && originLng !== undefined
          ? Math.round(haversineKm(originLat, originLng, spot.lat, spot.lng) * 100) / 100
          : null,
    }));

    return [...areas, ...listings].sort((a, b) => {
      const countScore = (b.count ?? 0) - (a.count ?? 0);
      if (countScore !== 0) return countScore;
      return (a.distanceKm ?? Number.MAX_VALUE) - (b.distanceKm ?? Number.MAX_VALUE);
    });
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
    assertRequiredText(dto.address, 'Address');
    assertRequiredText(dto.area, 'Area');
    assertRequiredText(dto.accessNotes, 'Access notes');
    assertRequiredText(dto.entrancePhotoUrl, 'Entrance photo');
    assertRequiredText(dto.bayPhotoUrl, 'Parking bay photo');
    assertRequiredText(dto.ownershipProofUrl, 'Ownership or permission proof');
    assertCoordinates(dto.lat, dto.lng);
    assertMoney(dto.hourlyPrice, 'Hourly price');
    assertMoney(dto.dailyPrice, 'Daily price');
    assertMoney(dto.monthlyPrice, 'Monthly price');
    return this.createSpot(req.user.id, dto);
  }

  private async createSpot(hostId: string, dto: CreateSpotDto) {
    const duplicateCandidateIds = await this.findDuplicateCandidateIds({
      hostId,
      lat: dto.lat,
      lng: dto.lng,
      address: dto.address,
      area: dto.area,
    });
    return this.prisma.parkingSpot.create({
      data: {
        hostId,
        lat: dto.lat,
        lng: dto.lng,
        address: dto.address.trim(),
        area: dto.area.trim(),
        covered: dto.covered ?? false,
        widthM: dto.widthM,
        lengthM: dto.lengthM,
        vehicleSizes: dto.vehicleSizes ?? 'sedan,suv',
        accessType: dto.accessType ?? AccessType.GUARD,
        accessNotes: dto.accessNotes?.trim(),
        photos: this.cleanPhotos(dto),
        entrancePhotoUrl: dto.entrancePhotoUrl?.trim(),
        bayPhotoUrl: dto.bayPhotoUrl?.trim(),
        ownershipProofUrl: dto.ownershipProofUrl?.trim(),
        autoApprove: dto.autoApprove ?? true,
        hourlyPrice: dto.hourlyPrice,
        dailyPrice: dto.dailyPrice,
        monthlyPrice: dto.monthlyPrice,
        verifiedStatus: VerifiedStatus.PENDING,
        verificationNotes:
          duplicateCandidateIds.length > 0
            ? `Potential duplicate of ${duplicateCandidateIds.length} nearby listing(s).`
            : null,
        duplicateCandidateIds,
        resubmittedAt: new Date(),
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
    if (dto.lat !== undefined || dto.lng !== undefined) {
      if (dto.lat === undefined || dto.lng === undefined) {
        throw new BadRequestException('Latitude and longitude must be updated together.');
      }
      assertCoordinates(dto.lat, dto.lng);
    }
    assertMoney(dto.hourlyPrice, 'Hourly price');
    assertMoney(dto.dailyPrice, 'Daily price');
    assertMoney(dto.monthlyPrice, 'Monthly price');
    if (dto.accessNotes !== undefined) assertRequiredText(dto.accessNotes, 'Access notes');
    if (dto.entrancePhotoUrl !== undefined) assertRequiredText(dto.entrancePhotoUrl, 'Entrance photo');
    if (dto.bayPhotoUrl !== undefined) assertRequiredText(dto.bayPhotoUrl, 'Parking bay photo');
    if (dto.ownershipProofUrl !== undefined) assertRequiredText(dto.ownershipProofUrl, 'Ownership or permission proof');
    const current = await this.prisma.parkingSpot.findFirst({ where: { id, hostId: req.user.id } });
    if (!current) return { error: 'not found' };
    const nextLat = dto.lat ?? current.lat;
    const nextLng = dto.lng ?? current.lng;
    const nextAddress = dto.address ?? current.address;
    const nextArea = dto.area ?? current.area;
    const duplicateCandidateIds = await this.findDuplicateCandidateIds({
      hostId: req.user.id,
      spotId: id,
      lat: nextLat,
      lng: nextLng,
      address: nextAddress,
      area: nextArea,
    });
    const data: Prisma.ParkingSpotUpdateManyMutationInput = {
      lat: dto.lat,
      lng: dto.lng,
      address: dto.address?.trim(),
      area: dto.area?.trim(),
      covered: dto.covered,
      widthM: dto.widthM,
      lengthM: dto.lengthM,
      vehicleSizes: dto.vehicleSizes,
      accessType: dto.accessType,
      accessNotes: dto.accessNotes?.trim(),
      photos: dto.photos ? this.cleanPhotos(dto as CreateSpotDto) : undefined,
      entrancePhotoUrl: dto.entrancePhotoUrl?.trim(),
      bayPhotoUrl: dto.bayPhotoUrl?.trim(),
      ownershipProofUrl: dto.ownershipProofUrl?.trim(),
      autoApprove: dto.autoApprove,
      hourlyPrice: dto.hourlyPrice,
      dailyPrice: dto.dailyPrice,
      monthlyPrice: dto.monthlyPrice,
      active: dto.active,
      verifiedStatus: VerifiedStatus.PENDING,
      rejectionReason: null,
      verifiedAt: null,
      resubmittedAt: new Date(),
      duplicateCandidateIds,
      verificationNotes:
        duplicateCandidateIds.length > 0
          ? `Potential duplicate of ${duplicateCandidateIds.length} nearby listing(s).`
          : null,
    };
    await this.prisma.parkingSpot.update({ where: { id }, data });
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
    assertWeekdays(dto.weekdays);
    assertTime(dto.startTime, 'Start time');
    assertTime(dto.endTime, 'End time');
    if (dto.startTime === dto.endTime) throw new BadRequestException('Start time and end time cannot match.');
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
    const startAt = new Date(body.startAt);
    const endAt = new Date(body.endAt);
    if (Number.isNaN(startAt.getTime()) || Number.isNaN(endAt.getTime()) || startAt >= endAt) {
      throw new BadRequestException('Invalid block time range.');
    }
    return this.prisma.spotBlock.create({
      data: {
        spotId: id,
        startAt,
        endAt,
        reason: body.reason?.trim(),
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

  private availabilityWindow(params: {
    availableNow?: string;
    startDate?: string;
    endDate?: string;
    startTime?: string;
    endTime?: string;
  }) {
    if (params.availableNow === 'true') {
      const now = new Date();
      const later = new Date(now.getTime() + 60 * 60 * 1000);
      const startTime = `${String(now.getUTCHours()).padStart(2, '0')}:${String(now.getUTCMinutes()).padStart(2, '0')}`;
      const endTime = `${String(later.getUTCHours()).padStart(2, '0')}:${String(later.getUTCMinutes()).padStart(2, '0')}`;
      return {
        startDate: now,
        endDate: later,
        weekdays: [now.getUTCDay()],
        startTime,
        endTime,
      };
    }
    if (!params.startDate && !params.endDate && !params.startTime && !params.endTime) return null;
    if (!params.startDate || !params.endDate || !params.startTime || !params.endTime) {
      throw new BadRequestException('Complete availability search dates and times are required.');
    }
    assertTime(params.startTime, 'Start time');
    assertTime(params.endTime, 'End time');
    if (params.startTime === params.endTime) throw new BadRequestException('Start time and end time cannot match.');
    const parsedStart = new Date(params.startDate);
    const parsedEnd = new Date(params.endDate);
    if (Number.isNaN(parsedStart.getTime()) || Number.isNaN(parsedEnd.getTime()) || parsedStart > parsedEnd) {
      throw new BadRequestException('Invalid availability search date range.');
    }
    return {
      startDate: parsedStart,
      endDate: parsedEnd,
      weekdays: this.weekdaysBetween(parsedStart, parsedEnd),
      startTime: params.startTime,
      endTime: params.endTime,
    };
  }

  private weekdaysBetween(startDate: Date, endDate: Date) {
    const days = new Set<number>();
    for (let cursor = new Date(startDate); cursor <= endDate; cursor.setUTCDate(cursor.getUTCDate() + 1)) {
      days.add(cursor.getUTCDay());
    }
    return [...days];
  }

  private spotIsAvailable(
    spot: {
      availability: { weekdays: number[]; startTime: string; endTime: string }[];
      blocks: { startAt: Date; endAt: Date }[];
      bookings: { startDate: Date; endDate: Date; weekdays: number[]; startTime: string; endTime: string }[];
    },
    window: { startDate: Date; endDate: Date; weekdays: number[]; startTime: string; endTime: string },
  ) {
    if (!availabilityCoversBooking(spot.availability, window)) return false;
    if (spot.blocks.some((block) => blockConflictsWithBooking(block, window))) return false;
    return !spot.bookings.some((booking) => bookingsConflict(booking, window));
  }

  private cleanPhotos(dto: Pick<CreateSpotDto, 'photos' | 'entrancePhotoUrl' | 'bayPhotoUrl'>) {
    const values = [
      ...(Array.isArray(dto.photos) ? dto.photos : []),
      dto.entrancePhotoUrl,
      dto.bayPhotoUrl,
    ];
    return [...new Set(values.map((photo) => photo?.trim()).filter((photo): photo is string => Boolean(photo)))];
  }

  private async findDuplicateCandidateIds(params: {
    hostId: string;
    spotId?: string;
    lat: number;
    lng: number;
    address: string;
    area: string;
  }) {
    const candidates = await this.prisma.parkingSpot.findMany({
      where: {
        active: true,
        id: params.spotId ? { not: params.spotId } : undefined,
        lat: { gte: params.lat - 0.001, lte: params.lat + 0.001 },
        lng: { gte: params.lng - 0.001, lte: params.lng + 0.001 },
      },
      select: { id: true, hostId: true, lat: true, lng: true, address: true, area: true },
      take: 25,
    });
    const addressKey = this.normalizedLocationText(params.address);
    const areaKey = this.normalizedLocationText(params.area);
    return candidates
      .filter((candidate) => {
        const nearby = haversineKm(params.lat, params.lng, candidate.lat, candidate.lng) <= 0.06;
        const sameText =
          this.normalizedLocationText(candidate.address) === addressKey &&
          this.normalizedLocationText(candidate.area) === areaKey;
        return nearby || sameText || candidate.hostId === params.hostId;
      })
      .map((candidate) => candidate.id);
  }

  private normalizedLocationText(value: string) {
    return value.trim().toLowerCase().replace(/\s+/g, ' ');
  }
}
