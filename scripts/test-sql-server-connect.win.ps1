$ErrorActionPreference = 'Stop'
$envPath = '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\.env'
$map = @{}
Get-Content -LiteralPath $envPath | ForEach-Object {
  if ([string]::IsNullOrWhiteSpace($_)) { return }
  if ($_.TrimStart().StartsWith('#')) { return }
  $parts = $_ -split '=', 2
  if ($parts.Count -eq 2) { $map[$parts[0].Trim()] = $parts[1].Trim() }
}
$user = $map['EPF_DB_USER']
$pwd = $map['EPF_DB_PWD']
$cs = "Srvr=`"{V8_SERVER}`";Ref=`"MergedBase`";Usr=`"$user`";Pwd=`"$pwd`";"
try {
  $c = New-Object -ComObject V83.COMConnector
  $cn = $c.Connect($cs)
  Write-Output ('CONNECT_OK cs=' + $cs)
} catch {
  Write-Output 'CONNECT_FAIL'
  Write-Output $_.Exception.Message
  exit 1
}
