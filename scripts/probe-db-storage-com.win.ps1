param(
  [string]$Alias = 'x1_14',
  [string]$OutPath = 'T:\1S\wsl_exchange\work_epf_112_9\logs\sql\db_storage_probe.md'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function U($codes) {
  $flat = New-Object System.Collections.Generic.List[object]
  foreach ($item in $codes) {
    if ($item -is [System.Array]) {
      foreach ($nested in $item) {
        $flat.Add($nested) | Out-Null
      }
    } else {
      $flat.Add($item) | Out-Null
    }
  }
  return -join ($flat | ForEach-Object { [char][int]$_ })
}

function To-Text {
  param([object]$Value)
  if ($null -eq $Value) { return '' }
  try { return [string]$Value } catch { return '<unprintable>' }
}

function Add-Line {
  param([System.Collections.Generic.List[string]]$Lines,[string]$Text)
  $Lines.Add($Text) | Out-Null
}

function Add-Blank {
  param([System.Collections.Generic.List[string]]$Lines)
  $Lines.Add('') | Out-Null
}

function Find-MetadataObject {
  param(
    [object]$Collection,
    [string]$Name
  )

  if ($null -eq $Collection) { return $null }

  try {
    $found = $Collection.Find($Name)
    if ($null -ne $found) { return $found }
  } catch {}

  try {
    foreach ($item in $Collection) {
      try {
        if ([string]$item.Name -eq $Name) {
          return $item
        }
      } catch {}
    }
  } catch {}

  return $null
}

function Invoke-DbStorageInfo {
  param([object]$Connection)
  $flags = [System.Reflection.BindingFlags]'Public,Instance,InvokeMethod'
  try {
    return $Connection.GetType().InvokeMember('GetDBStorageStructureInfo', $flags, $null, $Connection, @($null, $true))
  } catch {
    throw "GetDBStorageStructureInfo invoke failed: $($_.Exception.Message)"
  }
}

$ctx = $null
try {
  $ctx = Connect-1CFileBase -Alias $Alias
  $targetNames = @(
    (U (@(1080,1082,1061,1072,1088,1072,1082,1090,1077,1088,1080,1089,1090,1080,1082,1080,1054,1073,1098,1077,1082,1090,1086,1074,1059,1095,1077,1090,1072))),
    (U (@(1080,1082,1061,1072,1088,1072,1082,1090,1077,1088,1080,1089,1090,1080,1082,1080,1055,1088,1086,1095,1080,1093,1054,1073,1098,1077,1082,1090,1086,1074)))
  )
  $table = Invoke-DbStorageInfo -Connection $ctx.Connection

  $lines = New-Object System.Collections.Generic.List[string]
  Add-Line $lines '# DB storage probe'
  Add-Blank $lines
  Add-Line $lines ('- alias: ' + $ctx.Alias)
  Add-Line $lines ('- path: ' + $ctx.Path)
  Add-Line $lines ('- role: ' + $ctx.Role)
  Add-Line $lines ('- user: ' + $ctx.User)
  Add-Line $lines ('- rows: ' + $(try { [string]$table.Count() } catch { '<unknown>' }))
  Add-Blank $lines

  Add-Line $lines '## Requested metadata names'
  foreach ($item in $targetNames) {
    Add-Line $lines ('- ' + $item)
  }
  Add-Blank $lines

  $columnNames = New-Object System.Collections.Generic.List[string]
  try {
    foreach ($col in $table.Columns) {
      try { $columnNames.Add([string]$col.Name) | Out-Null } catch {}
    }
  } catch {}

  Add-Line $lines '## Columns'
  foreach ($name in $columnNames) {
    Add-Line $lines ('- ' + $name)
  }
  Add-Blank $lines

  Add-Line $lines '## Rows'
  try {
    foreach ($row in $table) {
      $metadata = ''
      $purpose = ''
      $storageTableName = ''
      $tableName = ''
      try { $metadata = To-Text $row.Metadata } catch {}
      $isTarget = $false
      foreach ($targetName in $targetNames) {
        if (-not [string]::IsNullOrWhiteSpace($metadata) -and $metadata.Contains($targetName)) {
          $isTarget = $true
          break
        }
      }
      if (-not $isTarget) { continue }
      try { $purpose = To-Text $row.Purpose } catch {}
      try { $storageTableName = To-Text $row.StorageTableName } catch {}
      try { $tableName = To-Text $row.TableName } catch {}
      Add-Line $lines ('- metadata=' + $metadata + '; purpose=' + $purpose + '; storage=' + $storageTableName + '; table=' + $tableName)
    }
  } catch {
    Add-Line $lines ('- rows iteration error: ' + $_.Exception.Message)
  }

  Save-Utf8Text -Path $OutPath -Text ([string]::Join("`r`n", $lines))
  Write-Output ('OUT=' + $OutPath)
} finally {
  if ($null -ne $ctx) {
    $ctx.Connection = $null
    $ctx.Connector = $null
  }
  $ctx = $null
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
}
