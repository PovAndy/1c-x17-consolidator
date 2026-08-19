$ErrorActionPreference = 'Stop'

function Get-EnvMap($Path) {
  $map = @{}
  Get-Content -LiteralPath $Path | ForEach-Object {
    if ([string]::IsNullOrWhiteSpace($_)) { return }
    if ($_.TrimStart().StartsWith('#')) { return }
    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) { $map[$parts[0].Trim()] = $parts[1].Trim() }
  }
  return $map
}

function U([int[]]$codes) {
  return -join ($codes | ForEach-Object { [char]$_ })
}

$BF = [System.Reflection.BindingFlags]'Public,Instance,GetProperty,InvokeMethod'
$envMap = Get-EnvMap '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\.env'
$user = $envMap['EPF_DB_USER']
$pwd = $envMap['EPF_DB_PWD']
$fileDb = 'T:\Base1s\Formula_GKHBuh21'
$epf = 'T:\\1S\\wsl_exchange\\work_epf_112_9\\build\\compiled.epf'

$cc = New-Object -ComObject V83.COMConnector
$conn = $cc.Connect("File=`"$fileDb`";Usr=`"$user`";Pwd=`"$pwd`";")
Write-Output 'CONNECT_OK'

$nameExternalProcessors = U @(1042,1085,1077,1096,1085,1080,1077,1054,1073,1088,1072,1073,1086,1090,1082,1080)
$nameCreate = U @(1057,1086,1079,1076,1072,1090,1100)
$nameVersion = U @(1040,1076,1072,1087,1090,95,1042,1077,1088,1089,1080,1103,1054,1073,1088,1072,1073,1086,1090,1082,1080)

$extMgr = $conn.GetType().InvokeMember($nameExternalProcessors, $BF, $null, $conn, @())
if ($null -eq $extMgr) { throw 'EXTERNAL_PROCESSORS_MANAGER_NULL' }
Write-Output 'EXT_MGR_OK'

$ext = $extMgr.GetType().InvokeMember($nameCreate, $BF, $null, $extMgr, @($epf, $false))
if ($null -eq $ext) { throw 'EPF_CREATE_FAILED' }
Write-Output 'EPF_OK'

$ver = $ext.GetType().InvokeMember($nameVersion, $BF, $null, $ext, @())
Write-Output ('EPF_VERSION=' + $ver)
