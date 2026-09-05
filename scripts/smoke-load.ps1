param(
  [string]$BaseUrl = "https://parkbangla.onrender.com",
  [int]$Requests = 30
)

$ErrorActionPreference = "Stop"
$paths = @("/health", "/spots?area=Banani")

for ($i = 1; $i -le $Requests; $i++) {
  foreach ($path in $paths) {
    $url = "$BaseUrl$path"
    $started = Get-Date
    try {
      $response = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 30
      $ms = [int]((Get-Date) - $started).TotalMilliseconds
      Write-Output "$($response.StatusCode) $ms ms $url"
    } catch {
      $ms = [int]((Get-Date) - $started).TotalMilliseconds
      Write-Output "FAIL $ms ms $url $($_.Exception.Message)"
    }
  }
}
