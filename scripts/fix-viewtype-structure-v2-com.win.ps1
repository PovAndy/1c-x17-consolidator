param(
  [string[]]$Aliases = @('x2_exp','x3_exp'),
  [string]$OutDir = 'T:\1S\wsl_exchange\work_epf_112_9\logs\auto'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function D([string]$Value) {
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}

function Invoke-Com([object]$obj, [string]$name, [object[]]$args = @()) {
  $obj.GetType().InvokeMember($name, [System.Reflection.BindingFlags]::InvokeMethod, $null, $obj, $args)
}

function Get-ComProp([object]$obj, [string]$name) {
  $obj.GetType().InvokeMember($name, [System.Reflection.BindingFlags]::GetProperty, $null, $obj, @())
}

function Try-GetComProp([object]$obj, [string]$name) {
  try {
    return [pscustomobject]@{ Exists = $true; Value = (Get-ComProp $obj $name) }
  } catch {
    return [pscustomobject]@{ Exists = $false; Value = $null }
  }
}

function Set-ComProp([object]$obj, [string]$name, [object]$value) {
  $obj.GetType().InvokeMember($name, [System.Reflection.BindingFlags]::SetProperty, $null, $obj, @($value)) | Out-Null
}

function T([object]$Value) {
  if ($null -eq $Value) { return '<null>' }
  try { return [string]$Value } catch { return '<err>' }
}

function Set-LoadMode([object]$obj) {
  try {
    $de = Get-ComProp $obj 'DataExchange'
    if ($null -ne $de) {
      Set-ComProp $de 'Load' $true
    }
  } catch {
  }
}

function Get-ViewTypeKeyFromRef([object]$Ref) {
  if ($null -eq $Ref) { return $null }
  try {
    $obj = Invoke-Com $Ref 'GetObject' @()
    if ($null -eq $obj) { return $null }
    $code = T (Get-ComProp $obj 'Code')
    $name = T (Get-ComProp $obj 'Description')
    if ([string]::IsNullOrWhiteSpace($code) -or [string]::IsNullOrWhiteSpace($name)) { return $null }
    return ($code + '|' + $name)
  } catch {
    return $null
  }
}

function Get-RefIdentity([object]$Connection, [object]$Ref) {
  if ($null -eq $Ref) { return $null }
  try {
    return (Invoke-Com $Connection 'XMLString' @($Ref))
  } catch {
    return $null
  }
}

function Get-TableCount([object]$Table) {
  if ($null -eq $Table) { return 0 }
  try { return [int]$Table.Count() } catch { return 0 }
}

$propViewType = D('0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCw')
$propCalcViewType = D('0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCw0JTQu9GP0JLRi9GH0LjRgdC70LXQvdC40Y8=')
$propTypeViewType = D('0KLQuNC/0J7QsdGK0LXQutGC0LDQo9GH0LXRgtCw')
$propTableType = D('0KLQuNC/0KLQsNCx0LvQuNGG0Ys=')

$queries = @{
  ViewTypesAll = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYsINCiLtCa0L7QtCDQmtCQ0JogQ29kZSwg0KIu0J3QsNC40LzQtdC90L7QstCw0L3QuNC1INCa0JDQmiBOYW1lLCDQoi7Qn9C+0LzQtdGC0LrQsNCj0LTQsNC70LXQvdC40Y8g0JrQkNCaIERlbE1hcmsg0JjQlyDQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JLQuNC00YvQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsCDQmtCQ0Jog0KIg0JPQlNCVINCiLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyA9INCb0J7QltCsINCj0J/QntCg0K/QlNCe0KfQmNCi0Kwg0J/QniDQoi7QmtC+0LQsINCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSwg0KIu0KHRgdGL0LvQutCw')
  ChartTypesRefs = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYg0JjQlyDQn9C70LDQvdCS0LjQtNC+0LLQpdCw0YDQsNC60YLQtdGA0LjRgdGC0LjQui7QuNC60KXQsNGA0LDQutGC0LXRgNC40YHRgtC40LrQuNCe0LHRitC10LrRgtC+0LLQo9GH0LXRgtCwINCa0JDQmiDQoiDQk9CU0JUg0KIu0J/QvtC80LXRgtC60LDQo9C00LDQu9C10L3QuNGPID0g0JvQntCW0Kw=')
  LsRefs = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYg0JjQlyDQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JvQuNGG0LXQstGL0LXQodGH0LXRgtCwINCa0JDQmiDQoiDQk9CU0JUg0KIu0J/QvtC80LXRgtC60LDQo9C00LDQu9C10L3QuNGPID0g0JvQntCW0Kw=')
  PremisePurposeRefs = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYg0JjQlyDQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60J3QsNC30L3QsNGH0LXQvdC40LXQn9C+0LzQtdGJ0LXQvdC40Lkg0JrQkNCaINCiINCT0JTQlSDQoi7Qn9C+0LzQtdGC0LrQsNCj0LTQsNC70LXQvdC40Y8gPSDQm9Ce0JbQrA==')
  CollectiveBasisRefs = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYg0JjQlyDQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60J7RgdC90L7QstCw0L3QuNGP0KDQsNGB0L/RgNC10LTQtdC70LXQvdC40Y/QmtC+0LvQu9C10LrRgtC40LLQvdGL0YXQn9GA0LjQsdC+0YDQvtCy0KPRh9C10YLQsCDQmtCQ0Jog0KIg0JPQlNCVINCiLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyA9INCb0J7QltCs')
  CalcBasisNormRefs = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYg0JjQlyDQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60J7RgdC90L7QstCw0L3QuNGP0KDQsNGB0YfQtdGC0LDQndC+0YDQvCDQmtCQ0Jog0KIg0JPQlNCVINCiLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyA9INCb0J7QltCs')
  CalcBasisServiceRefs = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYg0JjQlyDQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60J7RgdC90L7QstCw0L3QuNGP0KDQsNGB0YfQtdGC0LDQo9GB0LvRg9CzINCa0JDQmiDQoiDQk9CU0JUg0KIu0J/QvtC80LXRgtC60LDQo9C00LDQu9C10L3QuNGPID0g0JvQntCW0Kw=')
  ServicesRefs = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYg0JjQlyDQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60KPRgdC70YPQs9C4INCa0JDQmiDQoiDQk9CU0JUg0KIu0J/QvtC80LXRgtC60LDQo9C00LDQu9C10L3QuNGPID0g0JvQntCW0Kw=')
  OpenLsRefs = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYg0JjQlyDQlNC+0LrRg9C80LXQvdGCLtC40LrQntGC0LrRgNGL0YLQuNC10JvQuNGG0LXQstC+0LPQvtCh0YfQtdGC0LAg0JrQkNCaINCi')
  ChangePremiseInfoRefs = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYg0JjQlyDQlNC+0LrRg9C80LXQvdGCLtC40LrQmNC30LzQtdC90LXQvdC40LXQmNC90YTQvtGA0LzQsNGG0LjQuNCe0J/QvtC80LXRidC10L3QuNC4INCa0JDQmiDQog==')
  AcceptPremiseRefs = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYg0JjQlyDQlNC+0LrRg9C80LXQvdGCLtC40LrQn9GA0LjQvdGP0YLQuNC10J/QvtC80LXRidC10L3QuNGP0JrQo9GH0LXRgtGDINCa0JDQmiDQog==')
  RemoveObjectRefs = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYg0JjQlyDQlNC+0LrRg9C80LXQvdGCLtC40LrQodC90Y/RgtC40LXQntCx0YrQtdC60YLQsNCh0KPRh9C10YLQsCDQmtCQ0Jog0KI=')
  MeterStatusRefs = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYg0JjQlyDQlNC+0LrRg9C80LXQvdGCLtC40LrQmNC30LzQtdC90LXQvdC40LXQodGC0LDRgtGD0YHQvtCy0J/RgNC40LHQvtGA0L7QstCj0YfQtdGC0LAg0JrQkNCaINCi')
  FlatPaymentRows = D('0JLQq9CR0KDQkNCi0Kwg0KIu0J/QtdGA0LjQvtC0INCa0JDQmiBQZXJpb2QsINCiLtCQ0LrRgtC40LLQvdC+0YHRgtGMINCa0JDQmiBBY3RpdmUsINCiLtCS0LjQtNCe0LHRitC10LrRgtCw0KPRh9C10YLQsCDQmtCQ0JogVlQsINCiLtCh0YLQsNCy0LrQsNCd0JTQoSDQmtCQ0JogVmF0INCY0Jcg0KDQtdCz0LjRgdGC0YDQodCy0LXQtNC10L3QuNC5LtC40LrQntGC0YDQsNC20LXQvdC40LXQmtCy0LDRgNGC0L/Qu9Cw0YLRi9CS0KPRh9C10YLQtSDQmtCQ0Jog0KI=')
}

$datasets = @(
  @{ Name = 'ChartTypes'; Query = $queries.ChartTypesRefs; Fields = @($propViewType, $propCalcViewType) },
  @{ Name = 'Ls'; Query = $queries.LsRefs; Fields = @($propViewType) },
  @{ Name = 'PremisePurpose'; Query = $queries.PremisePurposeRefs; Fields = @($propViewType) },
  @{ Name = 'CollectiveBasis'; Query = $queries.CollectiveBasisRefs; Fields = @($propViewType) },
  @{ Name = 'CalcBasisNorm'; Query = $queries.CalcBasisNormRefs; Fields = @($propViewType) },
  @{ Name = 'CalcBasisService'; Query = $queries.CalcBasisServiceRefs; Fields = @($propViewType) },
  @{ Name = 'Services'; Query = $queries.ServicesRefs; Fields = @($propViewType) },
  @{ Name = 'OpenLs'; Query = $queries.OpenLsRefs; Fields = @($propViewType) },
  @{ Name = 'ChangePremiseInfo'; Query = $queries.ChangePremiseInfoRefs; Fields = @($propViewType) },
  @{ Name = 'AcceptPremise'; Query = $queries.AcceptPremiseRefs; Fields = @($propViewType) },
  @{ Name = 'RemoveObject'; Query = $queries.RemoveObjectRefs; Fields = @($propViewType) },
  @{ Name = 'MeterStatus'; Query = $queries.MeterStatusRefs; Fields = @($propTypeViewType, $propViewType) }
)

function Get-CanonicalMap([object]$Connection) {
  $table = (New-1CQuery -Connection $Connection -Text $queries.ViewTypesAll).Execute().Unload()
  $count = Get-TableCount $table
  $canonicalByKey = @{}
  $duplicates = New-Object System.Collections.Generic.List[object]

  for ($i = 0; $i -lt $count; $i++) {
    $row = $table.Get($i)
    $ref = $row.Get(0)
    $code = T ($row.Get(1))
    $name = T ($row.Get(2))
    $key = $code + '|' + $name
    if (-not $canonicalByKey.ContainsKey($key)) {
      $canonicalByKey[$key] = $ref
    } else {
      $duplicates.Add([pscustomobject]@{ Ref = $ref; Code = $code; Name = $name; Key = $key })
    }
  }

  return [pscustomobject]@{
    CanonicalByKey = $canonicalByKey
    Duplicates = $duplicates
  }
}

function Rebind-ObjectFields {
  param(
    [object]$Connection,
    [object]$Object,
    [string[]]$FieldNames,
    [hashtable]$CanonicalByKey
  )

  $changed = $false
  $changedFields = 0
  $warnings = New-Object System.Collections.Generic.List[string]

  foreach ($fieldName in $FieldNames) {
    $prop = Try-GetComProp $Object $fieldName
    if (-not $prop.Exists) { continue }

    $currentRef = $prop.Value
    $key = Get-ViewTypeKeyFromRef $currentRef
    if ([string]::IsNullOrWhiteSpace($key)) { continue }
    if (-not $CanonicalByKey.ContainsKey($key)) { continue }

    $desiredRef = $CanonicalByKey[$key]
    $currentId = Get-RefIdentity -Connection $Connection -Ref $currentRef
    $desiredId = Get-RefIdentity -Connection $Connection -Ref $desiredRef
    if (-not [string]::IsNullOrWhiteSpace($currentId) -and $currentId -eq $desiredId) { continue }

    try {
      Set-ComProp $Object $fieldName $desiredRef
      $changed = $true
      $changedFields++
    } catch {
      $warnings.Add($fieldName + ': ' + $_.Exception.Message)
    }
  }

  return [pscustomobject]@{
    Changed = $changed
    ChangedFields = $changedFields
    Warnings = $warnings
  }
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$index = New-Object System.Collections.Generic.List[string]
$index.Add('# COM fix view type structure v2')
$index.Add('')

foreach ($alias in $Aliases) {
  $ctx = Connect-1CFileBase -Alias $alias
  $mapInfo = Get-CanonicalMap -Connection $ctx.Connection
  $canonicalByKey = $mapInfo.CanonicalByKey
  $duplicates = $mapInfo.Duplicates

  $summary = New-Object System.Collections.Generic.List[string]
  $summary.Add('# Fix view type structure v2')
  $summary.Add('')
  $summary.Add('- alias: ' + $alias)
  $summary.Add('- path: ' + $ctx.Path)
  $summary.Add('- canonical groups: ' + $canonicalByKey.Count)
  $summary.Add('- active duplicates before fix: ' + $duplicates.Count)
  $summary.Add('')

  foreach ($ds in $datasets) {
    $objectsSeen = 0
    $objectsUpdated = 0
    $fieldsUpdated = 0
    $warnings = New-Object System.Collections.Generic.List[string]
    try {
      $table = (New-1CQuery -Connection $ctx.Connection -Text $ds.Query).Execute().Unload()
      $count = Get-TableCount $table
      for ($i = 0; $i -lt $count; $i++) {
        $row = $table.Get($i)
        $ref = $row.Get(0)
        $obj = Invoke-Com $ref 'GetObject' @()
        $objectsSeen++
        Set-LoadMode $obj
        $result = Rebind-ObjectFields -Connection $ctx.Connection -Object $obj -FieldNames $ds.Fields -CanonicalByKey $canonicalByKey
        if ($result.Changed) {
          Invoke-Com $obj 'Write' @()
          $objectsUpdated++
          $fieldsUpdated += $result.ChangedFields
        }
        foreach ($w in $result.Warnings) { $warnings.Add($w) }
      }
    } catch {
      $warnings.Add('QUERY_OR_OBJECT_ERROR: ' + $_.Exception.Message)
    }

    $summary.Add('- ' + $ds.Name + ': objects seen=' + $objectsSeen + '; objects updated=' + $objectsUpdated + '; fields updated=' + $fieldsUpdated)
    foreach ($w in ($warnings | Select-Object -First 20)) {
      $summary.Add('  - warning: ' + $w)
    }
  }

  $summary.Add('')
  $summary.Add('## FlatPayment')
  try {
    $table = (New-1CQuery -Connection $ctx.Connection -Text $queries.FlatPaymentRows).Execute().Unload()
    $count = Get-TableCount $table
    $rebound = 0
    for ($i = 0; $i -lt $count; $i++) {
      $row = $table.Get($i)
      $vt = $row.Get(2)
      $key = Get-ViewTypeKeyFromRef $vt
      if ([string]::IsNullOrWhiteSpace($key)) { continue }
      if ($canonicalByKey.ContainsKey($key)) {
        $rebound++
      }
    }
    $summary.Add('- rows inspected=' + $count)
    $summary.Add('- rows with resolvable canonical view type=' + $rebound)
    $summary.Add('- note: register rows are validated read-only here')
  } catch {
    $summary.Add('- error: ' + $_.Exception.Message)
  }

  $summary.Add('')
  $deleted = 0
  foreach ($dup in $duplicates) {
    try {
      $dupObj = Invoke-Com $dup.Ref 'GetObject' @()
      Set-LoadMode $dupObj
      Set-ComProp $dupObj 'DeletionMark' $true
      Invoke-Com $dupObj 'Write' @()
      $deleted++
    } catch {
      $summary.Add('- duplicate delete warning: ' + $dup.Key + '; ' + $_.Exception.Message)
    }
  }
  $summary.Add('- duplicates marked for deletion=' + $deleted)

  $summaryPath = Join-Path $OutDir ("{0}_fix_viewtype_structure_v2_{1}.md" -f $stamp, $alias)
  Save-Utf8Text -Path $summaryPath -Text ([string]::Join("`r`n", $summary))
  $index.Add('- ' + $alias + ': ' + $summaryPath)
  Write-Output ('SUMMARY_' + $alias + '=' + $summaryPath)
}

$indexPath = Join-Path $OutDir ("{0}_fix_viewtype_structure_v2_index.md" -f $stamp)
Save-Utf8Text -Path $indexPath -Text ([string]::Join("`r`n", $index))
Write-Output ('INDEX=' + $indexPath)
