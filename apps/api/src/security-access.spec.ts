import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { BadRequestException } from '@nestjs/common';
import { BookingStatus } from '@prisma/client';
import { BookingsController } from './bookings.controller';
import { WalletController } from './wallet.controller';

describe('booking access control', () => {
  it('scopes booking detail to the renter or spot host', async () => {
    const prisma = {
      booking: {
        findFirst: async (args: unknown) => args,
      },
    };
    const controller = new BookingsController({ expirePendingBookings: async () => undefined } as never, prisma as never);

    const result = await controller.one({ user: { id: 'user_1' } }, 'booking_1');

    assert.deepEqual((result as unknown as { where: unknown }).where, {
      id: 'booking_1',
      OR: [{ renterId: 'user_1' }, { spot: { hostId: 'user_1' } }],
    });
  });

  it('rejects messages from non-participants', async () => {
    const prisma = {
      booking: {
        findFirst: async () => null,
      },
      message: {
        create: async () => {
          throw new Error('message should not be created');
        },
      },
    };
    const controller = new BookingsController({} as never, prisma as never);

    await assert.rejects(
      () => controller.sendMessage({ user: { id: 'stranger' } }, 'booking_1', { content: 'hello' }),
      BadRequestException,
    );
  });

  it('allows reviews only for completed bookings and the other participant', async () => {
    const booking = {
      id: 'booking_1',
      renterId: 'renter_1',
      status: BookingStatus.CONFIRMED,
      spot: { hostId: 'host_1' },
    };
    const prisma = {
      booking: {
        findFirst: async () => booking,
      },
      review: {
        create: async () => {
          throw new Error('review should not be created');
        },
      },
    };
    const controller = new BookingsController({} as never, prisma as never);

    await assert.rejects(
      () => controller.review({ user: { id: 'renter_1' } }, 'booking_1', { toUserId: 'host_1', rating: 5 }),
      BadRequestException,
    );
  });
});

describe('wallet validation', () => {
  it('rejects negative demo top-ups', async () => {
    const controller = new WalletController({} as never);

    await assert.rejects(
      () => controller.topup({ user: { id: 'user_1' } }, { amount: -1, method: 'bKash' }),
      BadRequestException,
    );
  });
});
