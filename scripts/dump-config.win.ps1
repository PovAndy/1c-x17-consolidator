param(
  [string]$Alias = 'x1_21',
  [string]$OutRoot = 'T:\1S\wsl_exchange\work_epf_112_9\config-dumps'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir '1c-bases.win.json'
$ProjectRoot = Split-Path -Parent $ScriptDir
$EnvPath = Join-Path $ProjectRoot '.env'

if (Test-Path -LiteralPath $EnvPath) {
  Get-Content -LiteralPath $EnvPath -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { return }
    if ($line.StartsWith('#')) { return }
    $parts = $line -split '=', 2
    if ($parts.Count -ne 2) { return }
    if ($parts[0].Trim() -eq 'EPF_DB_USER' -and [string]::IsNullOrWhiteSpace($env:EPF_DB_USER)) { $env:EPF_DB_USER = $parts[1].Trim() }
    if ($parts[0].Trim() -eq 'EPF_DB_PWD' -and [string]::IsNullOrWhiteSpace($env:EPF_DB_PWD)) { $env:EPF_DB_PWD = $parts[1].Trim() }
  }
}

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$base = $config.bases.$Alias
if ($null -eq $base) { throw "Unknown alias: $Alias" }
$v8 = $config.v8_bin
if (-not (Test-Path -LiteralPath $v8)) { throw "1cv8.exe not found: $v8" }
if (-not (Test-Path -LiteralPath $base.path)) { throw "Base path not found: $($base.path)" }

$outDir = Join-Path $OutRoot $Alias
$logDir = Join-Path $OutRoot '_logs'
$log = Join-Path $logDir ("dump_config_{0}_{1}.log" -f $Alias, (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force -Path $outDir, $logDir | Out-Null

$args = @(
  'DESIGNER',
  '/DisableStartupDialogs',
  "/F$($base.path)",
  "/N$($env:EPF_DB_USER)",
  "/P$($env:EPF_DB_PWD)",
  '/DumpConfigToFiles',
  $outDir,
  '/Out',
  $log
)

$p = Start-Process -FilePath $v8 -ArgumentList $args -Wait -PassThru
Write-Output ('EXIT=' + $p.ExitCode)
Write-Output ('OUTDIR=' + $outDir)
Write-Output ('LOG=' + $log)
if ($p.ExitCode -ne 0) { exit $p.ExitCode }
