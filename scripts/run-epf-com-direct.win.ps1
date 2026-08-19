param(
  [Parameter(Mandatory = $true)]
  [string]$Alias,

  [Parameter(Mandatory = $true)]
  [string]$Method,

  [string]$MethodArg = '',

  [string]$EpfPath = 'T:\1S\wsl_exchange\work_epf_112_9\build\compiled.epf',
  [string]$OutFile = '',
  [string]$ConfigPath = '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-bases.win.json',
  [string]$EnvPath = '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\.env'
)

$ErrorActionPreference = 'Stop'

. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function U([int[]]$codes) {
  return -join ($codes | ForEach-Object { [char]$_ })
}

$bindingFlags = [System.Reflection.BindingFlags]'Public,Instance,GetProperty,InvokeMethod'
$nameExternalProcessors = U @(1042,1085,1077,1096,1085,1080,1077,1054,1073,1088,1072,1073,1086,1090,1082,1080)
$nameCreate = U @(1057,1086,1079,1076,1072,1090,1100)
$nameUnsafeProtectionDescription = U @(1054,1087,1080,1089,1072,1085,1080,1077,1047,1072,1097,1080,1090,1099,1054,1090,1054,1087,1072,1089,1085,1099,1093,1044,1077,1081,1089,1090,1074,1080,1081)
$nameWarnAboutUnsafeActions = U @(1055,1088,1077,1076,1091,1087,1088,1077,1078,1076,1072,1090,1100,1054,1073,1054,1087,1072,1089,1085,1099,1093,1044,1077,1081,1089,1090,1074,1080,1103,1093)

function Convert-1CResultToText {
  param([object]$Result)

  if ($null -eq $Result) { return '' }

  try { return [string]$Result } catch { return '<unprintable-result>' }
}

$ctx = $null
$extMgr = $null
$epf = $null
$unsafeProtection = $null
$resultText = ''

try {
  if (-not (Test-Path -LiteralPath $EpfPath)) {
    throw "EPF file not found: $EpfPath"
  }

  $ctx = Connect-1CBase -Alias $Alias -ConfigPath $ConfigPath -EnvPath $EnvPath
  Write-Output ("CONNECT_OK alias=" + $ctx.Alias + " kind=" + $ctx.Kind + " path=" + $ctx.Path)

  $extMgr = $ctx.Connection.GetType().InvokeMember($nameExternalProcessors, $bindingFlags, $null, $ctx.Connection, @())
  if ($null -eq $extMgr) {
    throw 'EXTERNAL_PROCESSORS_MANAGER_NULL'
  }

  $unsafeProtection = $ctx.Connection.NewObject($nameUnsafeProtectionDescription)
  $unsafeProtection.GetType().InvokeMember($nameWarnAboutUnsafeActions, [System.Reflection.BindingFlags]'Public,Instance,SetProperty', $null, $unsafeProtection, @($false)) | Out-Null

  $epf = $extMgr.GetType().InvokeMember($nameCreate, $bindingFlags, $null, $extMgr, @($EpfPath, $false, $unsafeProtection))
  if ($null -eq $epf) {
    throw 'EPF_CREATE_FAILED'
  }

  $invokeArgs = @()
  if (-not [string]::IsNullOrWhiteSpace($MethodArg)) {
    $invokeArgs = @($MethodArg)
  }

  $result = $epf.GetType().InvokeMember($Method, $bindingFlags, $null, $epf, $invokeArgs)
  if ($null -ne $result) {
    $resultText = Convert-1CResultToText -Result $result
  }

  if (-not [string]::IsNullOrWhiteSpace($OutFile)) {
    Save-Utf8Text -Path $OutFile -Text $resultText
    Write-Output ("OUTFILE=" + $OutFile)
  }

  Write-Output ("METHOD_OK=" + $Method)
  if (-not [string]::IsNullOrWhiteSpace($resultText)) {
    Write-Output ('RESULT_BEGIN')
    Write-Output $resultText
    Write-Output ('RESULT_END')
  }
} finally {
  $epf = $null
  $extMgr = $null
  $unsafeProtection = $null
  if ($null -ne $ctx) {
    $ctx.Connection = $null
    $ctx.Connector = $null
  }
  $ctx = $null
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
}
