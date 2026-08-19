$ErrorActionPreference = 'Stop'

$V8Bin = 'C:\Program Files\1cv8\8.3.27.1964\bin\1cv8.exe'
$IbPath = 'T:\Base1s\Formula_GKHBuh7-1'
$DbUserB64 = 'EAQ0BDwEOAQ9BDgEQQRCBEAEMARCBD4EQAQ='
$DbPwdB64 = 'MQA1ADkAMwA1ADcAGQQ5BA=='

$WslRoot = '\\wsl$\Ubuntu\home\papaandrey\1S\epf1129'
$WinRoot = 'T:\1S\wsl_exchange\work_epf_112_9'
$WinStage = Join-Path $WinRoot 'stage'
$WinSrc = Join-Path $WinRoot 'src'
$WinLogs = Join-Path $WinRoot 'logs'
$LogFile = Join-Path $WinLogs 'decompile.log'

if (-not (Test-Path $V8Bin)) { throw "V8 binary not found: $V8Bin" }

New-Item -ItemType Directory -Force -Path $WinStage, $WinSrc, $WinLogs | Out-Null
Copy-Item -Force (Join-Path $WslRoot 'backup\source.epf') (Join-Path $WinStage 'source.epf')

$DbUser = if ([string]::IsNullOrWhiteSpace($env:EPF_DB_USER)) {
  [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($DbUserB64))
} else {
  $env:EPF_DB_USER
}
$DbPwd = if ([string]::IsNullOrWhiteSpace($env:EPF_DB_PWD)) {
  [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($DbPwdB64))
} else {
  $env:EPF_DB_PWD
}

$args = @(
  'DESIGNER',
  '/DisableStartupDialogs',
  "/F$IbPath",
  "/N$DbUser",
  "/P$DbPwd",
  '/DumpExternalDataProcessorOrReportToFiles',
  $WinSrc,
  (Join-Path $WinStage 'source.epf'),
  '/Out',
  $LogFile
)

$p = Start-Process -FilePath $V8Bin -ArgumentList $args -Wait -PassThru
$hasOutput = (Get-ChildItem -LiteralPath $WinSrc -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1) -ne $null

if (($p.ExitCode -ne 0) -and (-not $hasOutput)) {
  Write-Host "ERROR: decompile failed. See log: $LogFile"
  exit 1
}

$null = robocopy $WinSrc (Join-Path $WslRoot 'src') /MIR /R:1 /W:1
if ($LASTEXITCODE -ge 8) {
  Write-Host "ERROR: robocopy failed with code $LASTEXITCODE"
  exit 2
}

Write-Host 'OK'
