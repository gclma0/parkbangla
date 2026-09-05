param(
  [string]$OutputDir = ".\backups"
)

if (-not $env:DATABASE_URL) {
  Write-Error "DATABASE_URL is required."
  exit 1
}

if (-not (Get-Command pg_dump -ErrorAction SilentlyContinue)) {
  Write-Error "pg_dump is required. Install PostgreSQL client tools first."
  exit 1
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$file = Join-Path $OutputDir "parkbangla-$stamp.dump"

pg_dump $env:DATABASE_URL --format=custom --file=$file
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Output "Backup written to $file"
