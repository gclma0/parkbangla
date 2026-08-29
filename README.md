# ParkBangla

Peer-to-peer parking (Commuter Pass) for Dhaka. Flutter apps + NestJS API.

Postgres in Docker is published on **host port 5433** (5432 is often already used on Windows).

## Run

```bash
docker compose up -d
cd apps/api
copy .env.example .env   # Windows
npm install
npx prisma db push
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
