param(
  [string]$Alias = 'x1_14'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function To-Text {
  param([object]$Value)
  if ($null -eq $Value) { return '<null>' }
  try { return [string]$Value } catch { return '<unprintable>' }
}

function U {
  param([object[]]$codes)
  return -join (@() | ForEach-Object { [char][int]param(
  [string]$Alias = 'x1_14'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function To-Text {
  param([object]$Value)
  if ($null -eq $Value) { return '<null>' }
  try { return [string]$Value } catch { return '<unprintable>' }
}

function U {
  param([object[]]$codes)
  return -join (@($codes) | ForEach-Object { [char][int]$_ })
}

$Catalogs = @(
  U @(1080,1082,1051,1080,1094,1077,1074,1099,1077,1057,1095,1077,1090,1072),
  U @(1080,1082,1054,1073,1098,1077,1082,1090,1099,1059,1095,1077,1090,1072)
)

$ctx = Connect-1CFileBase -Alias $Alias
try {
  $md = $ctx.Connection.Metadata()
  foreach ($catalogName in $Catalogs) {
    Write-Output ('## ' + $catalogName)
    $catalog = $md.Catalogs.Find($catalogName)
    if ($null -eq $catalog) {
      Write-Output '- not found'
      continue
    }
    foreach ($req in $catalog.Requisites) {
      try {
        Write-Output ('- ' + (To-Text $req.Name) + ' :: ' + (To-Text $req.Type))
      } catch {}
    }
    Write-Output ''
  }
} finally {
  if ($ctx) {
    $ctx.Connection = $null
    $ctx.Connector = $null
  }
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
}
 })
}

$Catalogs = @(
  U @(1080,1082,1051,1080,1094,1077,1074,1099,1077,1057,1095,1077,1090,1072),
  U @(1080,1082,1054,1073,1098,1077,1082,1090,1099,1059,1095,1077,1090,1072)
)

$ctx = Connect-1CFileBase -Alias $Alias
try {
  $md = $ctx.Connection.Metadata()
  foreach ($catalogName in $Catalogs) {
    Write-Output ('## ' + $catalogName)
    $catalog = $md.Catalogs.Find($catalogName)
    if ($null -eq $catalog) {
      Write-Output '- not found'
      continue
    }
    foreach ($req in $catalog.Requisites) {
      try {
        Write-Output ('- ' + (To-Text $req.Name) + ' :: ' + (To-Text $req.Type))
      } catch {}
    }
    Write-Output ''
  }
} finally {
  if ($ctx) {
    $ctx.Connection = $null
    $ctx.Connector = $null
  }
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
}
