param(
  [string[]]$Aliases = @('x1_01','x1_10','x1_14','x1_20','x1_21','x2','x3'),
  [string]$OutDir = 'T:\1S\wsl_exchange\work_epf_112_9\temp\122.54-runtime\donor-com'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function Invoke-Com([object]$Object, [string]$Name, [object[]]$Arguments = @()) {
  $Object.GetType().InvokeMember(
    $Name,
    [System.Reflection.BindingFlags]::InvokeMethod,
    $null,
    $Object,
    $Arguments
  )
}

function Get-ComProp([object]$Object, [string]$Name) {
  $Object.GetType().InvokeMember(
    $Name,
    [System.Reflection.BindingFlags]::GetProperty,
    $null,
    $Object,
    @()
  )
}

function Optional-Prop([object]$Object, [string]$Name) {
  if ($null -eq $Object) { return $null }
  try { return Get-ComProp $Object $Name } catch { return $null }
}

function Text([object]$Value) {
  if ($null -eq $Value) { return '' }
  try { return [string]$Value } catch { return '' }
}

function Ref-Id([object]$Connection, [object]$Value) {
  if ($null -eq $Value) { return '' }
  try { return [string](Invoke-Com $Connection 'XMLString' @($Value)) } catch { return '' }
}

function Ref-Name([object]$Connection, [object]$Reference) {
  if ($null -eq $Reference) { return '' }
  try {
    $object = Invoke-Com $Reference 'GetObject' @()
    foreach ($property in @('Description', 'Code')) {
      $value = Optional-Prop $object $property
      $text = Text $value
      if (-not [string]::IsNullOrWhiteSpace($text)) { return $text }
    }
  } catch {
  }
  try {
    $text = [string](Invoke-Com $Connection 'String' @($Reference))
    if (-not [string]::IsNullOrWhiteSpace($text)) { return $text }
  } catch {
  }
  $fallback = Text $Reference
  if ($fallback -eq 'System.__ComObject') { return '' }
  return $fallback
}

function Csv([string]$Value) {
  if ($null -eq $Value) { return '' }
  if ($Value.Contains(';') -or $Value.Contains('"') -or $Value.Contains("`r") -or $Value.Contains("`n")) {
    return '"' + $Value.Replace('"','""') + '"'
  }
  return $Value
}

function Add-ReferenceColumns(
  [System.Collections.Generic.List[string]]$Values,
  [object]$Connection,
  [object]$Reference
) {
  $Values.Add((Csv (Ref-Id $Connection $Reference))) | Out-Null
  $Values.Add((Csv (Ref-Name $Connection $Reference))) | Out-Null
}

if (-not (Test-Path -LiteralPath $OutDir)) {
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}

$objectRows = New-Object System.Collections.Generic.List[string]
$objectRows.Add('source_alias;ref_uuid;code;name;parent_uuid;parent_name;view_uuid;view_name;calc_view_uuid;calc_view_name;calc_char_uuid;calc_char_name;citizen_group_uuid;citizen_group_name;unit_uuid;unit_name;deletion_mark') | Out-Null

$otherTypeRows = New-Object System.Collections.Generic.List[string]
$otherTypeRows.Add('source_alias;char_ref_uuid;char_code;char_name;view_uuid;view_name;deletion_mark') | Out-Null

$paymentRows = New-Object System.Collections.Generic.List[string]
$paymentRows.Add('source_alias;ref_uuid;code;name;parent_uuid;parent_name;payment_kind_uuid;payment_kind_name;contract_uuid;contract_name;counterparty_uuid;counterparty_name;receipt_settings_uuid;receipt_settings_name;organization_uuid;organization_name;recipient_uuid;recipient_name;service_list_uuid;service_list_name;distribution_uuid;distribution_name;cash_flow_item_uuid;cash_flow_item_name;advance_account_uuid;advance_account_name;settlement_account_uuid;settlement_account_name;counterparty_account_uuid;counterparty_account_name;device_uuid;device_name;deletion_mark') | Out-Null

$basisRows = New-Object System.Collections.Generic.List[string]
$basisRows.Add('source_alias;ref_uuid;code;name;characteristic_uuid;characteristic_name;deletion_mark') | Out-Null

$report = New-Object System.Collections.Generic.List[string]
$report.Add('# Read-only donor export for [22.12]') | Out-Null
$report.Add('') | Out-Null
$report.Add('- aliases: ' + ($Aliases -join ', ')) | Out-Null
$report.Add('- mode: query only, no writes') | Out-Null
$report.Add('') | Out-Null

$objectQuery = @"
ВЫБРАТЬ
    Х.Ссылка,
    Х.Код,
    Х.Наименование,
    Х.ПометкаУдаления
ИЗ
    ПланВидовХарактеристик.икХарактеристикиОбъектовУчета КАК Х
УПОРЯДОЧИТЬ ПО
    Х.Наименование,
    Х.Код
"@

$otherTypeQuery = @"
ВЫБРАТЬ
    Х.Ссылка,
    Х.Код,
    Х.Наименование,
    Х.ПометкаУдаления
ИЗ
    ПланВидовХарактеристик.икХарактеристикиПрочихОбъектов КАК Х
УПОРЯДОЧИТЬ ПО
    Х.Наименование,
    Х.Код
"@

$paymentQuery = @"
ВЫБРАТЬ
    В.Ссылка,
    В.Код,
    В.Наименование,
    В.ПометкаУдаления
ИЗ
    Справочник.икВариантыОплатыУслуг КАК В
УПОРЯДОЧИТЬ ПО
    В.Наименование,
    В.Код
"@

$basisQuery = @"
ВЫБРАТЬ
    О.Ссылка,
    О.Код,
    О.Наименование,
    О.ПометкаУдаления
ИЗ
    Справочник.икОснованияРасчетаУслуг КАК О
УПОРЯДОЧИТЬ ПО
    О.Наименование,
    О.Код
"@

foreach ($alias in $Aliases) {
  $ctx = $null
  try {
    $ctx = Connect-1CBase -Alias $alias

    $table = (New-1CQuery -Connection $ctx.Connection -Text $objectQuery).Execute().Unload()
    $objectCount = $table.Count()
    for ($i = 0; $i -lt $objectCount; $i++) {
      $row = $table.Get($i)
      $ref = $row.Get(0)
      $object = $null
      try { $object = Invoke-Com $ref 'GetObject' @() } catch {}
      $values = New-Object System.Collections.Generic.List[string]
      $values.Add((Csv $alias)) | Out-Null
      $values.Add((Csv (Ref-Id $ctx.Connection $ref))) | Out-Null
      $values.Add((Csv (Text $row.Get(1)))) | Out-Null
      $values.Add((Csv (Text $row.Get(2)))) | Out-Null
      Add-ReferenceColumns $values $ctx.Connection (Optional-Prop $object 'Parent')
      Add-ReferenceColumns $values $ctx.Connection (Optional-Prop $object 'ВидОбъектаУчета')
      Add-ReferenceColumns $values $ctx.Connection (Optional-Prop $object 'ВидОбъектаУчетаДляВычисления')
      Add-ReferenceColumns $values $ctx.Connection (Optional-Prop $object 'ХарактеристикаОбъектаУчетаДляВычисления')
      Add-ReferenceColumns $values $ctx.Connection (Optional-Prop $object 'ГруппаГраждан')
      Add-ReferenceColumns $values $ctx.Connection (Optional-Prop $object 'ЕдиницаИзмерения')
      $values.Add((Csv (Text $row.Get(3)))) | Out-Null
      $objectRows.Add([string]::Join(';', $values)) | Out-Null
    }

    $table = (New-1CQuery -Connection $ctx.Connection -Text $otherTypeQuery).Execute().Unload()
    $otherTypeCount = $table.Count()
    for ($i = 0; $i -lt $otherTypeCount; $i++) {
      $row = $table.Get($i)
      $ref = $row.Get(0)
      $object = $null
      try { $object = Invoke-Com $ref 'GetObject' @() } catch {}
      $view = Optional-Prop $object 'ВидОбъекта'
      $otherTypeRows.Add([string]::Join(';', @(
        (Csv $alias),
        (Csv (Ref-Id $ctx.Connection $ref)),
        (Csv (Text $row.Get(1))),
        (Csv (Text $row.Get(2))),
        (Csv (Ref-Id $ctx.Connection $view)),
        (Csv (Ref-Name $ctx.Connection $view)),
        (Csv (Text $row.Get(3)))
      ))) | Out-Null
    }

    $paymentCount = 0
    try {
      $table = (New-1CQuery -Connection $ctx.Connection -Text $paymentQuery).Execute().Unload()
      $paymentCount = $table.Count()
      for ($i = 0; $i -lt $paymentCount; $i++) {
        $row = $table.Get($i)
        $ref = $row.Get(0)
        $object = $null
        try { $object = Invoke-Com $ref 'GetObject' @() } catch {}
        $values = New-Object System.Collections.Generic.List[string]
        $values.Add((Csv $alias)) | Out-Null
        $values.Add((Csv (Ref-Id $ctx.Connection $ref))) | Out-Null
        $values.Add((Csv (Text $row.Get(1)))) | Out-Null
        $values.Add((Csv (Text $row.Get(2)))) | Out-Null
        foreach ($field in @(
          'Parent',
          'ВидОплаты',
          'Договор',
          'Контрагент',
          'НастройкиПечатиЧека',
          'Организация',
          'ПолучательПлатежа',
          'СписокУслуг',
          'СпособРаспределения',
          'СтатьяДвиженияДенежныхСредств',
          'СчетАвансов',
          'СчетРасчетов',
          'СчетУчетаРасчетовСКонтрагентом',
          'УстройствоПечатиЧекаПоУмолчанию'
        )) {
          Add-ReferenceColumns $values $ctx.Connection (Optional-Prop $object $field)
        }
        $values.Add((Csv (Text $row.Get(3)))) | Out-Null
        $paymentRows.Add([string]::Join(';', $values)) | Out-Null
      }
    } catch {
      $report.Add("- payment variants: SKIP ($($_.Exception.GetType().Name))") | Out-Null
    }

    $basisCount = 0
    try {
      $table = (New-1CQuery -Connection $ctx.Connection -Text $basisQuery).Execute().Unload()
      $basisCount = $table.Count()
      for ($i = 0; $i -lt $basisCount; $i++) {
        $row = $table.Get($i)
        $ref = $row.Get(0)
        $object = $null
        try { $object = Invoke-Com $ref 'GetObject' @() } catch {}
        $characteristic = Optional-Prop $object 'ХарактеристикаОбъектаУчета'
        $basisRows.Add([string]::Join(';', @(
          (Csv $alias),
          (Csv (Ref-Id $ctx.Connection $ref)),
          (Csv (Text $row.Get(1))),
          (Csv (Text $row.Get(2))),
          (Csv (Ref-Id $ctx.Connection $characteristic)),
          (Csv (Ref-Name $ctx.Connection $characteristic)),
          (Csv (Text $row.Get(3)))
        ))) | Out-Null
      }
    } catch {
      $report.Add("- service bases: SKIP ($($_.Exception.GetType().Name))") | Out-Null
    }

    $report.Add("## $alias") | Out-Null
    $report.Add("- object PVH: $objectCount") | Out-Null
    $report.Add("- other-object characteristics: $otherTypeCount") | Out-Null
    if ($paymentCount -gt 0) {
      $report.Add("- payment variants: $paymentCount") | Out-Null
    }
    if ($basisCount -gt 0) {
      $report.Add("- service bases: $basisCount") | Out-Null
    }
    $report.Add('') | Out-Null
  } finally {
    if ($ctx) {
      $ctx.Connection = $null
      $ctx.Connector = $null
    }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
  }
}

Save-Utf8Text -Path (Join-Path $OutDir 'pvh_object.csv') -Text ([string]::Join("`r`n", $objectRows))
Save-Utf8Text -Path (Join-Path $OutDir 'pvh_other.csv') -Text ([string]::Join("`r`n", $otherTypeRows))
Save-Utf8Text -Path (Join-Path $OutDir 'payment_variants.csv') -Text ([string]::Join("`r`n", $paymentRows))
Save-Utf8Text -Path (Join-Path $OutDir 'service_bases.csv') -Text ([string]::Join("`r`n", $basisRows))
Save-Utf8Text -Path (Join-Path $OutDir 'report.md') -Text ([string]::Join("`r`n", $report))

Write-Output ('OUT=' + $OutDir)
Write-Output ('ALIASES=' + ($Aliases -join ','))
