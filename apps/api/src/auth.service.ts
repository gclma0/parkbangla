import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from './prisma.service';

const DEMO_OTP = process.env.DEMO_OTP ?? '123456';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
  ) {}

  async requestOtp(phone: string) {
    const code = DEMO_OTP;
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
    await this.prisma.otpChallenge.create({ data: { phone, code, expiresAt } });
    return { ok: true, demoOtp: code, message: 'OTP sent (demo mode)' };
  }

  async verifyOtp(phone: string, code: string, name?: string) {
    const latest = await this.prisma.otpChallenge.findFirst({
      where: { phone },
      orderBy: { createdAt: 'desc' },
    });
    if (!latest || latest.code !== code || latest.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired OTP');
    }
    let user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user) {
      user = await this.prisma.user.create({
        data: {
          phone,
          name: name?.trim() || `User ${phone.slice(-4)}`,
          walletBalance: 5000,
        },
      });
      await this.prisma.walletLedger.create({
        data: { userId: user.id, amount: 5000, reason: 'Welcome credit' },
      });
    }
    const token = await this.jwt.signAsync({ sub: user.id, phone: user.phone });
    return { token, user };
  }
}
