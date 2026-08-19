param(
  [string]$BuildDir = 'T:\1S\wsl_exchange\work_epf_112_9\build',
  [string]$ServerDir = '{SHARE_ROOT}\epf1129'
)

$ErrorActionPreference = 'Stop'

$Compiled = Join-Path $BuildDir 'compiled.epf'
if (-not (Test-Path -LiteralPath $Compiled)) {
  throw "compiled.epf not found: $Compiled"
}
$WorkDir = Split-Path -Parent $BuildDir
$RecoveryContext = Join-Path $WorkDir 'context\recovery\other-pvh\out'
$RecoveryFiles = @(
  (Join-Path $RecoveryContext 'restore_map.csv'),
  (Join-Path $RecoveryContext 'x17_broken.csv')
)
foreach ($RecoveryFile in $RecoveryFiles) {
  if (-not (Test-Path -LiteralPath $RecoveryFile)) {
    throw "Recovery context file not found: $RecoveryFile"
  }
}

$LatestVersioned = Get-ChildItem -LiteralPath $BuildDir -File -Filter '*.epf' |
  Where-Object { $_.Name -ne 'compiled.epf' } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if ($null -eq $LatestVersioned) {
  throw "No versioned EPF found in: $BuildDir"
}

if (-not (Test-Path -LiteralPath $ServerDir)) {
  throw "Server directory not found: $ServerDir"
}

$DstCompiled = Join-Path $ServerDir 'compiled.epf'
$DstVersioned = Join-Path $ServerDir $LatestVersioned.Name

Copy-Item -Force $Compiled $DstCompiled
Copy-Item -Force $LatestVersioned.FullName $DstVersioned
$ServerRecoveryContext = Join-Path $ServerDir 'context\recovery\other-pvh\out'
New-Item -ItemType Directory -Force -Path $ServerRecoveryContext | Out-Null
foreach ($RecoveryFile in $RecoveryFiles) {
  Copy-Item -Force $RecoveryFile (Join-Path $ServerRecoveryContext (Split-Path -Leaf $RecoveryFile))
}

Get-Item $DstCompiled, $DstVersioned,
  (Join-Path $ServerRecoveryContext 'restore_map.csv'),
  (Join-Path $ServerRecoveryContext 'x17_broken.csv') |
  Select-Object FullName, Length, LastWriteTime |
  Format-List
