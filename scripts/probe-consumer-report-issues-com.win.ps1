param(
  [string]$Alias = 'x1_01',
  [string[]]$LsNos = @('01-43'),
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

function Save-Lines {
  param([System.Collections.Generic.List[string]]$Lines,[string]$Path)
  $text = [string]::Join("`r`n", $Lines)
  if (-not [string]::IsNullOrWhiteSpace($Path)) {
    Save-Utf8Text -Path $Path -Text $text
  }
  return $text
}

$ctx = Connect-1CBase -Alias $Alias
$lines = New-Object System.Collections.Generic.List[string]
Add-Line $lines '# Probe consumer report issues'
Add-Blank $lines
Add-Line $lines ('- alias: ' + $ctx.Alias)
Add-Line $lines ('- path: ' + $ctx.Path)
Add-Line $lines ('- role: ' + $ctx.Role)
Add-Line $lines ('- user: ' + $ctx.User)

foreach ($lsNo in $LsNos) {
  Add-Blank $lines
  Add-Line $lines ('## LS ' + $lsNo)

  $qLs = New-1CQuery -Connection $ctx.Connection -Text @"
ВЫБРАТЬ ПЕРВЫЕ 1
    ЛС.Ссылка КАК ЛицевойСчет,
    ЛС.Код КАК Код,
    ЛС.Наименование КАК Наименование,
    ЛС.ОбъектУчета КАК ОбъектУчета
ИЗ
    Справочник.икЛицевыеСчета КАК ЛС
ГДЕ
    ЛС.Код = &LsNo
"@
  $qLs.SetParameter('LsNo', $lsNo)
  $lsTable = $qLs.Execute().Unload()
  if ($lsTable.Count() -eq 0) {
    Add-Line $lines '- LS not found'
    continue
  }

  $lsRow = $lsTable.Get(0)
  $lsRef = $lsRow.Get(0)
  $objRef = $lsRow.Get(3)
  Add-Line $lines ('- name: ' + (To-Text $lsRow.Get(2)))
  Add-Line $lines ('- object: ' + (To-Text $objRef))

  $qCharges = New-1CQuery -Connection $ctx.Connection -Text @"
ВЫБРАТЬ
    НАЧАЛОПЕРИОДА(Начисления.ДатаПериода, МЕСЯЦ) КАК Период,
    Начисления.Услуга КАК Услуга,
    МАКСИМУМ(Начисления.Тариф) КАК Тариф,
    СУММА(Начисления.Количество) КАК Количество,
    СУММА(Начисления.Сумма) КАК Сумма
ИЗ
    РегистрНакопления.икНачисленияЗаУслуги КАК Начисления
ГДЕ
    Начисления.Активность
    И Начисления.ЛицевойСчет = &LsRef
    И Начисления.ДатаПериода >= &DateFrom
    И Начисления.ДатаПериода < &DateTo
СГРУППИРОВАТЬ ПО
    НАЧАЛОПЕРИОДА(Начисления.ДатаПериода, МЕСЯЦ),
    Начисления.Услуга
УПОРЯДОЧИТЬ ПО
    Период,
    Услуга
"@
  $qCharges.SetParameter('LsRef', $lsRef)
  $qCharges.SetParameter('DateFrom', [datetime]'2025-01-01')
  $qCharges.SetParameter('DateTo',  [datetime]'2026-01-01')
  $charges = $qCharges.Execute().Unload()
  Add-Line $lines ('- accrual rows: ' + $charges.Count())
  for ($i = 0; $i -lt $charges.Count(); $i++) {
    $r = $charges.Get($i)
    Add-Line $lines ('  - ' + (To-Text $r.Get(0)) + ' | ' + (To-Text $r.Get(1)) + ' | tariff=' + (To-Text $r.Get(2)) + ' | qty=' + (To-Text $r.Get(3)) + ' | sum=' + (To-Text $r.Get(4)))
  }

  $qPays = New-1CQuery -Connection $ctx.Connection -Text @"
ВЫБРАТЬ
    НАЧАЛОПЕРИОДА(Оплаты.Ссылка.Дата, МЕСЯЦ) КАК Период,
    СУММА(Оплаты.СуммаОплаты) КАК Сумма
ИЗ
    Документ.икГрупповойВводОплатыУслуг.ЛицевыеСчета КАК Оплаты
ГДЕ
    НЕ Оплаты.Ссылка.ПометкаУдаления
    И Оплаты.Ссылка.Проведен
    И Оплаты.ЛицевойСчет = &LsRef
    И Оплаты.Ссылка.Дата >= &DateFrom
    И Оплаты.Ссылка.Дата < &DateTo
СГРУППИРОВАТЬ ПО
    НАЧАЛОПЕРИОДА(Оплаты.Ссылка.Дата, МЕСЯЦ)
УПОРЯДОЧИТЬ ПО
    Период
"@
  $qPays.SetParameter('LsRef', $lsRef)
  $qPays.SetParameter('DateFrom', [datetime]'2025-01-01')
  $qPays.SetParameter('DateTo',  [datetime]'2026-01-01')
  $pays = $qPays.Execute().Unload()
  Add-Line $lines ('- payment rows: ' + $pays.Count())
  for ($i = 0; $i -lt $pays.Count(); $i++) {
    $r = $pays.Get($i)
    Add-Line $lines ('  - ' + (To-Text $r.Get(0)) + ' | sum=' + (To-Text $r.Get(1)))
  }

  for ($month = 1; $month -le 12; $month++) {
    $period = Get-Date -Date ("2025-{0:d2}-01" -f $month)
    $qSvc = New-1CQuery -Connection $ctx.Connection -Text @"
ВЫБРАТЬ
    Т.Услуга КАК Услуга,
    Т.СтатусПодключения КАК СтатусПодключения
ИЗ
    РегистрСведений.икУслугиЛицевыхСчетов.СрезПоследних(&SliceDate,
        ЛицевойСчет = &LsRef) КАК Т
УПОРЯДОЧИТЬ ПО
    Услуга
"@
    $qSvc.SetParameter('SliceDate', [datetime]($period.AddMonths(1).AddDays(-1)))
    $qSvc.SetParameter('LsRef', $lsRef)
    $svc = $qSvc.Execute().Unload()
    Add-Line $lines ('- services at ' + $period.ToString('yyyy-MM-dd') + ': ' + $svc.Count())
    for ($j = 0; $j -lt $svc.Count(); $j++) {
      $r = $svc.Get($j)
      Add-Line $lines ('  - ' + (To-Text $r.Get(0)) + ' | status=' + (To-Text $r.Get(1)))
    }
  }
}

$text = Save-Lines -Lines $lines -Path $OutPath
Write-Output $text
