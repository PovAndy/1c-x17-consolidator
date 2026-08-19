$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$targets = @(
  'C:\Program Files\1cv8\conf\conf.cfg',
  '\\{V8_SERVER}\c$\Program Files\1cv8\conf\conf.cfg'
)
$line = 'DisableUnsafeActionProtection=.*MergedBase.*'
foreach ($path in $targets) {
  Write-Output ("== PATCH " + $path + " ==")
  if (-not (Test-Path -LiteralPath $path)) {
    Write-Output 'MISSING'
    continue
  }
  $backup = $path + '.codex_' + $timestamp + '.bak'
  Copy-Item -LiteralPath $path -Destination $backup -Force
  $content = Get-Content -LiteralPath $path -Encoding UTF8
  $filtered = @()
  foreach ($row in $content) {
    if ($row -match '^\s*DisableUnsafeActionProtection=') { continue }
    $filtered += $row
  }
  $filtered += $line
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines($path, $filtered, $utf8)
  Write-Output ('BACKUP=' + $backup)
  Write-Output 'CONTENT_BEGIN'
  Get-Content -LiteralPath $path -Encoding UTF8 | Out-String -Width 4096 | Write-Output
  Write-Output 'CONTENT_END'
}
