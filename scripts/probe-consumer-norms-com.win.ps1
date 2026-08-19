param(
  [string]$Alias = 'x1_21',
  [string[]]$LsNos = @('21-010', '21-099'),
  [string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function To-Text {
  param([object]$Value)
  if ($null -eq $Value) { return '<null>' }
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

function Names-FromMetadataCollection {
  param([object]$Collection)
  $result = New-Object System.Collections.Generic.List[string]
  if ($null -eq $Collection) { return $result }
  try {
    foreach ($item in $Collection) {
      try {
        $name = [string]$item.Name
        if (-not [string]::IsNullOrWhiteSpace($name)) { $result.Add($name) | Out-Null }
      } catch {}
    }
  } catch {}
  return $result
}

function Find-FieldName {
  param(
    [string[]]$Names,
    [string[]]$PrimaryPatterns,
    [string[]]$ExcludePatterns = @()
  )

  foreach ($name in $Names) {
    $norm = ($name.ToLowerInvariant() -replace '[^a-zа-я0-9]+','')
    $ok = $true
    foreach ($pat in $PrimaryPatterns) {
      if ($norm -notlike "*$($pat.ToLowerInvariant())*") {
        $ok = $false
        break
      }
    }
    if (-not $ok) { continue }

    $excluded = $false
    foreach ($pat in $ExcludePatterns) {
      if ($norm -like "*$($pat.ToLowerInvariant())*") {
        $excluded = $true
        break
      }
    }
    if (-not $excluded) { return $name }
  }
  return ''
}

function Row-ValueSafe {
  param([object]$Row,[int]$Index)
  try { return $Row.Get($Index) } catch { return $null }
}

$ctx = Connect-1CBase -Alias $Alias
$lines = New-Object System.Collections.Generic.List[string]
Add-Line $lines '# Probe consumer norms'
Add-Blank $lines
Add-Line $lines ('- alias: ' + $ctx.Alias)
Add-Line $lines ('- path: ' + $ctx.Path)
Add-Line $lines ('- role: ' + $ctx.Role)
Add-Line $lines ('- user: ' + $ctx.User)
Add-Blank $lines

$meta = $ctx.Connection.Metadata()
$reg = $meta.InformationRegisters.Find('икУслугиЛицевыхСчетов')
if ($null -eq $reg) {
  throw 'Metadata register икУслугиЛицевыхСчетов not found'
}

$names = New-Object System.Collections.Generic.List[string]
Names-FromMetadataCollection $reg.Dimensions | ForEach-Object { if (-not $names.Contains($_)) { $names.Add($_) | Out-Null } }
Names-FromMetadataCollection $reg.Attributes | ForEach-Object { if (-not $names.Contains($_)) { $names.Add($_) | Out-Null } }
Names-FromMetadataCollection $reg.Resources | ForEach-Object { if (-not $names.Contains($_)) { $names.Add($_) | Out-Null } }

$fieldLs = Find-FieldName -Names $names.ToArray() -PrimaryPatterns @('лицев')
if ([string]::IsNullOrWhiteSpace($fieldLs)) {
  $fieldLs = Find-FieldName -Names $names.ToArray() -PrimaryPatterns @('лс')
}
$fieldService = Find-FieldName -Names $names.ToArray() -PrimaryPatterns @('услуг')
$fieldDirectNorm = Find-FieldName -Names $names.ToArray() -PrimaryPatterns @('норматив','одну','единиц') -ExcludePatterns @('потреб')
if ([string]::IsNullOrWhiteSpace($fieldDirectNorm)) {
  $fieldDirectNorm = Find-FieldName -Names $names.ToArray() -PrimaryPatterns @('норма','одну','единиц') -ExcludePatterns @('потреб')
}
$fieldNormative = Find-FieldName -Names $names.ToArray() -PrimaryPatterns @('норматив')
$fieldConsumers = Find-FieldName -Names $names.ToArray() -PrimaryPatterns @('потребител')
$fieldBasis = Find-FieldName -Names $names.ToArray() -PrimaryPatterns @('основан','расчет')
if ([string]::IsNullOrWhiteSpace($fieldBasis)) {
  $fieldBasis = Find-FieldName -Names $names.ToArray() -PrimaryPatterns @('показатель','расчет')
}

Add-Line $lines '## Register fields'
Add-Line $lines ('- ЛС: ' + $(if ($fieldLs) { $fieldLs } else { '<not found>' }))
Add-Line $lines ('- Услуга: ' + $(if ($fieldService) { $fieldService } else { '<not found>' }))
Add-Line $lines ('- Прямая норма: ' + $(if ($fieldDirectNorm) { $fieldDirectNorm } else { '<not found>' }))
Add-Line $lines ('- Норматив: ' + $(if ($fieldNormative) { $fieldNormative } else { '<not found>' }))
Add-Line $lines ('- Потребители: ' + $(if ($fieldConsumers) { $fieldConsumers } else { '<not found>' }))
Add-Line $lines ('- Основание: ' + $(if ($fieldBasis) { $fieldBasis } else { '<not found>' }))
Add-Blank $lines
Add-Line $lines '## All register names'
foreach ($name in $names) { Add-Line $lines ('- ' + $name) }

foreach ($lsNo in $LsNos) {
  Add-Blank $lines
  Add-Line $lines ('## LS ' + $lsNo)

  if ([string]::IsNullOrWhiteSpace($fieldLs) -or [string]::IsNullOrWhiteSpace($fieldService)) {
    Add-Line $lines '- skipped: LS/service fields not discovered'
    continue
  }

  $selectParts = New-Object System.Collections.Generic.List[string]
  $selectParts.Add("Т.$fieldLs.Код КАК ЛицевойСчетКод") | Out-Null
  $selectParts.Add("Т.$fieldLs.Наименование КАК ЛицевойСчетНаименование") | Out-Null
  $selectParts.Add("Т.$fieldService.Код КАК УслугаКод") | Out-Null
  $selectParts.Add("Т.$fieldService.Наименование КАК УслугаНаименование") | Out-Null
  if (-not [string]::IsNullOrWhiteSpace($fieldDirectNorm)) { $selectParts.Add("Т.$fieldDirectNorm КАК НормаПрямая") | Out-Null }
  if (-not [string]::IsNullOrWhiteSpace($fieldNormative)) { $selectParts.Add("Т.$fieldNormative КАК Норматив") | Out-Null }
  if (-not [string]::IsNullOrWhiteSpace($fieldConsumers)) { $selectParts.Add("Т.$fieldConsumers КАК Потребители") | Out-Null }
  if (-not [string]::IsNullOrWhiteSpace($fieldBasis)) { $selectParts.Add("Т.$fieldBasis КАК Основание") | Out-Null }

  $queryText = @"
ВЫБРАТЬ
    $(($selectParts -join ",`r`n    "))
ИЗ
    РегистрСведений.икУслугиЛицевыхСчетов КАК Т
ГДЕ
    Т.$fieldLs.Код = &LsNo
"@
  try {
    $q = New-1CQuery -Connection $ctx.Connection -Text $queryText
    $q.SetParameter('LsNo', $lsNo)
    $table = $q.Execute().Unload()
    $count = $table.Count()
    Add-Line $lines ('- register rows: ' + $count)
    for ($i = 0; $i -lt $count; $i++) {
      $row = $table.Get($i)
      Add-Line $lines ('- service row #' + ($i+1))
      Add-Line $lines ('  - service: ' + (To-Text (Row-ValueSafe $row 3)))
      Add-Line $lines ('  - direct norm: ' + (To-Text (Row-ValueSafe $row 4)))
      Add-Line $lines ('  - normative: ' + (To-Text (Row-ValueSafe $row 5)))
      Add-Line $lines ('  - consumers: ' + (To-Text (Row-ValueSafe $row 6)))
      Add-Line $lines ('  - basis: ' + (To-Text (Row-ValueSafe $row 7)))
    }
  } catch {
    Add-Line $lines ('- register query error: ' + $_.Exception.Message)
  }

  $lsQuery = @"
ВЫБРАТЬ ПЕРВЫЕ 1
    ЛС.Ссылка КАК ЛицевойСчет,
    ЛС.Код КАК Код,
    ЛС.Наименование КАК Наименование,
    ЛС.ОбъектУчета КАК ОбъектУчета,
    ЛС.ОбъектУчета.Наименование КАК ОбъектУчетаНаименование
ИЗ
    Справочник.икЛицевыеСчета КАК ЛС
ГДЕ
    ЛС.Код = &LsNo
"@
  try {
    $qLs = New-1CQuery -Connection $ctx.Connection -Text $lsQuery
    $qLs.SetParameter('LsNo', $lsNo)
    $lsTable = $qLs.Execute().Unload()
    if ($lsTable.Count() -gt 0) {
      $rowLs = $lsTable.Get(0)
      $objRef = $rowLs.Get(3)
      Add-Line $lines ('- object: ' + (To-Text (Row-ValueSafe $rowLs 4)))
      if ($null -ne $objRef) {
        $charQuery = @"
ВЫБРАТЬ
    Значения.Характеристика.Наименование КАК Характеристика,
    Значения.Значение КАК Значение
ИЗ
    РегистрСведений.икХарактеристикиОбъектовУчета.СрезПоследних(&ДатаСреза, ОбъектУчета = &ОбъектУчета) КАК Значения
ГДЕ
    Значения.Характеристика.Наименование ПОДОБНО &Mask1
    ИЛИ Значения.Характеристика.Наименование ПОДОБНО &Mask2
    ИЛИ Значения.Характеристика.Наименование ПОДОБНО &Mask3
    ИЛИ Значения.Характеристика.Наименование ПОДОБНО &Mask4
УПОРЯДОЧИТЬ ПО
    Характеристика
"@
        $qChars = New-1CQuery -Connection $ctx.Connection -Text $charQuery
        $qChars.SetParameter('ДатаСреза', [datetime]'2026-03-17')
        $qChars.SetParameter('ОбъектУчета', $objRef)
        $qChars.SetParameter('Mask1', '%проживающ%')
        $qChars.SetParameter('Mask2', '%полив%')
        $qChars.SetParameter('Mask3', '%площад%')
        $qChars.SetParameter('Mask4', '%участ%')
        $charTable = $qChars.Execute().Unload()
        Add-Line $lines ('- object characteristics rows: ' + $charTable.Count())
        for ($j = 0; $j -lt $charTable.Count(); $j++) {
          $r = $charTable.Get($j)
          Add-Line $lines ('  - ' + (To-Text $r.Get(0)) + ' = ' + (To-Text $r.Get(1)))
        }
      }
    } else {
      Add-Line $lines '- LS not found in catalog'
    }
  } catch {
    Add-Line $lines ('- LS/object query error: ' + $_.Exception.Message)
  }
}

$text = [string]::Join("`r`n", $lines)
if (-not [string]::IsNullOrWhiteSpace($OutPath)) {
  Save-Utf8Text -Path $OutPath -Text $text
}
Write-Output $text
