$ErrorActionPreference = 'Stop'

$candidates = @(
  'C:\Program Files\1cv8\conf\conf.cfg',
  'C:\Program Files\1cv8\8.3.27.1964\bin\conf\conf.cfg'
)

foreach ($p in $candidates) {
  Write-Output ("== " + $p + " ==")
  if (Test-Path -LiteralPath $p) {
    Get-Item -LiteralPath $p | Select-Object FullName,Length,LastWriteTime | Format-List | Out-String -Width 4096 | Write-Output
    Get-Content -LiteralPath $p -Encoding UTF8 | Out-String -Width 4096 | Write-Output
  } else {
    Write-Output 'MISSING'
  }
}
