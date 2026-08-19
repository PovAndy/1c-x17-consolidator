param(
  [Parameter(Mandatory=$true)]
  [string[]]$Aliases,
  [datetime]$DateSlice = [datetime]'2026-03-25',
  [string]$OutRootShare = '{SHARE_ROOT}\epf1129\context\recovery\other-pvh\inbox',
  [string[]]$CharNamePatterns = @(
    'марка прибора',
    'поверк',
    'номер пломб',
    'антимагнит',
    'место установки',
    'вид прибора',
    'межповероч',
    'гис жкх',
    'гцжс'
  )
)

$ErrorActionPreference = 'Stop'
. '{PROJECT_ROOT}/scripts/1c-com-common.win.ps1'

function To-Text {
  param([object]$Value)
  if ($null -eq $Value) { return '' }
  try { return [string]$Value } catch { return '' }
}

function Csv-Escape {
  param([string]$Value)
  if ($null -eq $Value) { return '' }
  $s = [string]$Value
  if ($s.Contains(',') -or $s.Contains('"') -or $s.Contains("`r") -or $s.Contains("`n")) {
    return '"' + $s.Replace('"','""') + '"'
  }
  return $s
}

function Add-Line {
  param([System.Collections.Generic.List[string]]$Lines,[string]$Text)
  $Lines.Add($Text) | Out-Null
}

function Norm-Text {
  param([string]$Text)
  if ($null -eq $Text) { return '' }
  $s = $Text.ToLowerInvariant().Replace('ё','е')
  $s = [regex]::Replace($s, '\s+', ' ')
  return $s.Trim()
}

function Match-Pattern {
  param([string]$Text,[string[]]$Patterns)
  $n = Norm-Text -Text $Text
  foreach ($p in $Patterns) {
    if ($n.Contains((Norm-Text -Text $p))) { return $true }
  }
  return $false
}

$report = New-Object System.Collections.Generic.List[string]
Add-Line $report '# Export other PVH recovery sources'
Add-Line $report ''
Add-Line $report ('- date slice: ' + $DateSlice.ToString('yyyy-MM-dd'))
Add-Line $report ('- aliases: ' + ($Aliases -join ', '))
Add-Line $report ('- output root: ' + $OutRootShare)
Add-Line $report ''

foreach ($alias in $Aliases) {
  $ctx = Connect-1CBase -Alias $alias
  $baseDir = Join-Path $OutRootShare $alias
  New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

  $pvhLines = New-Object System.Collections.Generic.List[string]
  $regLines = New-Object System.Collections.Generic.List[string]
  Add-Line $pvhLines 'base_alias,ref,code,description,value_type,parent_ref,view_type_ref,deletion_mark'
  Add-Line $regLines 'base_alias,period,object_ref,object_name,char_ref,char_description,value_type,value_presentation'

  Add-Line $report ('## ' + $alias)
  Add-Line $report ('- path: ' + $ctx.Path)

  $qPvh = New-1CQuery -Connection $ctx.Connection -Text @"
ВЫБРАТЬ
    Характеристики.Ссылка КАК Ссылка,
    Характеристики.Код КАК Код,
    Характеристики.Наименование КАК Наименование,
    Характеристики.ТипЗначения КАК ТипЗначения,
    Характеристики.Родитель КАК Родитель,
    Характеристики.ВидОбъектаУчета КАК ВидОбъектаУчета,
    Характеристики.ПометкаУдаления КАК ПометкаУдаления
ИЗ
    ПланВидовХарактеристик.икХарактеристикиПрочихОбъектов КАК Характеристики
УПОРЯДОЧИТЬ ПО
    Наименование
"@
  $pvhTable = $qPvh.Execute().Unload()
  $pvhCount = 0
  for ($i = 0; $i -lt $pvhTable.Count(); $i++) {
    $row = $pvhTable.Get($i)
    $name = To-Text $row.Get(2)
    if (-not (Match-Pattern -Text $name -Patterns $CharNamePatterns)) { continue }
    $line = [string]::Join(',', @(
      (Csv-Escape $alias),
      (Csv-Escape (To-Text $row.Get(0))),
      (Csv-Escape (To-Text $row.Get(1))),
      (Csv-Escape $name),
      (Csv-Escape (To-Text $row.Get(3))),
      (Csv-Escape (To-Text $row.Get(4))),
      (Csv-Escape (To-Text $row.Get(5))),
      (Csv-Escape (To-Text $row.Get(6)).ToLowerInvariant())
    ))
    Add-Line $pvhLines $line
    $pvhCount++
  }

  $qReg = New-1CQuery -Connection $ctx.Connection -Text @"
ВЫБРАТЬ
    Значения.Период КАК Период,
    Значения.Объект КАК Объект,
    Значения.Характеристика КАК Характеристика,
    Значения.Значение КАК Значение,
    Значения.Характеристика.Наименование КАК ХарактеристикаНаименование,
    Значения.Характеристика.ТипЗначения КАК ТипЗначения
ИЗ
    РегистрСведений.икХарактеристикиПрочихОбъектов КАК Значения
ГДЕ
    Значения.Период <= &ДатаСреза
УПОРЯДОЧИТЬ ПО
    Период,
    ХарактеристикаНаименование
"@
  $qReg.SetParameter('ДатаСреза', $DateSlice)
  $regTable = $qReg.Execute().Unload()
  $regCount = 0
  for ($i = 0; $i -lt $regTable.Count(); $i++) {
    $row = $regTable.Get($i)
    $charName = To-Text $row.Get(4)
    if (-not (Match-Pattern -Text $charName -Patterns $CharNamePatterns)) { continue }
    $line = [string]::Join(',', @(
      (Csv-Escape $alias),
      (Csv-Escape (To-Text $row.Get(0))),
      (Csv-Escape (To-Text $row.Get(1))),
      (Csv-Escape (To-Text $row.Get(1))),
      (Csv-Escape (To-Text $row.Get(2))),
      (Csv-Escape $charName),
      (Csv-Escape (To-Text $row.Get(5))),
      (Csv-Escape (To-Text $row.Get(3)))
    ))
    Add-Line $regLines $line
    $regCount++
  }

  Save-Utf8Text -Path (Join-Path $baseDir 'pvh_other.csv') -Text ([string]::Join("`r`n", $pvhLines))
  Save-Utf8Text -Path (Join-Path $baseDir 'reg_other_chars.csv') -Text ([string]::Join("`r`n", $regLines))

  Add-Line $report ('- pvh rows written: ' + $pvhCount)
  Add-Line $report ('- register rows written: ' + $regCount)
  Add-Line $report ''
}

$reportPath = Join-Path $OutRootShare 'export_other_pvh_recovery_report.md'
Save-Utf8Text -Path $reportPath -Text ([string]::Join("`r`n", $report))
Write-Output ([string]::Join("`r`n", $report))
Write-Output ('REPORT=' + $reportPath)
