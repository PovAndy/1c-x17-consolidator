param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ArgList
)

$ErrorActionPreference = 'Stop'

$Alias = $null
$LaunchMode = 'enterprise'
$EpfPath = $null
$LatestBuild = $false
$List = $false

for ($i = 0; $i -lt $ArgList.Count; $i++) {
  $arg = [string]$ArgList[$i]
  switch -Regex ($arg) {
    '^-List$' {
      $List = $true
      continue
    }
    '^-LatestBuild$' {
      $LatestBuild = $true
      continue
    }
    '^-Alias$' {
      if ($i + 1 -ge $ArgList.Count) { throw "Missing value after -Alias" }
      $i++
      $Alias = [string]$ArgList[$i]
      continue
    }
    '^-LaunchMode$' {
      if ($i + 1 -ge $ArgList.Count) { throw "Missing value after -LaunchMode" }
      $i++
      $LaunchMode = ([string]$ArgList[$i]).ToLowerInvariant()
      continue
    }
    '^-EpfPath$' {
      if ($i + 1 -ge $ArgList.Count) { throw "Missing value after -EpfPath" }
      $i++
      $EpfPath = [string]$ArgList[$i]
      continue
    }
    default {
      throw "Unknown argument: $arg"
    }
  }
}

if (($LaunchMode -ne 'enterprise') -and ($LaunchMode -ne 'designer')) {
  throw "Unsupported -LaunchMode value: $LaunchMode"
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir '1c-bases.win.json'
$ProjectRoot = Split-Path -Parent $ScriptDir
$EnvPath = Join-Path $ProjectRoot '.env'

if (Test-Path -LiteralPath $EnvPath) {
  $EnvLines = Get-Content -LiteralPath $EnvPath -Encoding UTF8
  foreach ($line in $EnvLines) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
    if ($trimmed.StartsWith('#')) { continue }
    $eqPos = $trimmed.IndexOf('=')
    if ($eqPos -lt 1) { continue }
    $name = $trimmed.Substring(0, $eqPos).Trim()
    $value = $trimmed.Substring($eqPos + 1).Trim()
    if ($name -eq 'EPF_DB_USER' -and [string]::IsNullOrWhiteSpace($env:EPF_DB_USER)) {
      $env:EPF_DB_USER = $value
      continue
    }
    if ($name -eq 'EPF_DB_PWD' -and [string]::IsNullOrWhiteSpace($env:EPF_DB_PWD)) {
      $env:EPF_DB_PWD = $value
      continue
    }
  }
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Config not found: $ConfigPath"
}

$Config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$V8Bin = $Config.v8_bin
$WslRoot = $Config.wsl_root
$LockDir = Join-Path $WslRoot 'runtime\locks'

if ($List) {
  Write-Host "Available base aliases:"
  foreach ($baseProp in $Config.bases.PSObject.Properties) {
    $item = $baseProp.Value
    Write-Host ("- {0}: {1} [{2}]" -f $baseProp.Name, $item.path, $item.role)
  }
  exit 0
}

if ([string]::IsNullOrWhiteSpace($Alias)) {
  throw "Specify -Alias or use -List"
}

$Base = $Config.bases.$Alias
if ($null -eq $Base) {
  throw "Base alias not found: $Alias"
}

$BaseKind = 'file'
if ($Base.PSObject.Properties.Name -contains 'type' -and -not [string]::IsNullOrWhiteSpace([string]$Base.type)) {
  $BaseKind = ([string]$Base.type).ToLowerInvariant()
}

if ($BaseKind -eq 'file') {
  if (-not (Test-Path -LiteralPath $Base.path)) {
    throw "Base path not found: $($Base.path)"
  }
} elseif ($BaseKind -ne 'server') {
  throw "Unsupported base type: $BaseKind"
}

$LaunchBin = $V8Bin
if ($LaunchMode -eq 'enterprise' -and $BaseKind -eq 'server') {
  $ThinCandidate = Join-Path (Split-Path -Parent $V8Bin) '1cv8c.exe'
  if (Test-Path -LiteralPath $ThinCandidate) {
    $LaunchBin = $ThinCandidate
  }
}

if (-not (Test-Path -LiteralPath $LaunchBin)) {
  throw "1C binary not found: $LaunchBin"
}

if (-not (Test-Path -LiteralPath $LockDir)) {
  New-Item -ItemType Directory -Path $LockDir -Force | Out-Null
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

$ResolvedEpf = $null
if ($LatestBuild) {
  $LatestEpf = Join-Path $WslRoot 'build\compiled.epf'
  if (-not (Test-Path -LiteralPath $LatestEpf)) {
    throw "Latest compiled EPF not found: $LatestEpf"
  }
  $ResolvedEpf = $LatestEpf
} elseif (-not [string]::IsNullOrWhiteSpace($EpfPath)) {
  if (-not (Test-Path -LiteralPath $EpfPath)) {
    throw "EPF path not found: $EpfPath"
  }
  $ResolvedEpf = $EpfPath
}

$LaunchArgs = @()
if ($LaunchMode -eq 'designer') {
  $LaunchArgs += 'DESIGNER'
} else {
  $LaunchArgs += 'ENTERPRISE'
}

if ($BaseKind -eq 'server') {
  if ([string]::IsNullOrWhiteSpace([string]$Base.server) -or [string]::IsNullOrWhiteSpace([string]$Base.ref)) {
    throw "Server base config must contain 'server' and 'ref'"
  }
  $LaunchArgs += "/S$($Base.server)\$($Base.ref)"
} else {
  $LaunchArgs += "/F$($Base.path)"
}

if (-not [string]::IsNullOrWhiteSpace($env:EPF_DB_USER)) {
  $LaunchArgs += "/N$($env:EPF_DB_USER)"
}

if (-not [string]::IsNullOrWhiteSpace($env:EPF_DB_PWD)) {
  $LaunchArgs += "/P$($env:EPF_DB_PWD)"
}

if ($ResolvedEpf) {
  $LaunchArgs += '/Execute'
  $LaunchArgs += $ResolvedEpf
}

if ($BaseKind -eq 'server') {
  Write-Host ("Opening {0}: {1}\\{2}" -f $Alias, $Base.server, $Base.ref)
} else {
  Write-Host ("Opening {0}: {1}" -f $Alias, $Base.path)
}
if ($ResolvedEpf) {
  Write-Host ("EPF: {0}" -f $ResolvedEpf)
}

$Started = Start-Process -FilePath $LaunchBin -ArgumentList $LaunchArgs -PassThru
$LockInfo = [ordered]@{
  alias = $Alias
  pid = $Started.Id
  client = $LaunchBin
  started_at = (Get-Date).ToString('s')
  mode = $LaunchMode
}
$LockInfo | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $LockPath -Encoding UTF8
