param(
  [string]$Alias = 'x1_14',
  [string]$OutPath = 'T:\1S\wsl_exchange\work_epf_112_9\logs\sql\pvh_usage_metadata_x1_14.md'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function Add-Line {
  param([System.Collections.Generic.List[string]]$Lines,[string]$Text)
  $Lines.Add($Text) | Out-Null
}

function Add-Blank {
  param([System.Collections.Generic.List[string]]$Lines)
  $Lines.Add('') | Out-Null
}

function To-Text {
  param([object]$Value)
  if ($null -eq $Value) { return '' }
  try { return [string]$Value } catch { return '<unprintable>' }
}

function U($codes) {
  return -join (@($codes) | ForEach-Object { [char][int]$_ })
}

function Type-ContainsTarget {
  param(
    [object]$TypeValue,
    [string[]]$Targets
  )
  $typeText = To-Text $TypeValue
  if ([string]::IsNullOrWhiteSpace($typeText)) { return $false }
  foreach ($target in $Targets) {
    if ($typeText.Contains($target)) { return $true }
  }
  return $false
}

$target1 = U @(1080,1082,1061,1072,1088,1072,1082,1090,1077,1088,1080,1089,1090,1080,1082,1080,1054,1073,1098,1077,1082,1090,1086,1074,1059,1095,1077,1090,1072)
$target2 = U @(1080,1082,1061,1072,1088,1072,1082,1090,1077,1088,1080,1089,1090,1080,1082,1080,1055,1088,1086,1095,1080,1093,1054,1073,1098,1077,1082,1090,1086,1074)
$targets = @($target1, $target2)

$ctx = $null
try {
  $ctx = Connect-1CFileBase -Alias $Alias
  $md = $ctx.Connection.Metadata()
  $lines = New-Object System.Collections.Generic.List[string]

  Add-Line $lines '# PVH usage in metadata'
  Add-Blank $lines
  Add-Line $lines ('- alias: ' + $ctx.Alias)
  Add-Line $lines ('- path: ' + $ctx.Path)
  Add-Blank $lines
  Add-Line $lines '## Targets'
  Add-Line $lines ('- ' + $target1)
  Add-Line $lines ('- ' + $target2)
  Add-Blank $lines

  Add-Line $lines '## Documents'
  foreach ($doc in $md.Documents) {
    $docName = To-Text $doc.Name
    $docHits = New-Object System.Collections.Generic.List[string]
    try {
      foreach ($req in $doc.Requisites) {
        if (Type-ContainsTarget -TypeValue $req.Type -Targets $targets) {
          $docHits.Add('REQ ' + (To-Text $req.Name) + ' :: ' + (To-Text $req.Type)) | Out-Null
        }
      }
    } catch {}
    try {
      foreach ($ts in $doc.TabularSections) {
        foreach ($attr in $ts.Attributes) {
          if (Type-ContainsTarget -TypeValue $attr.Type -Targets $targets) {
            $docHits.Add('TS ' + (To-Text $ts.Name) + '.' + (To-Text $attr.Name) + ' :: ' + (To-Text $attr.Type)) | Out-Null
          }
        }
      }
    } catch {}
    if ($docHits.Count -gt 0) {
      Add-Line $lines ('### ' + $docName)
      foreach ($hit in $docHits) { Add-Line $lines ('- ' + $hit) }
      Add-Blank $lines
    }
  }

  Add-Line $lines '## Information registers'
  foreach ($reg in $md.InformationRegisters) {
    $regName = To-Text $reg.Name
    $regHits = New-Object System.Collections.Generic.List[string]
    try {
      foreach ($item in $reg.Dimensions) {
        if (Type-ContainsTarget -TypeValue $item.Type -Targets $targets) {
          $regHits.Add('DIM ' + (To-Text $item.Name) + ' :: ' + (To-Text $item.Type)) | Out-Null
        }
      }
    } catch {}
    try {
      foreach ($item in $reg.Attributes) {
        if (Type-ContainsTarget -TypeValue $item.Type -Targets $targets) {
          $regHits.Add('ATTR ' + (To-Text $item.Name) + ' :: ' + (To-Text $item.Type)) | Out-Null
        }
      }
    } catch {}
    try {
      foreach ($item in $reg.Resources) {
        if (Type-ContainsTarget -TypeValue $item.Type -Targets $targets) {
          $regHits.Add('RES ' + (To-Text $item.Name) + ' :: ' + (To-Text $item.Type)) | Out-Null
        }
      }
    } catch {}
    if ($regHits.Count -gt 0) {
      Add-Line $lines ('### ' + $regName)
      foreach ($hit in $regHits) { Add-Line $lines ('- ' + $hit) }
      Add-Blank $lines
    }
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
