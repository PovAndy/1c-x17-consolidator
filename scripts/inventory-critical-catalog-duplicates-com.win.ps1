param(
  [string]$Alias = 'x17_pg2',
  [string]$OutPath = '',
  [string[]]$Catalogs = @()
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function U {
  param([object[]]$codes)
  $chars = New-Object System.Collections.Generic.List[string]
  foreach ($item in $codes) {
    if ($item -is [System.Array]) {
      foreach ($nested in $item) {
        $chars.Add([string][char][int]$nested) | Out-Null
      }
    } else {
      $chars.Add([string][char][int]$item) | Out-Null
    }
  }
  return -join $chars
}

function To-Text {
  param([object]$Value)
  if ($null -eq $Value) { return '' }
  try { return ([string]$Value).Trim() } catch { return '<unprintable>' }
}

function Get-ComPropSafe {
  param(
    [object]$Object,
    [string]$Name,
    [object]$Default = $null
  )

  if ($null -eq $Object) { return $Default }
  try {
    return $Object.GetType().InvokeMember($Name, [System.Reflection.BindingFlags]::GetProperty, $null, $Object, @())
  } catch {
    return $Default
  }
}

function Invoke-ComSafe {
  param(
    [object]$Object,
    [string]$Name,
    [object[]]$Args = @(),
    [object]$Default = $null
  )

  if ($null -eq $Object) { return $Default }
  try {
    return $Object.GetType().InvokeMember($Name, [System.Reflection.BindingFlags]::InvokeMethod, $null, $Object, $Args)
  } catch {
    return $Default
  }
}

function Normalize-Key {
  param([string]$Value)
  if ($null -eq $Value) { return '' }
  return $Value.Trim().ToLowerInvariant()
}

function Add-GroupItem {
  param(
    [hashtable]$Map,
    [string]$Key,
    [pscustomobject]$Item
  )

  if ([string]::IsNullOrWhiteSpace($Key)) { return }
  if (-not $Map.ContainsKey($Key)) {
    $Map[$Key] = New-Object System.Collections.Generic.List[object]
  }
  $Map[$Key].Add($Item) | Out-Null
}

function Summarize-DuplicateMap {
  param(
    [hashtable]$Map,
    [int]$ExampleLimit = 10
  )

  $groupCount = 0
  $elementCount = 0
  $examples = New-Object System.Collections.Generic.List[string]
  foreach ($entry in $Map.GetEnumerator() | Sort-Object Key) {
    $items = $entry.Value
    if ($items.Count -le 1) { continue }
    $groupCount++
    $elementCount += $items.Count
    if ($examples.Count -lt $ExampleLimit) {
      $preview = ($items | Select-Object -First 4 | ForEach-Object {
        ('{0} [code={1}] [ref={2}]' -f $_.Name, $_.Code, $_.Ref)
      }) -join ' | '
      $examples.Add("- $($entry.Key): $preview") | Out-Null
    }
  }
  return [pscustomobject]@{
    GroupCount = $groupCount
    ElementCount = $elementCount
    Examples = $examples
  }
}

function Build-CatalogQueryText {
  param([string]$CatalogName)

  $kwSelect = U -codes @(1042,1067,1041,1056,1040,1058,1068) # ВЫБРАТЬ
  $kwFrom = U -codes @(1048,1047) # ИЗ
  $kwAs = U -codes @(1050,1040,1050) # КАК
  $fieldRef = U -codes @(1057,1089,1099,1083,1082,1072) # Ссылка
  $fieldCode = U -codes @(1050,1086,1076) # Код
  $fieldName = U -codes @(1053,1072,1080,1084,1077,1085,1086,1074,1072,1085,1080,1077) # Наименование
  $fieldDel = U -codes @(1055,1086,1084,1077,1090,1082,1072,1059,1076,1072,1083,1077,1085,1080,1103) # ПометкаУдаления
  $catalogPrefix = U -codes @(1057,1087,1088,1072,1074,1086,1095,1085,1080,1082,46) # Справочник.
  $alias = U -codes @(1058) # Т

  return @"
$kwSelect
    $alias.$fieldRef $kwAs $fieldRef,
    $alias.$fieldCode $kwAs $fieldCode,
    $alias.$fieldName $kwAs $fieldName,
    $alias.$fieldDel $kwAs $fieldDel
$kwFrom
    $catalogPrefix$CatalogName $kwAs $alias
"@
}

if ($Catalogs.Count -eq 0) {
  $Catalogs = @(
    (U -codes @(1080,1082,1042,1080,1076,1099,1054,1073,1098,1077,1082,1090,1086,1074,1059,1095,1077,1090,1072)), # икВидыОбъектовУчета
    (U -codes @(1080,1082,1042,1080,1076,1099,1055,1088,1080,1073,1086,1088,1086,1074,1059,1095,1077,1090,1072)), # икВидыПриборовУчета
    (U -codes @(1080,1082,1048,1085,1076,1080,1074,1080,1076,1091,1072,1083,1100,1085,1099,1077,1055,1088,1080,1073,1086,1088,1099,1059,1095,1077,1090,1072)), # икИндивидуальныеПриборыУчета
    (U -codes @(1080,1082,1054,1073,1098,1077,1082,1090,1099,1059,1095,1077,1090,1072)), # икОбъектыУчета
    (U -codes @(1080,1082,1051,1080,1094,1077,1074,1099,1077,1057,1095,1077,1090,1072)), # икЛицевыеСчета
    (U -codes @(1080,1082,1059,1089,1083,1091,1075,1080)), # икУслуги
    (U -codes @(1054,1088,1075,1072,1085,1080,1079,1072,1094,1080,1080)) # Организации
  )
}

$ctx = $null
try {
  $ctx = Connect-1CBase -Alias $Alias
  if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $OutPath = "T:\1S\wsl_exchange\work_epf_112_9\logs\duplicates\critical_catalog_duplicates_${Alias}_${stamp}.md"
  }

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('# Critical catalog duplicate inventory') | Out-Null
  $lines.Add('') | Out-Null
  $lines.Add('- Base: `' + $ctx.Alias + '`') | Out-Null
  $lines.Add('- Path: `' + $ctx.Path + '`') | Out-Null
  $lines.Add('- Timestamp: `' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '`') | Out-Null
  $lines.Add('- Mode: `read-only`') | Out-Null
  $lines.Add('') | Out-Null

  $totalCodeGroups = 0
  $totalCodeElements = 0
  $totalNameGroups = 0
  $totalNameElements = 0
  $catalogsWithFindings = 0

  foreach ($catalogName in $Catalogs) {
    $lines.Add('## ' + $catalogName) | Out-Null
    $activeRows = New-Object System.Collections.Generic.List[object]
    $deletedRows = 0
    try {
      $query = New-1CQuery -Connection $ctx.Connection -Text (Build-CatalogQueryText -CatalogName $catalogName)
      $table = $query.Execute().Unload()
      $count = [int]$table.Count()
      for ($i = 0; $i -lt $count; $i++) {
        $row = $table.Get($i)
        $ref = To-Text ($row.Get(0))
        $code = To-Text ($row.Get(1))
        $name = To-Text ($row.Get(2))
        $deletionMark = [bool]($row.Get(3))
        if ($deletionMark) {
          $deletedRows++
          continue
        }
        $activeRows.Add([pscustomobject]@{
          Ref = $ref
          Code = $code
          Name = $name
        }) | Out-Null
      }
    } catch {
      $lines.Add('- query failed: ' + $_.Exception.Message) | Out-Null
      $lines.Add('') | Out-Null
      continue
    }

    $codeMap = @{}
    $nameMap = @{}
    foreach ($row in $activeRows) {
      Add-GroupItem -Map $codeMap -Key (Normalize-Key $row.Code) -Item $row
      Add-GroupItem -Map $nameMap -Key (Normalize-Key $row.Name) -Item $row
    }

    $codeSummary = Summarize-DuplicateMap -Map $codeMap
    $nameSummary = Summarize-DuplicateMap -Map $nameMap
    if ($codeSummary.GroupCount -gt 0 -or $nameSummary.GroupCount -gt 0) {
      $catalogsWithFindings++
    }

    $totalCodeGroups += $codeSummary.GroupCount
    $totalCodeElements += $codeSummary.ElementCount
    $totalNameGroups += $nameSummary.GroupCount
    $totalNameElements += $nameSummary.ElementCount

    $lines.Add('- active elements: ' + $activeRows.Count) | Out-Null
    $lines.Add('- deletion-marked elements: ' + $deletedRows) | Out-Null
    $lines.Add('- duplicate code groups: ' + $codeSummary.GroupCount) | Out-Null
    $lines.Add('- elements inside duplicate code groups: ' + $codeSummary.ElementCount) | Out-Null
    $lines.Add('- duplicate name groups: ' + $nameSummary.GroupCount) | Out-Null
    $lines.Add('- elements inside duplicate name groups: ' + $nameSummary.ElementCount) | Out-Null

    if ($codeSummary.Examples.Count -gt 0) {
      $lines.Add('### Duplicate code examples') | Out-Null
      foreach ($line in $codeSummary.Examples) {
        $lines.Add($line) | Out-Null
      }
    }

    if ($nameSummary.Examples.Count -gt 0) {
      $lines.Add('### Duplicate name examples') | Out-Null
      foreach ($line in $nameSummary.Examples) {
        $lines.Add($line) | Out-Null
      }
    }

    $lines.Add('') | Out-Null
  }

  $lines.Add('## Summary') | Out-Null
  $lines.Add('- catalogs with findings: ' + $catalogsWithFindings) | Out-Null
  $lines.Add('- total duplicate code groups: ' + $totalCodeGroups) | Out-Null
  $lines.Add('- total elements inside duplicate code groups: ' + $totalCodeElements) | Out-Null
  $lines.Add('- total duplicate name groups: ' + $totalNameGroups) | Out-Null
  $lines.Add('- total elements inside duplicate name groups: ' + $totalNameElements) | Out-Null
  $lines.Add('') | Out-Null
  $lines.Add('## Next step') | Out-Null
  $lines.Add('1. For duplicate code groups, evaluate whether elements participate in choices, registers, documents, and reports.') | Out-Null
  $lines.Add('2. Split findings into risk classes A/B/C before any corrective pass.') | Out-Null
  $lines.Add('3. Do not merge/delete only because code matches; verify business impact first.') | Out-Null

  Save-Utf8Text -Path $OutPath -Text ([string]::Join("`r`n", $lines))
  Write-Host $OutPath
} finally {
  if ($null -ne $ctx) {
    $ctx.Connection = $null
    $ctx.Connector = $null
  }
  $ctx = $null
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
}
