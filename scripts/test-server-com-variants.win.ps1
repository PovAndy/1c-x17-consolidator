$ErrorActionPreference = 'Stop'

$envPath = '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\.env'
$map = @{}
Get-Content -LiteralPath $envPath -Encoding UTF8 | ForEach-Object {
  if ([string]::IsNullOrWhiteSpace($_)) { return }
  if ($_.TrimStart().StartsWith('#')) { return }
  $parts = $_ -split '=', 2
  if ($parts.Count -eq 2) { $map[$parts[0].Trim()] = $parts[1].Trim() }
}

$user = $map['EPF_DB_USER']
$pwd = $map['EPF_DB_PWD']

$variants = @(
  @{ label = '{V8_SERVER}';        cs = "Srvr=`"{V8_SERVER}`";Ref=`"MergedBase`";Usr=`"$user`";Pwd=`"$pwd`";" },
  @{ label = '{V8_SERVER}_1541';   cs = "Srvr=`"{V8_SERVER}:{V8_PORT}`";Ref=`"MergedBase`";Usr=`"$user`";Pwd=`"$pwd`";" },
  @{ label = 'ip';            cs = "Srvr=`"192.168.195.46`";Ref=`"MergedBase`";Usr=`"$user`";Pwd=`"$pwd`";" },
  @{ label = 'ip_1541';       cs = "Srvr=`"192.168.195.46:1541`";Ref=`"MergedBase`";Usr=`"$user`";Pwd=`"$pwd`";" }
)

foreach ($variant in $variants) {
  Write-Output ("TRY " + $variant.label + " " + $variant.cs)
  $job = Start-Job -ScriptBlock {
    param($connectionString)
    $ErrorActionPreference = 'Stop'
    $c = New-Object -ComObject V83.COMConnector
    $null = $c.Connect($connectionString)
    'CONNECT_OK'
  } -ArgumentList $variant.cs

  if (Wait-Job $job -Timeout 20) {
    try {
      Receive-Job $job
    } catch {
      Write-Output 'CONNECT_FAIL'
      Write-Output $_.Exception.Message
    }
  } else {
    Write-Output 'TIMEOUT'
    Stop-Job $job | Out-Null
  }

  Remove-Job $job -Force | Out-Null
}
