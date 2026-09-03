import { BadRequestException, Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { IsNumber, IsString } from 'class-validator';
import { AuthGuard } from './auth.guard';
import { PrismaService } from './prisma.service';

class TopupDto {
  @IsNumber()
  amount!: number;
  @IsString()
  method!: string;
}

class WithdrawDto {
  @IsNumber()
  amount!: number;
  @IsString()
  destination!: string;
}

@Controller()
@UseGuards(AuthGuard)
export class WalletController {
  constructor(private prisma: PrismaService) {}

  private assertMoney(amount: number) {
    if (!Number.isFinite(amount) || amount <= 0 || amount > 100000) {
      throw new BadRequestException('Amount must be between 1 and 100000.');
    }
  }

  @Get('wallet')
  async wallet(@Req() req: { user: { id: string } }) {
    const user = await this.prisma.user.findUnique({ where: { id: req.user.id } });
    const ledger = await this.prisma.walletLedger.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
      take: 40,
    });
    const tx = await this.prisma.transaction.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
      take: 40,
    });
    return { balance: user?.walletBalance ?? 0, ledger, transactions: tx };
  }

  @Post('wallet/topup')
  async topup(@Req() req: { user: { id: string } }, @Body() dto: TopupDto) {
    this.assertMoney(dto.amount);
    if (!dto.method.trim()) throw new BadRequestException('Payment method is required.');
    const user = await this.prisma.user.update({
      where: { id: req.user.id },
      data: { walletBalance: { increment: dto.amount } },
    });
    await this.prisma.walletLedger.create({
      data: { userId: req.user.id, amount: dto.amount, reason: `Top-up ${dto.method}` },
    });
    await this.prisma.transaction.create({
      data: {
        userId: req.user.id,
        amount: dto.amount,
        method: dto.method,
        type: 'TOPUP',
      },
    });
    return { balance: user.walletBalance };
  }

  @Post('wallet/withdraw')
  async withdraw(@Req() req: { user: { id: string } }, @Body() dto: WithdrawDto) {
    this.assertMoney(dto.amount);
    if (!dto.destination.trim()) throw new BadRequestException('Withdrawal destination is required.');
    const me = await this.prisma.user.findUnique({ where: { id: req.user.id } });
    if (!me || me.walletBalance < dto.amount) throw new BadRequestException('Insufficient funds');
    const user = await this.prisma.user.update({
      where: { id: req.user.id },
      data: { walletBalance: { decrement: dto.amount } },
    });
    await this.prisma.walletLedger.create({
      data: {
        userId: req.user.id,
        amount: -dto.amount,
        reason: `Withdraw to ${dto.destination}`,
      },
    });
    await this.prisma.transaction.create({
      data: {
        userId: req.user.id,
        amount: dto.amount,
        method: dto.destination,
        type: 'PAYOUT',
      },
    });
    return { balance: user.walletBalance };
  }
}
