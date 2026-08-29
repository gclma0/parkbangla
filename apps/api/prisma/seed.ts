import { PrismaClient, AccessType, VerifiedStatus } from '@prisma/client';

const prisma = new PrismaClient();

const photos = [
  'https://images.unsplash.com/photo-1590674899484-d5640e854abe?w=1200',
  'https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=1200',
  'https://images.unsplash.com/photo-1486006920555-c77dcf18193c?w=1200',
  'https://images.unsplash.com/photo-1573348722427-f1d6819fdf98?w=1200',
];

async function main() {
  await prisma.checkIn.deleteMany();
  await prisma.review.deleteMany();
  await prisma.dispute.deleteMany();
  await prisma.transaction.deleteMany();
  await prisma.walletLedger.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.report.deleteMany();
  await prisma.booking.deleteMany();
  await prisma.spotBlock.deleteMany();
  await prisma.availability.deleteMany();
  await prisma.parkingSpot.deleteMany();
  await prisma.vehicle.deleteMany();
  await prisma.otpChallenge.deleteMany();
  await prisma.user.deleteMany();

  const renter = await prisma.user.create({
    data: {
      name: 'Nusrat Rahman',
      phone: '01710000001',
      walletBalance: 25000,
      ratingAvg: 4.8,
      ratingCount: 12,
      idVerified: true,
      locale: 'en',
    },
  });
  const host = await prisma.user.create({
    data: {
      name: 'Arif Chowdhury',
      phone: '01710000002',
      walletBalance: 1200,
      ratingAvg: 4.9,
      ratingCount: 40,
      idVerified: true,
    },
  });
  const host2 = await prisma.user.create({
    data: {
      name: 'Sadia Karim',
      phone: '01710000003',
      walletBalance: 800,
      ratingAvg: 4.6,
      ratingCount: 18,
      idVerified: true,
    },
  });
  await prisma.user.create({
    data: {
      name: 'ParkBangla Ops',
      phone: '01710000009',
      walletBalance: 0,
      isAdmin: true,
      idVerified: true,
    },
  });

  await prisma.vehicle.create({
    data: { userId: renter.id, plate: 'DHAKA-GA-12-3456', type: 'car', sizeClass: 'sedan' },
  });

  const listings = [
    {
      hostId: host.id,
      lat: 23.7808,
      lng: 90.4143,
      address: 'House 12, Road 53, Gulshan 2',
      area: 'Gulshan',
      covered: true,
      accessType: AccessType.GUARD,
      accessNotes: 'Tell the guard “ParkBangla — Arif”. PIN at gate.',
      hourlyPrice: 80,
      dailyPrice: 500,
      monthlyPrice: 9500,
      photos: [photos[0], photos[1]],
    },
    {
      hostId: host.id,
      lat: 23.794,
      lng: 90.4048,
      address: 'Banani 11, behind Kamal Ataturk Ave',
      area: 'Banani',
      covered: false,
      accessType: AccessType.GATE_CODE,
      accessNotes: 'Gate code shared after check-in.',
      hourlyPrice: 70,
      dailyPrice: 450,
      monthlyPrice: 8800,
      photos: [photos[2]],
    },
    {
      hostId: host2.id,
      lat: 23.7298,
      lng: 90.4175,
      address: 'Motijheel C/A, adjacent to Shapla Chattar',
      area: 'Motijheel',
      covered: true,
      accessType: AccessType.REMOTE,
      accessNotes: 'Boom barrier — host opens remotely.',
      hourlyPrice: 60,
      dailyPrice: 400,
      monthlyPrice: 7200,
      photos: [photos[3], photos[0]],
    },
    {
      hostId: host2.id,
      lat: 23.7815,
      lng: 90.416,
      address: 'Gulshan 1 circle, lane 7 driveway',
      area: 'Gulshan',
      covered: false,
      accessType: AccessType.GUARD,
      accessNotes: 'Residential compound. Weekdays only.',
      hourlyPrice: 75,
      dailyPrice: 480,
      monthlyPrice: 9000,
      photos: [photos[1]],
    },
  ];

  for (const l of listings) {
    const spot = await prisma.parkingSpot.create({
      data: {
        ...l,
        widthM: 2.5,
        lengthM: 5.2,
        vehicleSizes: 'sedan,suv',
        verifiedStatus: VerifiedStatus.VERIFIED,
        autoApprove: true,
      },
    });
    await prisma.availability.create({
      data: {
        spotId: spot.id,
        weekdays: [1, 2, 3, 4, 5],
        startTime: '09:00',
        endTime: '19:00',
      },
    });
  }

  console.log('Seeded ParkBangla demo users and Gulshan/Banani/Motijheel spots.');
}

main()
  .then(() => prisma.$disconnect())
  .catch((e) => {
    console.error(e);
    prisma.$disconnect();
    process.exit(1);
  });
