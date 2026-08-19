$ErrorActionPreference = 'Stop'
$src = 'T:\1S\wsl_exchange\work_epf_112_9\config-dumps\x1_14'
$dst = '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\context\config-dumps\x1_14_local'
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -LiteralPath (Join-Path $src '*') -Destination $dst -Recurse -Force
Write-Output "COPIED=$dst"
