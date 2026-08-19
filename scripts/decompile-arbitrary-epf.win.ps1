param(
  [Parameter(Mandatory = $true)]
  [string]$EpfPath,

  [Parameter(Mandatory = $true)]
  [string]$OutDir,

  [string]$V8Bin = 'C:\Program Files\1cv8\8.3.27.1964\bin\1cv8.exe',
  [string]$IbPath = 'T:\Base1s\Formula_GKHBuh7-1',
  [string]$EnvPath = '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\.env',
  [string]$LogPath = '',
  [string]$DbUser = '',
  [string]$DbPwd = ''
)

$ErrorActionPreference = 'Stop'

function Read-DotEnvMap {
  param([string]$Path)

  $map = @{}
  if (-not (Test-Path -LiteralPath $Path)) {
    return $map
  }

  $utf8 = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::ReadAllLines($Path, $utf8) | ForEach-Object {
    if ([string]::IsNullOrWhiteSpace($_)) { return }
    if ($_.TrimStart().StartsWith('#')) { return }
    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) {
      $map[$parts[0].Trim()] = $parts[1].Trim()
    }
  }

  return $map
}

if (-not (Test-Path -LiteralPath $V8Bin)) { throw "V8 binary not found: $V8Bin" }
if (-not (Test-Path -LiteralPath $EpfPath)) { throw "EPF not found: $EpfPath" }

$envMap = Read-DotEnvMap -Path $EnvPath
$user = if ([string]::IsNullOrWhiteSpace($DbUser)) { $envMap['EPF_DB_USER'] } else { $DbUser }
$pwd = if ([string]::IsNullOrWhiteSpace($DbPwd)) { $envMap['EPF_DB_PWD'] } else { $DbPwd }
if ([string]::IsNullOrWhiteSpace($user)) {
  $user = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('EAQ0BDwEOAQ9BDgEQQRCBEAEMARCBD4EQAQ='))
}
if ([string]::IsNullOrWhiteSpace($pwd)) {
  $pwd = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('MQA1ADkAMwA1ADcAGQQ5BA=='))
}

if ([string]::IsNullOrWhiteSpace($LogPath)) {
  $LogPath = Join-Path ([System.IO.Path]::GetDirectoryName($OutDir)) 'decompile-arbitrary.log'
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Get-ChildItem -LiteralPath $OutDir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

$args = @(
  'DESIGNER',
  '/DisableStartupDialogs',
  "/F$IbPath",
  "/N$user",
  "/P$pwd",
  '/DumpExternalDataProcessorOrReportToFiles',
  $OutDir,
  $EpfPath,
  '/Out',
  $LogPath
)

$proc = Start-Process -FilePath $V8Bin -ArgumentList $args -Wait -PassThru
Write-Output ("EXIT=" + $proc.ExitCode)
Write-Output ("OUTDIR=" + $OutDir)
Write-Output ("LOG=" + $LogPath)
if ($proc.ExitCode -ne 0) {
  exit $proc.ExitCode
}
