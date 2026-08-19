param(
  [string[]]$Aliases = @('x1_01','x1_10','x1_14','x1_20','x1_21'),
  [datetime]$DateSlice = [datetime]'2026-03-22',
  [string]$OutPathLocal = '',
  [string]$OutPathShare = '{SHARE_ROOT}\epf1129\context\recovery\ls-structure\out\ls_char_etalon.csv',
  [string]$OutReportLocal = '',
  [string]$OutReportShare = '{SHARE_ROOT}\epf1129\context\recovery\ls-structure\out\ls_char_etalon_report.md'
)

$ErrorActionPreference = 'Stop'
. '{PROJECT_ROOT}/scripts/1c-com-common.win.ps1'

function To-Text {
  param([object]$Value)
  if ($null -eq $Value) { return '' }
  try { return [string]$Value } catch { return '' }
}

function Add-Line {
  param([System.Collections.Generic.List[string]]$Lines,[string]$Text)
  $Lines.Add($Text) | Out-Null
}

function Norm-Text {
  param([string]$Text)
  if ($null -eq $Text) { return '' }
  $s = $Text.ToLowerInvariant()
  $s = $s.Replace('ё','е')
  $s = [regex]::Replace($s, '["''`]+', ' ')
  $s = [regex]::Replace($s, '[()\[\]{}]+', ' ')
  $s = [regex]::Replace($s, '[_\-]+', ' ')
  $s = [regex]::Replace($s, '\s+', ' ')
  return $s.Trim()
}

function Csv-Escape {
  param([string]$Value)
  if ($null -eq $Value) { return '' }
  $s = [string]$Value
  if ($s.Contains(';') -or $s.Contains('"') -or $s.Contains("`r") -or $s.Contains("`n")) {
    return '"' + $s.Replace('"','""') + '"'
  }
  return $s
}

$allRows = New-Object System.Collections.Generic.List[string]
$report = New-Object System.Collections.Generic.List[string]
$allRows.Add('source_alias;ls_code;char_name;char_name_normalized;value_repr') | Out-Null
Add-Line $report '# Export LS characteristic structure etalon'
Add-Line $report ''
Add-Line $report ('- date slice: ' + $DateSlice.ToString('yyyy-MM-dd'))
Add-Line $report ('- aliases: ' + ($Aliases -join ', '))
Add-Line $report ''

foreach ($alias in $Aliases) {
  $ctx = Connect-1CBase -Alias $alias
  Add-Line $report ('## ' + $alias)
  Add-Line $report ('- path: ' + $ctx.Path)
  $qLs = New-1CQuery -Connection $ctx.Connection -Text @"
ВЫБРАТЬ
    ЛС.Код КАК ЛицевойСчетКод,
    ЛС.ОбъектУчета КАК ОбъектУчета
ИЗ
    Справочник.икЛицевыеСчета КАК ЛС
ГДЕ
    НЕ ЛС.ПометкаУдаления
УПОРЯДОЧИТЬ ПО
    ЛицевойСчетКод
"@
  $lsTable = $qLs.Execute().Unload()
  Add-Line $report ('- LS rows: ' + $lsTable.Count())
  $dedup = @{}
  $rowsRead = 0
  for ($i = 0; $i -lt $lsTable.Count(); $i++) {
    $lsRow = $lsTable.Get($i)
    $lsCode = To-Text $lsRow.Get(0)
    $objRef = $lsRow.Get(1)
    if ([string]::IsNullOrWhiteSpace($lsCode) -or $null -eq $objRef) { continue }

    $qChars = New-1CQuery -Connection $ctx.Connection -Text @"
ВЫБРАТЬ
    Значения.Характеристика.Наименование КАК Характеристика,
    Значения.Значение КАК Значение
ИЗ
    РегистрСведений.икХарактеристикиОбъектовУчета.СрезПоследних(&ДатаСреза, ОбъектУчета = &ОбъектУчета) КАК Значения
УПОРЯДОЧИТЬ ПО
    Характеристика
"@
    $qChars.SetParameter('ДатаСреза', $DateSlice)
    $qChars.SetParameter('ОбъектУчета', $objRef)
    $charTable = $qChars.Execute().Unload()
    $rowsRead += $charTable.Count()
    for ($j = 0; $j -lt $charTable.Count(); $j++) {
      $row = $charTable.Get($j)
      $charName = To-Text $row.Get(0)
      $valueRepr = To-Text $row.Get(1)
      if ([string]::IsNullOrWhiteSpace($charName)) { continue }
      $norm = Norm-Text -Text $charName
      $key = "$lsCode|$norm"
      if ($dedup.ContainsKey($key)) { continue }
      $dedup[$key] = $true
      $allRows.Add(([string]::Join(';', @(
        (Csv-Escape $alias),
        (Csv-Escape $lsCode),
        (Csv-Escape $charName),
        (Csv-Escape $norm),
        (Csv-Escape $valueRepr)
      )))) | Out-Null
    }
  }
  Add-Line $report ('- characteristic rows read: ' + $rowsRead)
  Add-Line $report ('- unique ls+char rows written: ' + $dedup.Count)
  Add-Line $report ''
}

$csvText = [string]::Join("`r`n", $allRows)
$reportText = [string]::Join("`r`n", $report)
if (-not [string]::IsNullOrWhiteSpace($OutPathLocal)) { Save-Utf8Text -Path $OutPathLocal -Text $csvText }
Save-Utf8Text -Path $OutPathShare -Text $csvText
if (-not [string]::IsNullOrWhiteSpace($OutReportLocal)) { Save-Utf8Text -Path $OutReportLocal -Text $reportText }
Save-Utf8Text -Path $OutReportShare -Text $reportText
Write-Output $reportText
Write-Output ('CSV=' + $OutPathShare)
Write-Output ('REPORT=' + $OutReportShare)
