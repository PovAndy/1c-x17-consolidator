param(
  [string]$Alias = 'x17',
  [string]$Action,
  [string]$LsNo = '',
  [string]$DocNo = '',
  [string]$EpfPath = '',
  [switch]$LatestBuild,
  [switch]$ShowWindow,
  [switch]$UseSharedRuntime,
  [string]$ReportPath = '',
  [string]$StatusPath = '',
  [string]$JobPath = '',
  [string]$OutLogPath = '',
  [string]$RestoreMapPath = '',
  [int]$TimeoutSec = 900
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Action)) {
  throw 'Specify -Action'
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir '1c-bases.win.json'
$ProjectRoot = Split-Path -Parent $ScriptDir
$EnvPath = Join-Path $ProjectRoot '.env'

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Config not found: $ConfigPath"
}

$Config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$V8Bin = $Config.v8_bin
$WslRoot = $Config.wsl_root
$WinRoot = $ProjectRoot
$SharedRuntimeRoot = ''
if ($Config.PSObject.Properties.Name -contains 'shared_runtime_root' -and -not [string]::IsNullOrWhiteSpace([string]$Config.shared_runtime_root)) {
  $SharedRuntimeRoot = [string]$Config.shared_runtime_root
}
$LocalLockDir = Join-Path $WslRoot 'runtime\locks'
$Base = $Config.bases.$Alias
if ($null -eq $Base) {
  throw "Base alias not found: $Alias"
}

$BaseType = 'file'
if ($Base.PSObject.Properties.Name -contains 'type' -and -not [string]::IsNullOrWhiteSpace([string]$Base.type)) {
  $BaseType = ([string]$Base.type).ToLowerInvariant()
}

if ($BaseType -ne 'server' -and $BaseType -ne 'file') {
  throw "Unsupported base type: $BaseType"
}

if (Test-Path -LiteralPath $EnvPath) {
  $EnvLines = Get-Content -LiteralPath $EnvPath -Encoding UTF8
  foreach ($line in $EnvLines) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) { continue }
    $eqPos = $trimmed.IndexOf('=')
    if ($eqPos -lt 1) { continue }
    $name = $trimmed.Substring(0, $eqPos).Trim()
    $value = $trimmed.Substring($eqPos + 1).Trim()
    if ($name -eq 'EPF_DB_USER' -and [string]::IsNullOrWhiteSpace($env:EPF_DB_USER)) { $env:EPF_DB_USER = $value }
    if ($name -eq 'EPF_DB_PWD' -and [string]::IsNullOrWhiteSpace($env:EPF_DB_PWD)) { $env:EPF_DB_PWD = $value }
  }
}

if ($LatestBuild) {
  $EpfPath = Join-Path $WinRoot 'build\compiled.epf'
}
if ([string]::IsNullOrWhiteSpace($EpfPath)) {
  throw 'Specify -EpfPath or use -LatestBuild'
}
$PreferredLocalCompiled = 'T:\1S\wsl_exchange\work_epf_112_9\build\compiled.epf'
$PreferredWslCompiled = '\\wsl$\Ubuntu\home\papaandrey\1S\epf1129\build\compiled.epf'
$UseSharedRuntime = ($UseSharedRuntime.IsPresent -and $BaseType -eq 'server' -and -not [string]::IsNullOrWhiteSpace($SharedRuntimeRoot))
$RuntimeRoot = $(if ($UseSharedRuntime) { $SharedRuntimeRoot } else { $WinRoot })
$SharedEpfPath = ''
if ($LatestBuild -and $BaseType -eq 'server') {
  if (Test-Path -LiteralPath $PreferredLocalCompiled) {
    $EpfPath = $PreferredLocalCompiled
  } elseif (Test-Path -LiteralPath $PreferredWslCompiled) {
    $EpfPath = $PreferredWslCompiled
  }
}
if ($BaseType -eq 'server' -and -not [string]::IsNullOrWhiteSpace($SharedRuntimeRoot) -and ($EpfPath -eq (Join-Path $WinRoot 'build\compiled.epf'))) {
  $SharedEpfPath = Join-Path $SharedRuntimeRoot 'compiled.epf'
  if ($LatestBuild -and (Test-Path -LiteralPath $SharedEpfPath)) {
    $EpfPath = $SharedEpfPath
  }
}
if (-not (Test-Path -LiteralPath $EpfPath)) {
  throw "EPF path not found: $EpfPath"
}
$AutorunDir = Join-Path $RuntimeRoot 'runtime\autorun'
$LockDir = $LocalLockDir
foreach ($dir in @($AutorunDir, $LockDir)) {
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
}

$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($JobPath)) {
  $JobPath = Join-Path $AutorunDir 'job.json'
}
if ([string]::IsNullOrWhiteSpace($StatusPath)) {
  $StatusPath = Join-Path $AutorunDir ("status_{0}_{1}.json" -f $Alias, $Timestamp)
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportDir = Join-Path $RuntimeRoot 'logs\autorun'
  if (-not (Test-Path -LiteralPath $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
  }
  $SafeAction = ($Action -replace '[^a-zA-Z0-9_-]', '_')
  $ReportPath = Join-Path $ReportDir ("{0}_{1}_{2}.md" -f $Alias, $SafeAction, $Timestamp)
}
if ([string]::IsNullOrWhiteSpace($OutLogPath)) {
  $OutLogDir = Join-Path $RuntimeRoot 'logs\autorun'
  if (-not (Test-Path -LiteralPath $OutLogDir)) {
    New-Item -ItemType Directory -Path $OutLogDir -Force | Out-Null
  }
  $SafeAction = ($Action -replace '[^a-zA-Z0-9_-]', '_')
  $OutLogPath = Join-Path $OutLogDir ("{0}_{1}_{2}.out.log" -f $Alias, $SafeAction, $Timestamp)
}

if ([string]::IsNullOrWhiteSpace($RestoreMapPath)) {
  $RestoreMapPath = Join-Path $WinRoot 'context\recovery\other-pvh\out\restore_map.csv'
}
if ($BaseType -eq 'server' -and -not [string]::IsNullOrWhiteSpace($SharedRuntimeRoot) -and -not [string]::IsNullOrWhiteSpace($RestoreMapPath) -and (Test-Path -LiteralPath $RestoreMapPath)) {
  $SharedRestoreMapDir = Join-Path $RuntimeRoot 'context\recovery\other-pvh\out'
  if (-not $UseSharedRuntime) {
    $SharedRestoreMapDir = Join-Path $SharedRuntimeRoot 'context\recovery\other-pvh\out'
  }
  if (-not (Test-Path -LiteralPath $SharedRestoreMapDir)) {
    New-Item -ItemType Directory -Path $SharedRestoreMapDir -Force | Out-Null
  }
  $SharedRestoreMapPath = Join-Path $SharedRestoreMapDir 'restore_map.csv'
  Copy-Item -LiteralPath $RestoreMapPath -Destination $SharedRestoreMapPath -Force
  $RestoreMapPath = $SharedRestoreMapPath
}

foreach ($path in @($JobPath, $StatusPath)) {
  if (Test-Path -LiteralPath $path) {
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
  }
}

$LockPath = Join-Path $LockDir ("{0}.lock.json" -f $Alias)
if (Test-Path -LiteralPath $LockPath) {
  try {
    $LockInfo = Get-Content -LiteralPath $LockPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $LockPid = 0
    if ($LockInfo.PSObject.Properties.Name -contains 'pid') {
      $LockPid = [int]$LockInfo.pid
    }
    if ($LockPid -gt 0) {
      $Existing = Get-Process -Id $LockPid -ErrorAction SilentlyContinue
      if ($null -ne $Existing) {
        Write-Host ("Already running {0}: pid={1} client={2}" -f $Alias, $LockPid, $LockInfo.client)
        exit 10
      }
    }
  } catch {
  }
  Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
}

$job = [ordered]@{
  action = $Action
  ls_filter = $LsNo
  doc_filter = $DocNo
  report_path = $ReportPath
  status_path = $StatusPath
  out_log_path = $OutLogPath
  restore_map_path = $RestoreMapPath
  close_on_finish = $true
  created_at = (Get-Date).ToString('s')
  base_alias = $Alias
}
$job | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JobPath -Encoding UTF8

$LaunchArgs = @('ENTERPRISE')
if ($BaseType -eq 'server') {
  $LaunchArgs += "/S$($Base.server)\$($Base.ref)"
} else {
  $LaunchArgs += "/F$($Base.path)"
}
if (-not [string]::IsNullOrWhiteSpace($env:EPF_DB_USER)) { $LaunchArgs += "/N$($env:EPF_DB_USER)" }
if (-not [string]::IsNullOrWhiteSpace($env:EPF_DB_PWD)) { $LaunchArgs += "/P$($env:EPF_DB_PWD)" }
$LaunchArgs += '/DisableStartupDialogs'
$LaunchArgs += '/DisableStartupMessages'
$LaunchArgs += '/DisableUnrecoverableErrorMessage'
$LaunchArgs += '/Execute'
$LaunchArgs += $EpfPath
$LaunchArgs += '/Out'
$LaunchArgs += $OutLogPath

$LaunchBin = $V8Bin
if ($BaseType -eq 'server') {
  # For server bases, /Execute in thin client tends to get stuck before the form
  # starts (likely on hidden startup/security dialogs). Prefer the full client.
  $LaunchBin = $V8Bin
}

if (-not (Test-Path -LiteralPath $LaunchBin)) {
  throw "1C binary not found: $LaunchBin"
}

Write-Host ("Autorun action: {0}" -f $Action)
Write-Host ("Base: {0}" -f $Alias)
Write-Host ("Client: {0}" -f $LaunchBin)
Write-Host ("Window: {0}" -f $(if ($ShowWindow) { 'shown' } else { 'hidden' }))
Write-Host ("Job: {0}" -f $JobPath)
Write-Host ("Status: {0}" -f $StatusPath)
Write-Host ("Report: {0}" -f $ReportPath)
Write-Host ("OutLog: {0}" -f $OutLogPath)

$StartProcessParams = @{
  FilePath = $LaunchBin
  ArgumentList = $LaunchArgs
  PassThru = $true
}
if (-not $ShowWindow) {
  $StartProcessParams['WindowStyle'] = 'Hidden'
}
$proc = Start-Process @StartProcessParams
$LockInfo = [ordered]@{
  alias = $Alias
  pid = $proc.Id
  client = $LaunchBin
  started_at = (Get-Date).ToString('s')
  mode = 'autorun'
  action = $Action
}
$LockInfo | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $LockPath -Encoding UTF8
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
  if (Test-Path -LiteralPath $StatusPath) {
    $status = Get-Content -LiteralPath $StatusPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $CurrentStatus = [string]$status.status
    if ($CurrentStatus -eq 'started') {
      Start-Sleep -Seconds 2
      continue
    }
    Write-Host ("STATUS={0}" -f $status.status)
    Write-Host ("SUMMARY={0}" -f $status.summary)
    Write-Host ("REPORT={0}" -f $status.report_path)
    try {
      $RunningProcess = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
      if ($null -ne $RunningProcess) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
      }
    } catch {
    }
    Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
    if ($status.success) {
      exit 0
    }
    exit 1
  }
  Start-Sleep -Seconds 2
}

Write-Host 'STATUS=timeout'
Write-Host ("ProcessId={0}" -f $proc.Id)
Write-Host ("No status file after {0} sec" -f $TimeoutSec)
try {
  $RunningProcess = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
  if ($null -ne $RunningProcess) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  }
} catch {
}
Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
exit 124
