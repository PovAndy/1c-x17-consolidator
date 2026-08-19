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
function U([int[]]$codes) { return -join ($codes | ForEach-Object { [char]$_ }) }
$envMap = Get-EnvMap '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\.env'
$user = $envMap['EPF_DB_USER']
$pwd = $envMap['EPF_DB_PWD']
$fileDb = 'T:\Base1s\Formula_GKHBuh21'
$cc = New-Object -ComObject V83.COMConnector
$conn = $cc.Connect("File=`"$fileDb`";Usr=`"$user`";Pwd=`"$pwd`";")
Write-Output 'CONNECT_OK'
try {
  $q = $conn.NewObject('Query')
  $q.Text = (U @(1042,1067,1041,1056,1040,1058,1068,32,49,32,1050,1040,1050,32,1061))
  $res = $q.Execute().Unload()
  Write-Output ('QUERY_OK=' + $res.Count())
} catch {
  Write-Output ('QUERY_FAIL: ' + $_.Exception.Message)
  exit 1
}
