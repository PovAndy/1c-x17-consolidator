param(
  [Parameter(Mandatory = $true)]
  [string]$Alias,

  [Parameter(Mandatory = $true)]
  [string]$Timestamp
)

$ErrorActionPreference = 'Stop'

$root = '{SHARE_ROOT}\epf1129'
$runtimeDir = Join-Path $root 'runtime\autorun'
$logsDir = Join-Path $root 'logs\autorun'

$statusPath = Join-Path $runtimeDir ("status_{0}_{1}.json" -f $Alias, $Timestamp)
$logPrefix = "{0}_" -f $Alias

Write-Output ("RUNTIME_DIR={0}" -f $runtimeDir)
Write-Output ("LOGS_DIR={0}" -f $logsDir)
Write-Output ("STATUS_PATH={0}" -f $statusPath)

if (Test-Path -LiteralPath $runtimeDir) {
  Write-Output 'RUNTIME_CONTENT_BEGIN'
  Get-ChildItem -LiteralPath $runtimeDir |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 12 FullName,Length,LastWriteTime |
    Format-Table -AutoSize | Out-String -Width 4096 | Write-Output
  Write-Output 'RUNTIME_CONTENT_END'
} else {
  Write-Output 'RUNTIME_DIR_MISSING'
}

if (Test-Path -LiteralPath $logsDir) {
  Write-Output 'LOGS_CONTENT_BEGIN'
  Get-ChildItem -LiteralPath $logsDir |
    Where-Object { $_.Name -like ($logPrefix + '*') } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 20 FullName,Length,LastWriteTime |
    Format-Table -AutoSize | Out-String -Width 4096 | Write-Output
  Write-Output 'LOGS_CONTENT_END'
} else {
  Write-Output 'LOGS_DIR_MISSING'
}

if (Test-Path -LiteralPath $statusPath) {
  Write-Output 'STATUS_BEGIN'
  Get-Content -LiteralPath $statusPath -Raw -Encoding UTF8 | Write-Output
  Write-Output 'STATUS_END'
} else {
  Write-Output 'STATUS_MISSING'
}
