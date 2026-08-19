param(
  [string]$PlatformVersion = '8.3.27.1989',
  [string]$WslDistro = $env:EPF_WSL_DISTRO,
  [switch]$AuditOnly
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($WslDistro)) {
  $WslDistro = 'Ubuntu'
}

$AuditWslPython = '{PROJECT_ROOT}/.venv-gemini-bridge/bin/python'
$AuditWslScript = '{PROJECT_ROOT}/scripts/run_targeted_audit.py'
& wsl.exe -d $WslDistro -- $AuditWslPython $AuditWslScript --gate
if ($LASTEXITCODE -ne 0) {
  throw "Сборка заблокирована таргетированным аудитом. Проверьте temp/audit_report.html и устраните High Severity."
}
if ($AuditOnly) {
  Write-Host 'AUDIT_ONLY_OK'
  exit 0
}

$V8Bin = Join-Path 'C:\Program Files\1cv8' "$PlatformVersion\bin\1cv8.exe"
if (-not (Test-Path -LiteralPath $V8Bin)) {
  throw "1C binary not found for required platform $PlatformVersion`: $V8Bin"
}
$IbPath = 'T:\Base1s\Formula_GKHBuh7-1'
$DbUserB64 = 'EAQ0BDwEOAQ9BDgEQQRCBEAEMARCBD4EQAQ='
$DbPwdB64 = 'MQA1ADkAMwA1ADcAGQQ5BA=='

$WslRoot = "\\wsl$\$WslDistro\home\papaandrey\1S\epf1129"
$WinRoot = 'T:\1S\wsl_exchange\work_epf_112_9'
$WinSrc = Join-Path $WinRoot 'src'
$WinBuild = Join-Path $WinRoot 'build'
$WinLogs = Join-Path $WinRoot 'logs'
$LogFile = Join-Path $WinLogs 'compile.log'
$OutEpf = Join-Path $WinBuild 'compiled.epf'

if (-not (Test-Path $V8Bin)) { throw "V8 binary not found: $V8Bin" }
if (-not (Test-Path (Join-Path $WslRoot 'src'))) { throw "WSL src not found: $WslRoot\\src" }

New-Item -ItemType Directory -Force -Path $WinSrc, $WinBuild, $WinLogs | Out-Null
$null = robocopy (Join-Path $WslRoot 'src') $WinSrc /MIR /R:1 /W:1
if ($LASTEXITCODE -ge 8) {
  Write-Host "ERROR: robocopy failed with code $LASTEXITCODE"
  exit 2
}

$RootXml = Get-ChildItem -LiteralPath $WinSrc -File -Filter *.xml -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $RootXml) {
  Write-Host "ERROR: root xml file not found in $WinSrc"
  exit 3
}

$ObjectModule = Get-ChildItem -LiteralPath $WinSrc -Recurse -File -Filter ObjectModule.bsl -ErrorAction SilentlyContinue | Select-Object -First 1
$Version = $null
if ($null -ne $ObjectModule) {
  foreach ($enc in @('UTF8', 'Default', 'Unicode')) {
    try {
      $ModuleText = Get-Content -LiteralPath $ObjectModule.FullName -Raw -Encoding $enc
      $VersionMatch = [regex]::Match($ModuleText, '"(v25-[0-9]+\.[0-9]+)"')
      if (-not $VersionMatch.Success) {
        $VersionMatch = [regex]::Match($ModuleText, '(v[0-9]+-[0-9]+\.[0-9]+)')
      }
      if ($VersionMatch.Success) {
        $Version = $VersionMatch.Groups[1].Value
        break
      }
    } catch {
    }
  }
}

$SafeBaseName = ($RootXml.BaseName -replace '[^\p{L}\p{Nd}_\.-]', '_')
$VersionedFileName = if ([string]::IsNullOrWhiteSpace($Version)) {
  "$SafeBaseName.epf"
} else {
  "${SafeBaseName}_${Version}.epf"
}
$OutEpfVersioned = Join-Path $WinBuild $VersionedFileName

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

$DesignerArgs = @(
  'DESIGNER',
  '/DisableStartupDialogs',
  "/F$IbPath",
  "/N$DbUser",
  "/P$DbPwd",
  '/LoadExternalDataProcessorOrReportFromFiles',
  $RootXml.FullName,
  $OutEpfVersioned,
  '/Out',
  $LogFile
)

$p = Start-Process -FilePath $V8Bin -ArgumentList $DesignerArgs -Wait -PassThru
$hasOutput = Test-Path -LiteralPath $OutEpfVersioned

if (($p.ExitCode -ne 0) -and (-not $hasOutput)) {
  Write-Host "ERROR: compile failed. See log: $LogFile"
  exit 1
}

Copy-Item -Force $OutEpfVersioned $OutEpf
Copy-Item -Force $OutEpfVersioned (Join-Path $WslRoot 'build\compiled.epf')
Copy-Item -Force $OutEpfVersioned (Join-Path $WslRoot ("build\" + $VersionedFileName))
Write-Host 'OK'
