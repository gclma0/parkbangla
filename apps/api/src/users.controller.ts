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
}

@Controller()
@UseGuards(AuthGuard)
export class UsersController {
  constructor(private prisma: PrismaService) {}

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
  notifications(@Req() req: { user: { id: string } }) {
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

  @Post('reports')
  report(
    @Req() req: { user: { id: string } },
    @Body() body: { targetType: string; targetId: string; reason: string },
  ) {
    return this.prisma.report.create({
      data: {
        reporterId: req.user.id,
        targetType: body.targetType,
        targetId: body.targetId,
        reason: body.reason,
      },
    });
  }
}

export class SuggestDto {
  @IsOptional()
  @IsString()
  area?: string;
}
