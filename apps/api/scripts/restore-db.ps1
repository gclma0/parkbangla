param(
  [Parameter(Mandatory = $true)]
  [string]$BackupFile
)

if (-not $env:DATABASE_URL) {
  Write-Error "DATABASE_URL is required."
  exit 1
}

if (-not (Test-Path -LiteralPath $BackupFile)) {
  Write-Error "Backup file not found: $BackupFile"
  exit 1
}

if (-not (Get-Command pg_restore -ErrorAction SilentlyContinue)) {
  Write-Error "pg_restore is required. Install PostgreSQL client tools first."
  exit 1
}

pg_restore --clean --if-exists --no-owner --dbname=$env:DATABASE_URL $BackupFile
exit $LASTEXITCODE
