param(
  [string[]]$Aliases = @('x1_01','x1_10','x1_14','x1_20','x1_21','x2','x3'),
  [string[]]$AddressNeedles = @('Учхоз','Креповский','Петровский','Красный','Белогорский'),
  [datetime]$DateSlice = [datetime]'2026-03-22',
  [string]$OutCsv = 'T:\1S\wsl_exchange\work_epf_112_9\context\recovery\object-account-pvh\out\object_account_chars_by_address.csv',
  [string]$OutReport = 'T:\1S\wsl_exchange\work_epf_112_9\context\recovery\object-account-pvh\out\object_account_chars_by_address.md'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function T([object]$Value) {
  if ($null -eq $Value) { return '' }
  try { return [string]$Value } catch { return '' }
}

function Csv([string]$Value) {
  if ($null -eq $Value) { return '' }
  $s = [string]$Value
  if ($s.Contains(';') -or $s.Contains('"') -or $s.Contains("`r") -or $s.Contains("`n")) {
    return '"' + $s.Replace('"','""') + '"'
  }
  return $s
}

function Match-AnyNeedle([string]$Text, [string[]]$Needles) {
  if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
  foreach ($needle in $Needles) {
    if ([string]::IsNullOrWhiteSpace($needle)) { continue }
    if ($Text.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
      return $true
    }
  }
  return $false
}

$csv = New-Object System.Collections.Generic.List[string]
$csv.Add('source_alias;ls_code;object_repr;char_name;value_repr') | Out-Null
$report = New-Object System.Collections.Generic.List[string]
$report.Add('# Object-account characteristics by address needles') | Out-Null
$report.Add('') | Out-Null
$report.Add('- date slice: ' + $DateSlice.ToString('yyyy-MM-dd')) | Out-Null
$report.Add('- address needles: ' + ($AddressNeedles -join ', ')) | Out-Null
$report.Add('') | Out-Null

foreach ($alias in $Aliases) {
  $ctx = $null
  try {
    $ctx = Connect-1CBase -Alias $alias
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
    $matchedLs = 0
    $written = 0
    for ($i = 0; $i -lt $lsTable.Count(); $i++) {
      $lsRow = $lsTable.Get($i)
      $lsCode = (T $lsRow.Get(0)).Trim()
      $objRef = $lsRow.Get(1)
      if ([string]::IsNullOrWhiteSpace($lsCode) -or $null -eq $objRef) { continue }
      $objRepr = T $objRef
      if (-not (Match-AnyNeedle -Text $objRepr -Needles $AddressNeedles)) { continue }
      $matchedLs++

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
      for ($j = 0; $j -lt $charTable.Count(); $j++) {
        $row = $charTable.Get($j)
        $charName = (T $row.Get(0)).Trim()
        if ([string]::IsNullOrWhiteSpace($charName)) { continue }
        $valueRepr = (T $row.Get(1)).Trim()
        $csv.Add(([string]::Join(';', @(
          (Csv $alias),
          (Csv $lsCode),
          (Csv $objRepr),
          (Csv $charName),
          (Csv $valueRepr)
        )))) | Out-Null
        $written++
      }
    }
    $report.Add('## ' + $alias) | Out-Null
    $report.Add('- matched LS: ' + $matchedLs) | Out-Null
    $report.Add('- rows written: ' + $written) | Out-Null
    $report.Add('') | Out-Null
  } finally {
    if ($ctx) { $ctx.Connection = $null; $ctx.Connector = $null }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
  }
}

Save-Utf8Text -Path $OutCsv -Text ([string]::Join("`r`n", $csv))
Save-Utf8Text -Path $OutReport -Text ([string]::Join("`r`n", $report))
Write-Output ('CSV=' + $OutCsv)
Write-Output ('REPORT=' + $OutReport)
