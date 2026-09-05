import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { BadRequestException } from '@nestjs/common';
import { UsersController } from './users.controller';
import { BookingsController } from './bookings.controller';

describe('reviews reputation and safety', () => {
  it('normalizes categorized reports with evidence URLs', async () => {
    const prisma = {
      report: {
        create: async (args: unknown) => args,
      },
    };
    const controller = new UsersController(prisma as never);

    const result = await controller.report(
      { user: { id: 'user_1' } },
      {
        targetType: ' SPOT ',
        targetId: ' spot_1 ',
        category: 'MISLEADING_LISTING',
        reason: ' Entrance was wrong ',
        evidenceUrls: [' https://example.com/a.jpg ', ''],
      },
    );

    assert.deepEqual((result as unknown as { data: unknown }).data, {
      reporterId: 'user_1',
      targetType: 'SPOT',
      targetId: 'spot_1',
      category: 'MISLEADING_LISTING',
      reason: 'Entrance was wrong',
      evidenceUrls: ['https://example.com/a.jpg'],
    });
  });

  it('prevents users from blocking themselves', () => {
    const controller = new UsersController({} as never);

    assert.throws(
      () => controller.blockUser({ user: { id: 'user_1' } }, 'user_1', {}),
      BadRequestException,
    );
  });

  it('blocks booking-party interaction when either user blocked the other', async () => {
    const prisma = {
      booking: {
        findFirst: async () => ({ id: 'booking_1', renterId: 'renter_1', spot: { hostId: 'host_1' } }),
      },
      userBlock: {
        findFirst: async () => ({ id: 'block_1' }),
      },
    };
    const controller = new BookingsController({} as never, prisma as never);

    await assert.rejects(
      () => controller.getMessages({ user: { id: 'renter_1' } }, 'booking_1'),
      BadRequestException,
    );
  });
});
