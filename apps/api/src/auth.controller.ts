import { Body, Controller, HttpException, HttpStatus, Post, Req } from '@nestjs/common';
import { IsOptional, IsString, MinLength } from 'class-validator';
import { AuthService } from './auth.service';

class RequestOtpDto {
  @IsString()
  phone!: string;
}

class VerifyOtpDto {
  @IsString()
  phone!: string;
  @IsString()
  @MinLength(4)
  code!: string;
  @IsOptional()
  @IsString()
  name?: string;
}

@Controller('auth')
export class AuthController {
  constructor(private auth: AuthService) {}
  private readonly otpAttempts = new Map<string, { count: number; resetAt: number }>();

  @Post('otp/request')
  request(@Body() dto: RequestOtpDto, @Req() req: { ip?: string }) {
    const phone = dto.phone.replace(/\s/g, '');
    this.assertOtpAllowed(`${req.ip ?? 'unknown'}:${phone}`);
    return this.auth.requestOtp(phone);
  }

  @Post('otp/verify')
  verify(@Body() dto: VerifyOtpDto) {
    return this.auth.verifyOtp(dto.phone.replace(/\s/g, ''), dto.code, dto.name);
  }

  private assertOtpAllowed(key: string) {
    const now = Date.now();
    const current = this.otpAttempts.get(key);
    if (!current || current.resetAt <= now) {
      this.otpAttempts.set(key, { count: 1, resetAt: now + 10 * 60 * 1000 });
      return;
    }
    if (current.count >= 5) {
      throw new HttpException('Too many OTP requests. Try again later.', HttpStatus.TOO_MANY_REQUESTS);
    }
    current.count += 1;
  }
}
