import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { BadRequestException } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { UsersController } from './users.controller';

describe('admin and support console', () => {
  it('requires a reason for manual booking cancellation adjustments', async () => {
    const controller = new AdminController({} as never);

    await assert.rejects(
      () => controller.cancelAdjust({ user: { id: 'admin_1', isAdmin: true } }, 'booking_1', { refundAmount: 10 }),
      BadRequestException,
    );
  });

  it('requires dispute evidence notes or a file URL', async () => {
    const controller = new AdminController({} as never);

    await assert.rejects(
      () => controller.addDisputeEvidence({ user: { id: 'admin_1', isAdmin: true } }, 'dispute_1', {}),
      BadRequestException,
    );
  });

  it('requires subject and message when users create support tickets', () => {
    const controller = new UsersController({} as never);

    assert.throws(
      () => controller.supportTicket({ user: { id: 'user_1' } }, { subject: 'Help', message: '' }),
      BadRequestException,
    );
  });
});
