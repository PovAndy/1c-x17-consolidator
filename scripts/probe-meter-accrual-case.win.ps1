param(
  [string]$Alias = 'x1_14',
  [string]$LsNo = '14-123',
  [string]$BeginDate = '2026-03-01',
  [string]$EndDate = '2026-03-31',
  [string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function New-MarkdownSection {
  param(
    [string]$Title,
    [object]$Table,
    [string[]]$Columns
  )

  $lines = @("## $Title", "")
  if ($null -eq $Table) {
    return ($lines + @('_null_', ''))
  }

  $count = 0
  try { $count = [int]$Table.Count() } catch { $count = 0 }
  if ($count -eq 0) {
    return ($lines + @('_empty_', ''))
  }

  $lines += '| ' + ($Columns -join ' | ') + ' |'
  $lines += '| ' + (($Columns | ForEach-Object { '---' }) -join ' | ') + ' |'
  for ($i = 0; $i -lt $count; $i++) {
    $row = $Table.Get($i)
    $cells = @()
    foreach ($col in $Columns) {
      $value = $row.$col
      $cells += ((Convert-1CValueToString $value) -replace '\r?\n', ' ')
    }
    $lines += '| ' + ($cells -join ' | ') + ' |'
  }
  $lines += ''
  return $lines
}

function Invoke-QueryTable {
  param(
    [object]$Connection,
    [string]$Text,
    [hashtable]$Parameters
  )

  $query = New-1CQuery -Connection $Connection -Text $Text
  foreach ($key in $Parameters.Keys) {
    $query.SetParameter($key, $Parameters[$key])
  }
  return $query.Execute().Unload()
}

function Add-ErrorSection {
  param(
    [string[]]$Lines,
    [string]$Title,
    [System.Exception]$Exception
  )

  $Lines += "## ERROR: $Title"
  $Lines += ''
  $Lines += ('- ' + $Exception.GetType().FullName + ': ' + $Exception.Message)
  $Lines += ''
  return $Lines
}

$ctx = Connect-1CBase -Alias $Alias
$begin = [datetime]::Parse($BeginDate)
$end = [datetime]::Parse($EndDate)

$reportLines = @(
  '# Meter accrual probe',
  '',
  ('- Alias: ' + $Alias),
  ('- LsNo: ' + $LsNo),
  ('- Period: ' + (Get-Date $begin -Format 'yyyy-MM-dd') + ' .. ' + (Get-Date $end -Format 'yyyy-MM-dd')),
  ''
)

$lsTable = $null
try {
  $lsTable = Invoke-QueryTable -Connection $ctx.Connection -Text @'
ВЫБРАТЬ ПЕРВЫЕ 1
    ЛС.Ссылка КАК LSRef,
    ЛС.Номер КАК LSNo,
    ЛС.Наименование КАК LSName,
    ЛС.ОбъектУчета КАК ObjectRef
ИЗ
    Справочник.икЛицевыеСчета КАК ЛС
ГДЕ
    ЛС.Номер = &LsNo
'@ -Parameters @{ LsNo = $LsNo }
} catch {
  $reportLines = Add-ErrorSection -Lines $reportLines -Title 'LS lookup' -Exception $_.Exception
}

$reportLines += New-MarkdownSection -Title 'LS' -Table $lsTable -Columns @('LSNo','LSName','LSRef','ObjectRef')

if ($null -eq $lsTable -or $lsTable.Count() -eq 0) {
  $reportLines += '_LS not found_'
  if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $OutPath = "T:\1S\wsl_exchange\work_epf_112_9\logs\meter_probe_${Alias}_${LsNo}.md"
  }
  Save-Utf8Text -Path $OutPath -Text ($reportLines -join "`r`n")
  Write-Output $OutPath
  exit 0
}

$lsRef = $lsTable.Get(0).LSRef
$objectRef = $lsTable.Get(0).ObjectRef

$objectTable = $null
try {
  $objectTable = Invoke-QueryTable -Connection $ctx.Connection -Text @'
ВЫБРАТЬ ПЕРВЫЕ 1
    Объект.Ссылка КАК ObjectRef,
    Объект.Код КАК ObjectCode,
    Объект.Наименование КАК ObjectName
ИЗ
    Справочник.икОбъектыУчета КАК Объект
ГДЕ
    Объект.Ссылка = &ObjectRef
'@ -Parameters @{ ObjectRef = $objectRef }
} catch {
  $reportLines = Add-ErrorSection -Lines $reportLines -Title 'Object lookup' -Exception $_.Exception
}

$reportLines += New-MarkdownSection -Title 'Object' -Table $objectTable -Columns @('ObjectRef','ObjectCode','ObjectName')

$metersTable = $null
try {
  $metersTable = Invoke-QueryTable -Connection $ctx.Connection -Text @'
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
УПОРЯДОЧИТЬ ПО
    ПУ.Наименование,
    ПУ.Код
'@ -Parameters @{ ObjectRef = $objectRef }
} catch {
  $reportLines = Add-ErrorSection -Lines $reportLines -Title 'Meter list' -Exception $_.Exception
}

$reportLines += New-MarkdownSection -Title 'Meters' -Table $metersTable -Columns @('MeterName','MeterCode','MeterRef','OwnerRef','MeterKindRef','ServiceKindRef','FactoryNo')

$statusTable = $null
try {
  $statusTable = Invoke-QueryTable -Connection $ctx.Connection -Text @'
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
        ВЫБРАТЬ
            ПУ.Ссылка
        ИЗ
            Справочник.икИндивидуальныеПриборыУчета КАК ПУ
        ГДЕ
            ПУ.Владелец = &ObjectRef)
    И Ст.Период <= &EndDate
УПОРЯДОЧИТЬ ПО
    Ст.ПриборУчета,
    Ст.Период
'@ -Parameters @{ ObjectRef = $objectRef; EndDate = $end }
} catch {
  $reportLines = Add-ErrorSection -Lines $reportLines -Title 'Meter statuses' -Exception $_.Exception
}

$reportLines += New-MarkdownSection -Title 'Meter statuses' -Table $statusTable -Columns @('Period','MeterRef','MeterStatus','StatusBegin','StatusEnd')

$readingTable = $null
try {
  $readingTable = Invoke-QueryTable -Connection $ctx.Connection -Text @'
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
        ВЫБРАТЬ
            ПУ.Ссылка
        ИЗ
            Справочник.икИндивидуальныеПриборыУчета КАК ПУ
        ГДЕ
            ПУ.Владелец = &ObjectRef)
    И Показания.Период МЕЖДУ &BeginDate И &EndDate
УПОРЯДОЧИТЬ ПО
    Показания.ПриборУчета,
    Показания.Период
'@ -Parameters @{ ObjectRef = $objectRef; BeginDate = $begin; EndDate = $end }
} catch {
  $reportLines = Add-ErrorSection -Lines $reportLines -Title 'Meter readings' -Exception $_.Exception
}

$reportLines += New-MarkdownSection -Title 'Meter readings' -Table $readingTable -Columns @('Period','MeterRef','TariffZone','MeterValue','InputTs','Registrar')

$meterVolumeTable = $null
try {
  $meterVolumeTable = Invoke-QueryTable -Connection $ctx.Connection -Text @'
ВЫБРАТЬ
    Обороты.Период КАК Period,
    Обороты.ПриборУчета КАК MeterRef,
    Обороты.ТарифнаяЗона КАК TariffZone,
    Обороты.КоличествоОборот КАК QtyTurnover,
    Обороты.Регистратор КАК Registrar
ИЗ
    РегистрНакопления.икОбъемПотребленияПоПриборамУчета.Обороты(&BeginDate, &EndDate, Регистратор, ОбъектУчета = &ObjectRef) КАК Обороты
УПОРЯДОЧИТЬ ПО
    Обороты.ПриборУчета,
    Обороты.Период
'@ -Parameters @{ BeginDate = $begin; EndDate = $end; ObjectRef = $objectRef }
} catch {
  $reportLines = Add-ErrorSection -Lines $reportLines -Title 'Meter volume turnovers' -Exception $_.Exception
}

$reportLines += New-MarkdownSection -Title 'Meter volume turnovers' -Table $meterVolumeTable -Columns @('Period','MeterRef','TariffZone','QtyTurnover','Registrar')

$serviceVolumeTable = $null
try {
  $serviceVolumeTable = Invoke-QueryTable -Connection $ctx.Connection -Text @'
ВЫБРАТЬ
    Обороты.Период КАК Period,
    Обороты.ЛицевойСчет КАК LSRef,
    Обороты.Услуга КАК ServiceRef,
    Обороты.ИсточникОбъема КАК VolumeSource,
    Обороты.КоличествоОборот КАК QtyTurnover,
    Обороты.Регистратор КАК Registrar
ИЗ
    РегистрНакопления.икОбъемПотребленияУслуг.Обороты(&BeginDate, &EndDate, Регистратор, ЛицевойСчет = &LSRef) КАК Обороты
УПОРЯДОЧИТЬ ПО
    Обороты.Период,
    Обороты.Услуга
'@ -Parameters @{ BeginDate = $begin; EndDate = $end; LSRef = $lsRef }
} catch {
  $reportLines = Add-ErrorSection -Lines $reportLines -Title 'Service volume turnovers' -Exception $_.Exception
}

$reportLines += New-MarkdownSection -Title 'Service volume turnovers' -Table $serviceVolumeTable -Columns @('Period','ServiceRef','VolumeSource','QtyTurnover','Registrar')

$accrualTable = $null
try {
  $accrualTable = Invoke-QueryTable -Connection $ctx.Connection -Text @'
ВЫБРАТЬ
    Обороты.Период КАК Period,
    Обороты.ЛицевойСчет КАК LSRef,
    Обороты.Услуга КАК ServiceRef,
    Обороты.КоличествоОборот КАК QtyTurnover,
    Обороты.СуммаОборот КАК SumTurnover,
    Обороты.ТарифОборот КАК TariffTurnover,
    Обороты.Регистратор КАК Registrar
ИЗ
    РегистрНакопления.икНачисленияЗаУслуги.Обороты(&BeginDate, &EndDate, Регистратор, ЛицевойСчет = &LSRef) КАК Обороты
УПОРЯДОЧИТЬ ПО
    Обороты.Период,
    Обороты.Услуга
'@ -Parameters @{ BeginDate = $begin; EndDate = $end; LSRef = $lsRef }
} catch {
  $reportLines = Add-ErrorSection -Lines $reportLines -Title 'Accrual turnovers' -Exception $_.Exception
}

$reportLines += New-MarkdownSection -Title 'Accrual turnovers' -Table $accrualTable -Columns @('Period','ServiceRef','QtyTurnover','SumTurnover','TariffTurnover','Registrar')

if ([string]::IsNullOrWhiteSpace($OutPath)) {
  $safeLs = ($LsNo -replace '[^0-9A-Za-z_-]', '_')
  $OutPath = "T:\1S\wsl_exchange\work_epf_112_9\logs\meter_probe_${Alias}_${safeLs}.md"
}

Save-Utf8Text -Path $OutPath -Text ($reportLines -join "`r`n")
Write-Output $OutPath
