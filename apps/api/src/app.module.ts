import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PrismaService } from './prisma.service';
import { HealthController } from './health.controller';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { UsersController } from './users.controller';
import { SpotsController } from './spots.controller';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { WalletController } from './wallet.controller';
import { AdminController } from './admin.controller';
import { AuthGuard } from './auth.guard';
import { UploadsController } from './uploads.controller';

@Module({
  imports: [
    JwtModule.register({
      secret: process.env.JWT_SECRET ?? 'parkbangla-dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [
    HealthController,
    AuthController,
    UsersController,
    SpotsController,
    BookingsController,
    WalletController,
    AdminController,
    UploadsController,
  ],
  providers: [PrismaService, AuthService, BookingsService, AuthGuard],
})
export class AppModule {}
