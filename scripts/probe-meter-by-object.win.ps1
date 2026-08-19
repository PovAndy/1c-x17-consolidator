param(
  [string]$Alias = 'x1_14',
  [string]$ObjectCode = '00-000324',
  [string]$BeginDate = '2026-03-01',
  [string]$EndDate = '2026-03-31',
  [string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function New-MarkdownSection {
  param([string]$Title,[object]$Table,[string[]]$Columns)
  $lines = @("## $Title", "")
  if ($null -eq $Table) { return ($lines + @('_null_', '')) }
  $count = 0
  try { $count = [int]$Table.Count() } catch { $count = 0 }
  if ($count -eq 0) { return ($lines + @('_empty_', '')) }
  $lines += '| ' + ($Columns -join ' | ') + ' |'
  $lines += '| ' + (($Columns | ForEach-Object { '---' }) -join ' | ') + ' |'
  for ($i = 0; $i -lt $count; $i++) {
    $row = $Table.Get($i)
    $cells = @()
    foreach ($col in $Columns) {
      $cells += ((Convert-1CValueToString $row.$col) -replace '\r?\n', ' ')
    }
    $lines += '| ' + ($cells -join ' | ') + ' |'
  }
  $lines += ''
  return $lines
}

function Invoke-QueryTable {
  param([object]$Connection,[string]$Text,[hashtable]$Parameters)
  $query = New-1CQuery -Connection $Connection -Text $Text
  foreach ($k in $Parameters.Keys) {
    $query.SetParameter($k, $Parameters[$k])
  }
  return $query.Execute().Unload()
}

$ctx = Connect-1CBase -Alias $Alias
$begin = [datetime]::Parse($BeginDate)
$end = [datetime]::Parse($EndDate)
$reportLines = @(
  '# Meter object probe',
  '',
  ('- Alias: ' + $Alias),
  ('- ObjectCode: ' + $ObjectCode),
  ('- Period: ' + (Get-Date $begin -Format 'yyyy-MM-dd') + ' .. ' + (Get-Date $end -Format 'yyyy-MM-dd')),
  ''
)

$objectTable = Invoke-QueryTable -Connection $ctx.Connection -Text @'
ВЫБРАТЬ ПЕРВЫЕ 1
    Объект.Ссылка КАК ObjectRef,
    Объект.Код КАК ObjectCode,
    Объект.Наименование КАК ObjectName
ИЗ
    Справочник.икОбъектыУчета КАК Объект
ГДЕ
    Объект.Код = &ObjectCode
'@ -Parameters @{ ObjectCode = $ObjectCode }
$reportLines += New-MarkdownSection -Title 'Object' -Table $objectTable -Columns @('ObjectRef','ObjectCode','ObjectName')

if ($objectTable.Count() -eq 0) {
  if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $OutPath = "T:\1S\wsl_exchange\work_epf_112_9\logs\meter_object_probe_${Alias}_${ObjectCode}.md"
  }
  Save-Utf8Text -Path $OutPath -Text ($reportLines -join "`r`n")
  Write-Output $OutPath
  exit 0
}

$objectRef = $objectTable.Get(0).ObjectRef

$meters = Invoke-QueryTable -Connection $ctx.Connection -Text @'
ВЫБРАТЬ
    ПУ.Ссылка КАК MeterRef,
    ПУ.Наименование КАК MeterName,
    ПУ.Код КАК MeterCode,
    ПУ.Владелец КАК OwnerRef,
    ПУ.ВидПрибораУчета КАК MeterKindRef,
    ПУ.ВидПрибораУчета.ВидУслуги КАК ServiceKindRef,
    ПУ.ЗаводскойНомер КАК FactoryNo
ИЗ
    Справочник.икИндивидуальныеПриборыУчета КАК ПУ
ГДЕ
    ПУ.Владелец = &ObjectRef
УПОРЯДОЧИТЬ ПО ПУ.Наименование, ПУ.Код
'@ -Parameters @{ ObjectRef = $objectRef }
$reportLines += New-MarkdownSection -Title 'Meters' -Table $meters -Columns @('MeterName','MeterCode','MeterRef','OwnerRef','MeterKindRef','ServiceKindRef','FactoryNo')

$statuses = Invoke-QueryTable -Connection $ctx.Connection -Text @'
ВЫБРАТЬ
    Ст.Период КАК Period,
    Ст.ПриборУчета КАК MeterRef,
    Ст.СтатусПрибораУчета КАК MeterStatus,
    Ст.ДатаНачала КАК StatusBegin,
    Ст.ДатаОкончания КАК StatusEnd
ИЗ
    РегистрСведений.икСтатусыПриборовУчета КАК Ст
ГДЕ
    Ст.ПриборУчета В (
        ВЫБРАТЬ ПУ.Ссылка
        ИЗ Справочник.икИндивидуальныеПриборыУчета КАК ПУ
        ГДЕ ПУ.Владелец = &ObjectRef)
    И Ст.Период <= &EndDate
УПОРЯДОЧИТЬ ПО Ст.ПриборУчета, Ст.Период
'@ -Parameters @{ ObjectRef = $objectRef; EndDate = $end }
$reportLines += New-MarkdownSection -Title 'Meter statuses' -Table $statuses -Columns @('Period','MeterRef','MeterStatus','StatusBegin','StatusEnd')

$readings = Invoke-QueryTable -Connection $ctx.Connection -Text @'
ВЫБРАТЬ
    Показания.Период КАК Period,
    Показания.ПриборУчета КАК MeterRef,
    Показания.ТарифнаяЗона КАК TariffZone,
    Показания.Показание КАК MeterValue,
    Показания.ДатаВремяВвода КАК InputTs,
    Показания.Регистратор КАК Registrar
ИЗ
    РегистрСведений.икПоказанияПриборовУчета КАК Показания
ГДЕ
    Показания.ПриборУчета В (
        ВЫБРАТЬ ПУ.Ссылка
        ИЗ Справочник.икИндивидуальныеПриборыУчета КАК ПУ
        ГДЕ ПУ.Владелец = &ObjectRef)
    И Показания.Период МЕЖДУ &BeginDate И &EndDate
УПОРЯДОЧИТЬ ПО Показания.ПриборУчета, Показания.Период
'@ -Parameters @{ ObjectRef = $objectRef; BeginDate = $begin; EndDate = $end }
$reportLines += New-MarkdownSection -Title 'Meter readings' -Table $readings -Columns @('Period','MeterRef','TariffZone','MeterValue','InputTs','Registrar')

$meterVolume = Invoke-QueryTable -Connection $ctx.Connection -Text @'
ВЫБРАТЬ
    Обороты.Период КАК Period,
    Обороты.ПриборУчета КАК MeterRef,
    Обороты.ТарифнаяЗона КАК TariffZone,
    Обороты.КоличествоОборот КАК QtyTurnover,
    Обороты.Регистратор КАК Registrar
ИЗ
    РегистрНакопления.икОбъемПотребленияПоПриборамУчета.Обороты(&BeginDate, &EndDate, Регистратор, ОбъектУчета = &ObjectRef) КАК Обороты
УПОРЯДОЧИТЬ ПО Обороты.ПриборУчета, Обороты.Период
'@ -Parameters @{ BeginDate = $begin; EndDate = $end; ObjectRef = $objectRef }
$reportLines += New-MarkdownSection -Title 'Meter volume turnovers' -Table $meterVolume -Columns @('Period','MeterRef','TariffZone','QtyTurnover','Registrar')

if ([string]::IsNullOrWhiteSpace($OutPath)) {
  $OutPath = "T:\1S\wsl_exchange\work_epf_112_9\logs\meter_object_probe_${Alias}_${ObjectCode}.md"
}
Save-Utf8Text -Path $OutPath -Text ($reportLines -join "`r`n")
Write-Output $OutPath
