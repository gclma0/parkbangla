import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { BadRequestException } from '@nestjs/common';
import { BookingsController } from './bookings.controller';
import { UsersController } from './users.controller';

describe('notifications and communication', () => {
  it('normalizes notification preferences', async () => {
    const prisma = {
      user: {
        update: async (args: unknown) => args,
      },
    };
    const controller = new UsersController(prisma as never);

    const result = await controller.updateNotificationPreferences(
      { user: { id: 'user_1' } },
      { pushEnabled: false, inAppEnabled: true, disabledTypes: [' MESSAGE_RECEIVED ', ''] },
    );

    assert.deepEqual(result, {
      pushEnabled: false,
      inAppEnabled: true,
      disabledTypes: ['MESSAGE_RECEIVED'],
    });
  });

  it('rejects empty chat messages even when an attachment is present', async () => {
    const prisma = {
      booking: {
        findFirst: async () => ({ id: 'booking_1', renterId: 'renter_1', spot: { hostId: 'host_1' } }),
      },
      message: {
        create: async () => {
          throw new Error('message should not be created');
        },
      },
      userBlock: {
        findFirst: async () => null,
      },
    };
    const controller = new BookingsController({} as never, prisma as never);

    await assert.rejects(
      () => controller.sendMessage({ user: { id: 'renter_1' } }, 'booking_1', { content: '', attachmentUrl: 'https://example.com/photo.jpg' }),
      BadRequestException,
    );
  });

  it('counts unread messages for booking participants', async () => {
    const prisma = {
      booking: {
        findMany: async () => [{ id: 'booking_1' }, { id: 'booking_2' }],
      },
      message: {
        count: async (args: unknown) => args,
      },
    };
    const controller = new UsersController(prisma as never);

    const result = await controller.unreadMessages({ user: { id: 'user_1' } });

    assert.deepEqual((result as unknown as { count: { where: unknown } }).count.where, {
      bookingId: { in: ['booking_1', 'booking_2'] },
      senderId: { not: 'user_1' },
      readAt: null,
    });
  });
});
