import { spawnSync } from 'node:child_process';

function run(command, args) {
  const result = spawnSync(command, args, { stdio: 'inherit', shell: process.platform === 'win32' });
  return result.status ?? 1;
}

const status = run('npx', ['prisma', 'migrate', 'deploy']);

if (status === 0) {
  process.exit(0);
}

console.error(`
Prisma migrate deploy failed.

If this is the existing Render database that was previously managed with "prisma db push",
baseline it once before deploying this change:

  cd apps/api
  npx prisma migrate resolve --applied 20260905000000_baseline

Run that command against the Render DATABASE_URL, then redeploy.
`);

process.exit(status);
