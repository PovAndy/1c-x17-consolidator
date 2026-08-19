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
$css = @(
  "Srvr=`"{V8_SERVER}`";Ref=`"MergedBase`";Usr=`"$user`";Pwd=`"$pwd`";",
  "Srvr=`"{V8_SERVER}:{V8_PORT}`";Ref=`"MergedBase`";Usr=`"$user`";Pwd=`"$pwd`";"
)
foreach ($cs in $css) {
  Write-Output ('TRY ' + $cs)
  $job = Start-Job -ScriptBlock {
    param($connectionString)
    $ErrorActionPreference = 'Stop'
    $c = New-Object -ComObject V83.COMConnector
    $cn = $c.Connect($connectionString)
    'CONNECT_OK'
  } -ArgumentList $cs
  if (Wait-Job $job -Timeout 20) {
    Receive-Job $job
  } else {
    Write-Output 'TIMEOUT'
    Stop-Job $job | Out-Null
  }
  Remove-Job $job -Force | Out-Null
}
