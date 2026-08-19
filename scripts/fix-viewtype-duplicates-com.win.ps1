param(
  [string[]]$Aliases = @('x2','x3'),
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

function Set-ComProp([object]$obj, [string]$name, [object]$value) {
  $obj.GetType().InvokeMember($name, [System.Reflection.BindingFlags]::SetProperty, $null, $obj, @($value)) | Out-Null
}

function T([object]$Value) {
  if ($null -eq $Value) { return '<null>' }
  try { return [string]$Value } catch { return '<err>' }
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

function Set-LoadMode([object]$obj) {
  try {
    $de = Get-ComProp $obj 'DataExchange'
    if ($null -ne $de) {
      Set-ComProp $de 'Load' $true
    }
  } catch {
  }
}

$propViewType = D('0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCw')
$propCalcViewType = D('0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCw0JTQu9GP0JLRi9GH0LjRgdC70LXQvdC40Y8=')
$prefixDup = '[DUP] '

$queries = @{
  ViewTypesAll = D('0JLQq9CR0KDQkNCi0KwKCdCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAoJ0KIu0JrQvtC0INCa0JDQmiBDb2RlLAoJ0KIu0J3QsNC40LzQtdC90L7QstCw0L3QuNC1INCa0JDQmiBOYW1lLAoJ0KIu0J/RgNC10LTQvtC/0YDQtdC00LXQu9C10L3QvdGL0Lkg0JrQkNCaIFByZWRlZiwKCdCiLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyDQmtCQ0JogRGVsTWFyawrQmNCXCgnQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JLQuNC00YvQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsCDQmtCQ0Jog0KIK0JPQlNCVCgnQoi7Qn9C+0LzQtdGC0LrQsNCj0LTQsNC70LXQvdC40Y8gPSDQm9Ce0JbQrArQo9Cf0J7QoNCv0JTQntCn0JjQotCsINCf0J4KCdCiLtCa0L7QtCwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSwKCdCiLtCf0YDQtdC00L7Qv9GA0LXQtNC10LvQtdC90L3Ri9C5INCj0JHQq9CSLAoJ0KIu0KHRgdGL0LvQutCwINCS0J7Ql9Cg')
  ChartTypes = D('0JLQq9CR0KDQkNCi0KwKCdCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAoJ0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwINCa0JDQmiBWaWV3VHlwZVJlZiwKCdCiLtCS0LjQtNCe0LHRitC10LrRgtCw0KPRh9C10YLQsNCU0LvRj9CS0YvRh9C40YHQu9C10L3QuNGPINCa0JDQmiBDYWxjVmlld1R5cGVSZWYK0JjQlwoJ0J/Qu9Cw0L3QktC40LTQvtCy0KXQsNGA0LDQutGC0LXRgNC40YHRgtC40Lou0LjQutCl0LDRgNCw0LrRgtC10YDQuNGB0YLQuNC60LjQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsCDQmtCQ0Jog0KIK0JPQlNCVCgnQoi7Qn9C+0LzQtdGC0LrQsNCj0LTQsNC70LXQvdC40Y8gPSDQm9Ce0JbQrA==')
  Ls = D('0JLQq9CR0KDQkNCi0KwKCdCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAoJ0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwINCa0JDQmiBWaWV3VHlwZVJlZgrQmNCXCgnQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JvQuNGG0LXQstGL0LXQodGH0LXRgtCwINCa0JDQmiDQogrQk9CU0JUKCdCiLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyA9INCb0J7QltCs')
  OpenLs = D('0JLQq9CR0KDQkNCi0Kwg0J/QldCg0JLQq9CVIDEKCdCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAoJ0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwINCa0JDQmiBWaWV3VHlwZVJlZgrQmNCXCgnQlNC+0LrRg9C80LXQvdGCLtC40LrQntGC0LrRgNGL0YLQuNC10JvQuNGG0LXQstC+0LPQvtCh0YfQtdGC0LAg0JrQkNCaINCi')
  PremisePurpose = D('0JLQq9CR0KDQkNCi0KwKCdCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAoJ0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwINCa0JDQmiBWaWV3VHlwZVJlZgrQmNCXCgnQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60J3QsNC30L3QsNGH0LXQvdC40LXQn9C+0LzQtdGJ0LXQvdC40Lkg0JrQkNCaINCiCtCT0JTQlQoJ0KIu0J/QvtC80LXRgtC60LDQo9C00LDQu9C10L3QuNGPID0g0JvQntCW0Kw=')
  CalcBasisService = D('0JLQq9CR0KDQkNCi0KwKCdCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAoJ0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwINCa0JDQmiBWaWV3VHlwZVJlZgrQmNCXCgnQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60J7RgdC90L7QstCw0L3QuNGP0KDQsNGB0YfQtdGC0LDQo9GB0LvRg9CzINCa0JDQmiDQogrQk9CU0JUKCdCiLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyA9INCb0J7QltCs')
  ChangePremiseInfo = D('0JLQq9CR0KDQkNCi0KwKCdCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAoJ0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwINCa0JDQmiBWaWV3VHlwZVJlZgrQmNCXCgnQlNC+0LrRg9C80LXQvdGCLtC40LrQmNC30LzQtdC90LXQvdC40LXQmNC90YTQvtGA0LzQsNGG0LjQuNCe0J/QvtC80LXRidC10L3QuNC4INCa0JDQmiDQog==')
  CollectiveBasis = D('0JLQq9CR0KDQkNCi0KwKCdCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAoJ0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwINCa0JDQmiBWaWV3VHlwZVJlZgrQmNCXCgnQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60J7RgdC90L7QstCw0L3QuNGP0KDQsNGB0L/RgNC10LTQtdC70LXQvdC40Y/QmtC+0LvQu9C10LrRgtC40LLQvdGL0YXQn9GA0LjQsdC+0YDQvtCy0KPRh9C10YLQsCDQmtCQ0Jog0KIK0JPQlNCVCgnQoi7Qn9C+0LzQtdGC0LrQsNCj0LTQsNC70LXQvdC40Y8gPSDQm9Ce0JbQrA==')
  Services = D('0JLQq9CR0KDQkNCi0KwKCdCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAoJ0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwINCa0JDQmiBWaWV3VHlwZVJlZgrQmNCXCgnQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60KPRgdC70YPQs9C4INCa0JDQmiDQogrQk9CU0JUKCdCiLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyA9INCb0J7QltCs')
  AcceptPremise = D('0JLQq9CR0KDQkNCi0KwKCdCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAoJ0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwINCa0JDQmiBWaWV3VHlwZVJlZgrQmNCXCgnQlNC+0LrRg9C80LXQvdGCLtC40LrQn9GA0LjQvdGP0YLQuNC10J/QvtC80LXRidC10L3QuNGP0JrQo9GH0LXRgtGDINCa0JDQmiDQog==')
  CalcBasisNorm = D('0JLQq9CR0KDQkNCi0KwKCdCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAoJ0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwINCa0JDQmiBWaWV3VHlwZVJlZgrQmNCXCgnQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60J7RgdC90L7QstCw0L3QuNGP0KDQsNGB0YfQtdGC0LDQndC+0YDQvCDQmtCQ0Jog0KIK0JPQlNCVCgnQoi7Qn9C+0LzQtdGC0LrQsNCj0LTQsNC70LXQvdC40Y8gPSDQm9Ce0JbQrA==')
  RemoveObject = D('0JLQq9CR0KDQkNCi0KwKCdCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAoJ0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwINCa0JDQmiBWaWV3VHlwZVJlZgrQmNCXCgnQlNC+0LrRg9C80LXQvdGCLtC40LrQodC90Y/RgtC40LXQntCx0YrQtdC60YLQsNCh0KPRh9C10YLQsCDQmtCQ0Jog0KI=')
}

$datasets = @(
  @{ Name = 'ChartTypes'; Query = $queries.ChartTypes; Fields = @($propViewType, $propCalcViewType) },
  @{ Name = 'Ls'; Query = $queries.Ls; Fields = @($propViewType) },
  @{ Name = 'OpenLs'; Query = $queries.OpenLs; Fields = @($propViewType) },
  @{ Name = 'PremisePurpose'; Query = $queries.PremisePurpose; Fields = @($propViewType) },
  @{ Name = 'CalcBasisService'; Query = $queries.CalcBasisService; Fields = @($propViewType) },
  @{ Name = 'ChangePremiseInfo'; Query = $queries.ChangePremiseInfo; Fields = @($propViewType) },
  @{ Name = 'CollectiveBasis'; Query = $queries.CollectiveBasis; Fields = @($propViewType) },
  @{ Name = 'Services'; Query = $queries.Services; Fields = @($propViewType) },
  @{ Name = 'AcceptPremise'; Query = $queries.AcceptPremise; Fields = @($propViewType) },
  @{ Name = 'CalcBasisNorm'; Query = $queries.CalcBasisNorm; Fields = @($propViewType) },
  @{ Name = 'RemoveObject'; Query = $queries.RemoveObject; Fields = @($propViewType) }
)

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$allSummaries = New-Object System.Collections.Generic.List[string]
$allSummaries.Add('# COM fix view type duplicates')
$allSummaries.Add('')

foreach ($alias in $Aliases) {
  $ctx = Connect-1CFileBase -Alias $alias
  $summary = New-Object System.Collections.Generic.List[string]
  $summary.Add('## Base ' + $alias)
  $summary.Add('- path: ' + $ctx.Path)
  $summary.Add('')

  $viewTable = (New-1CQuery -Connection $ctx.Connection -Text $queries.ViewTypesAll).Execute().Unload()
  $rowCount = [int]$viewTable.Count()
  $canonicalByKey = @{}
  $duplicates = New-Object System.Collections.Generic.List[object]

  for ($i = 0; $i -lt $rowCount; $i++) {
    $row = $viewTable.Get($i)
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

  $summary.Add('- view type groups: ' + $canonicalByKey.Count)
  $summary.Add('- duplicate view type elements: ' + $duplicates.Count)
  $summary.Add('')

  $totalObjectsUpdated = 0
  $totalFieldsRebound = 0
  $datasetStats = New-Object System.Collections.Generic.List[string]

  foreach ($ds in $datasets) {
    $objectsUpdated = 0
    $fieldsRebound = 0
    try {
      $table = (New-1CQuery -Connection $ctx.Connection -Text $ds.Query).Execute().Unload()
      $count = [int]$table.Count()
      for ($i = 0; $i -lt $count; $i++) {
        $row = $table.Get($i)
        $objRef = $row.Get(0)
        $obj = Invoke-Com $objRef 'GetObject' @()
        $changed = $false
        Set-LoadMode $obj

        for ($f = 0; $f -lt $ds.Fields.Count; $f++) {
          $fieldName = $ds.Fields[$f]
          $currentRef = $row.Get($f + 1)
          $key = Get-ViewTypeKeyFromRef $currentRef
          if ([string]::IsNullOrWhiteSpace($key)) { continue }
          if (-not $canonicalByKey.ContainsKey($key)) { continue }
          $desiredRef = $canonicalByKey[$key]
          try {
            Set-ComProp $obj $fieldName $desiredRef
            $changed = $true
            $fieldsRebound++
          } catch {
            $datasetStats.Add($ds.Name + ': FIELD_SET_ERROR: ' + $_.Exception.Message)
          }
        }

        if ($changed) {
          Invoke-Com $obj 'Write' @()
          $objectsUpdated++
        }
      }
    } catch {
      $datasetStats.Add($ds.Name + ': QUERY_OR_WRITE_ERROR: ' + $_.Exception.Message)
    }

    $totalObjectsUpdated += $objectsUpdated
    $totalFieldsRebound += $fieldsRebound
    $summary.Add('- ' + $ds.Name + ': objects updated=' + $objectsUpdated + '; fields rebound=' + $fieldsRebound)
  }

  $summary.Add('')
  $deletedCount = 0
  foreach ($dup in $duplicates) {
    try {
      $dupObj = Invoke-Com $dup.Ref 'GetObject' @()
      Set-LoadMode $dupObj
      Set-ComProp $dupObj 'DeletionMark' $true
      $desc = T (Get-ComProp $dupObj 'Description')
      if (-not [string]::IsNullOrWhiteSpace($desc) -and -not $desc.StartsWith($prefixDup)) {
        Set-ComProp $dupObj 'Description' ($prefixDup + $desc)
      }
      Invoke-Com $dupObj 'Write' @()
      $deletedCount++
    } catch {
      $datasetStats.Add('SOFT_DELETE_ERROR ' + $dup.Code + '|' + $dup.Name + ': ' + $_.Exception.Message)
    }
  }

  $summary.Add('- duplicates soft-deleted: ' + $deletedCount)
  $summary.Add('')
  if ($datasetStats.Count -gt 0) {
    $summary.Add('### Warnings')
    foreach ($line in $datasetStats) { $summary.Add('- ' + $line) }
    $summary.Add('')
  }

  $summaryPath = Join-Path $OutDir ("{0}_fix_viewtypes_{1}.md" -f $stamp, $alias)
  Save-Utf8Text -Path $summaryPath -Text ([string]::Join("`r`n", $summary))
  $allSummaries.Add('- ' + $alias + ': ' + $summaryPath)
  Write-Output ('SUMMARY_' + $alias + '=' + $summaryPath)
}

$indexPath = Join-Path $OutDir ("{0}_fix_viewtypes_index.md" -f $stamp)
Save-Utf8Text -Path $indexPath -Text ([string]::Join("`r`n", $allSummaries))
Write-Output ('INDEX=' + $indexPath)
