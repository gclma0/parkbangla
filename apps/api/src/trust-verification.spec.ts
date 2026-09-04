import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { BadRequestException } from '@nestjs/common';
import { VerifiedStatus } from '@prisma/client';
import { AdminController } from './admin.controller';
import { SpotsController } from './spots.controller';

describe('trust and spot verification', () => {
  it('requires listing proof fields before spot creation', async () => {
    const controller = new SpotsController({} as never);

    assert.throws(
      () =>
        controller.create(
          { user: { id: 'host_1' } },
          {
            lat: 23.7806,
            lng: 90.4143,
            address: 'Road 11',
            area: 'Banani',
            accessNotes: '',
            hourlyPrice: 80,
            dailyPrice: 500,
            monthlyPrice: 9000,
          },
        ),
      BadRequestException,
    );
  });

  it('stores nearby duplicate candidates on new spots', async () => {
    const prisma = {
      parkingSpot: {
        findMany: async () => [
          {
            id: 'spot_existing',
            hostId: 'host_2',
            lat: 23.78061,
            lng: 90.41431,
            address: 'Road 11',
            area: 'Banani',
          },
        ],
        create: async (args: { data: { duplicateCandidateIds: string[] } }) => args.data,
      },
    };
    const controller = new SpotsController(prisma as never);

    const result = await controller.create(
      { user: { id: 'host_1' } },
      {
        lat: 23.7806,
        lng: 90.4143,
        address: 'Road 11',
        area: 'Banani',
        accessNotes: 'Use south entrance',
        entrancePhotoUrl: 'https://example.com/entrance.jpg',
        bayPhotoUrl: 'https://example.com/bay.jpg',
        ownershipProofUrl: 'https://example.com/proof.pdf',
        hourlyPrice: 80,
        dailyPrice: 500,
        monthlyPrice: 9000,
      },
    );

    assert.deepEqual((result as { duplicateCandidateIds: string[] }).duplicateCandidateIds, ['spot_existing']);
  });

  it('requires an admin rejection reason for spot rejection', async () => {
    const controller = new AdminController({} as never);

    await assert.rejects(
      () => controller.verifySpot({ user: { isAdmin: true } }, 'spot_1', { status: VerifiedStatus.REJECTED }),
      BadRequestException,
    );
  });
});
