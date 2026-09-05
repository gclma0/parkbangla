# ParkBangla

Peer-to-peer parking (Commuter Pass) for Dhaka. Flutter apps + NestJS API.

Postgres in Docker is published on **host port 5433** (5432 is often already used on Windows).

## Run

```bash
docker compose up -d
cd apps/api
copy .env.example .env   # Windows
npm install
npm run migrate:deploy
npm run seed
npm run start:dev
# API listens on http://localhost:3001 (port 3000 is often taken)
```

```bash
cd apps/mobile
flutter pub get
flutter run -d chrome
```

```bash
cd apps/admin
flutter pub get
flutter run -d chrome
```

Demo OTP is always `123456`. Demo phones: `01710000001` (renter), `01710000002` (host), `01710000009` (admin).

## Production Notes

- Deployment uses Prisma migrations through `npm run migrate:deploy`.
- The existing Render database must be baselined once if it was previously created with `prisma db push`; see [docs/OPERATIONS.md](docs/OPERATIONS.md).
- Legal and launch policy drafts are in [docs/POLICIES.md](docs/POLICIES.md).
- CI runs API validation/build/tests plus Flutter analyze/tests for mobile and admin.
