import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Controller()
export class HealthController {
  constructor(private prisma: PrismaService) {}

  @Get('health')
  async health() {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch {
      throw new ServiceUnavailableException({
        ok: false,
        name: 'ParkBangla',
        database: 'down',
      });
    }
    return {
      ok: true,
      name: 'ParkBangla',
      database: 'up',
      environment: process.env.NODE_ENV ?? 'development',
      version: process.env.npm_package_version ?? '0.1.0',
      checkedAt: new Date().toISOString(),
    };
  }
}
