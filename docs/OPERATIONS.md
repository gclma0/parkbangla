# ParkBangla Operations

## Environments

- Development: local Docker Postgres, demo OTP, local uploads.
- Staging: Render service and staging database with non-production data.
- Production: Render production service and production database.

Required API variables:

- `DATABASE_URL`
- `JWT_SECRET`
- `PORT`
- `NODE_ENV`
- `DEMO_OTP` until paid OTP is integrated
- `FIREBASE_SERVICE_ACCOUNT` when real push delivery is enabled
- `SENTRY_DSN` when error tracking is enabled

Mobile/admin builds should set `API_URL` with `--dart-define`.

## Database Migrations

The repository now has a Prisma baseline migration at:

`apps/api/prisma/migrations/20260905000000_baseline/migration.sql`

For a new database, deploy normally:

```bash
cd apps/api
npm run migrate:deploy
```

For the existing Render database that was previously managed by `prisma db push`, baseline it once before switching deployment to migrations:

```bash
cd apps/api
npx prisma migrate resolve --applied 20260905000000_baseline
```

Run that command with the Render `DATABASE_URL`. After that, future schema changes should be created with Prisma migrations and deployed with `npm run migrate:deploy`.

## Backups

Install PostgreSQL client tools so `pg_dump` and `pg_restore` are available.

Create a backup:

```powershell
cd apps/api
$env:DATABASE_URL="postgresql://..."
npm run backup:db
```

Restore into a test database first:

```powershell
cd apps/api
$env:DATABASE_URL="postgresql://..."
npm run restore:db -- .\backups\parkbangla-YYYYMMDD-HHMMSS.dump
```

Do not restore over production until the backup has been tested against a disposable database.

## Monitoring

- Health check: `GET /health`
- Expected healthy response: `ok=true`, `database=up`
- Render should monitor `/health`.
- GitHub workflow `.github/workflows/keep-render-awake.yml` can keep the free Render API warm during testing.
- API logs are structured JSON. Keep `LOG_HEADERS=false` unless debugging locally.

## Incident Checklist

- Check Render deploy status and logs.
- Hit `/health` and confirm database status.
- Check recent admin audit logs for destructive operations.
- Check support tickets, disputes, reports, and risk flags in the admin app.
- Take a database backup before any manual data repair.
