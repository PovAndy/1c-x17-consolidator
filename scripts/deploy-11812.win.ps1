$ErrorActionPreference = 'Stop'
$buildDir = 'T:\1S\wsl_exchange\work_epf_112_9\build'
$serverDir = '{SHARE_ROOT}\epf1129'
$compiled = Join-Path $buildDir 'compiled.epf'
$versioned = Get-ChildItem -LiteralPath $buildDir -File -Filter '*.epf' |
  Where-Object { $_.Name -ne 'compiled.epf' } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
if (-not (Test-Path -LiteralPath $compiled)) { throw "compiled.epf not found: $compiled" }
if ($null -eq $versioned) { throw "No versioned epf in $buildDir" }
Copy-Item -Force $compiled (Join-Path $serverDir 'compiled.epf')
Copy-Item -Force $versioned.FullName (Join-Path $serverDir 'epf_118_12.epf')
Get-Item (Join-Path $serverDir 'compiled.epf'), (Join-Path $serverDir 'epf_118_12.epf') | Select-Object FullName,Length,LastWriteTime | Format-List
