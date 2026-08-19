param(
  [string]$Alias = 'x3_exp',
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

function Set-LoadMode([object]$obj) {
  try {
    $de = Get-ComProp $obj 'DataExchange'
    if ($null -ne $de) {
      Set-ComProp $de 'Load' $true
    }
  } catch {
  }
}

function Select-FirstRefByCodes {
  param(
    [object[]]$Rows,
    [string[]]$Codes
  )

  foreach ($code in $Codes) {
    foreach ($r in $Rows) {
      if ($r.Code -eq $code) { return $r.Ref }
    }
  }
  return $null
}

function Get-RefIdentity([object]$Connection, [object]$Ref) {
  if ($null -eq $Ref) { return $null }
  try { return (Invoke-Com $Connection 'XMLString' @($Ref)) } catch { return $null }
}

$propViewType = D('0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCw')
$propCalcViewType = D('0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCw0JTQu9GP0JLRi9GH0LjRgdC70LXQvdC40Y8=')
$propShowInList = D('0J/QvtC60LDQt9GL0LLQsNGC0YzQktCh0L/QuNGB0LrQtdCl0LDRgNCw0LrRgtC10YDQuNGB0YLQuNC60J7QsdGK0LXQutGC0L7Qsg==')
$propCalcChar = D('0K3RgtC+0JLRi9GH0LjRgdC70Y/QtdC80LDRj9Cl0LDRgNCw0LrRgtC10YDQuNGB0YLQuNC60LA=')
$propArea = D('0K3RgtC+0J/Qu9C+0YnQsNC00Yw=')

$viewQuery = D('0JLQq9CR0KDQkNCi0Kwg0KIu0KHRgdGL0LvQutCwINCa0JDQmiBSZWYsINCiLtCa0L7QtCDQmtCQ0JogQ29kZSwg0KIu0J3QsNC40LzQtdC90L7QstCw0L3QuNC1INCa0JDQmiBOYW1lLCDQoi7Qn9C+0LzQtdGC0LrQsNCj0LTQsNC70LXQvdC40Y8g0JrQkNCaIERlbE1hcmsg0JjQlyDQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JLQuNC00YvQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsCDQmtCQ0Jog0KIg0JPQlNCVINCiLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyA9INCb0J7QltCsINCj0J/QntCg0K/QlNCe0KfQmNCi0Kwg0J/QniDQoi7QmtC+0LQsINCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSwg0KIu0KHRgdGL0LvQutCw')
$pvhRefsQuery = D('0JLQq9CR0KDQkNCi0KwKCdCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAoJ0KIu0JrQvtC0INCa0JDQmiBDb2RlLAoJ0KIu0J3QsNC40LzQtdC90L7QstCw0L3QuNC1INCa0JDQmiBOYW1lLAoJ0KIu0K3RgtC+0JPRgNGD0L/Qv9CwINCa0JDQmiBJc0dyb3VwLAoJ0J/QoNCV0JTQodCi0JDQktCb0JXQndCY0JUo0KIu0KDQvtC00LjRgtC10LvRjCkg0JrQkNCaIFBhcmVudArQmNCXCgnQn9C70LDQvdCS0LjQtNC+0LLQpdCw0YDQsNC60YLQtdGA0LjRgdGC0LjQui7QuNC60KXQsNGA0LDQutGC0LXRgNC40YHRgtC40LrQuNCe0LHRitC10LrRgtC+0LLQo9GH0LXRgtCwINCa0JDQmiDQogrQo9Cf0J7QoNCv0JTQntCn0JjQotCsINCf0J4KCdCiLtCa0L7QtCwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtQ==')

$ctx = Connect-1CFileBase -Alias $Alias
$summary = New-Object System.Collections.Generic.List[string]
$summary.Add('# Merge x3 PVH union')
$summary.Add('')
$summary.Add('- alias: ' + $Alias)
$summary.Add('- path: ' + $ctx.Path)
$summary.Add('')

$viewTable = (New-1CQuery -Connection $ctx.Connection -Text $viewQuery).Execute().Unload()
$viewCount = [int]$viewTable.Count()
$activeViewRefsByCode = @{}
for ($i = 0; $i -lt $viewCount; $i++) {
  $row = $viewTable.Get($i)
  $isDeleted = [string](T $row.Get(3))
  if ($isDeleted -eq 'True') { continue }
  $code = T ($row.Get(1))
  if (-not $activeViewRefsByCode.ContainsKey($code)) {
    $activeViewRefsByCode[$code] = $row.Get(0)
  }
}

$pvhTable = (New-1CQuery -Connection $ctx.Connection -Text $pvhRefsQuery).Execute().Unload()
$pvhCount = [int]$pvhTable.Count()
$rows = @()
$groupRefsByCode = @{}
$existingKeys = @{}
$maxCode = 0
for ($i = 0; $i -lt $pvhCount; $i++) {
  $row = $pvhTable.Get($i)
  $ref = $row.Get(0)
  $code = T ($row.Get(1))
  $name = T ($row.Get(2))
  $isGroup = (T ($row.Get(3)) -eq 'True')
  $parentName = T ($row.Get(4))
  $rows += [pscustomobject]@{
    Ref = $ref
    Code = $code
    Name = $name
    IsGroup = $isGroup
    ParentName = $parentName
  }
  $existingKeys[($isGroup.ToString() + '|' + $parentName + '|' + $name)] = $true
  if ($isGroup) { $groupRefsByCode[$code] = $ref }
  $n = 0
  if ([int]::TryParse($code, [ref]$n)) {
    if ($n -gt $maxCode) { $maxCode = $n }
  }
}

$managerArray = Get-ComProp $ctx.Connection 'ChartsOfCharacteristicTypes'
$manager = $managerArray[6]

$parentLivingRef = $groupRefsByCode['000000160']
$livingViewRef = $activeViewRefsByCode['000000001']

$templateIntRef = $null
$templateAreaRef = $null
$templatePhoneRef = $null
$templateIntRef = Select-FirstRefByCodes -Rows $rows -Codes @('000000267','000000026','000000027')
$templateAreaRef = Select-FirstRefByCodes -Rows $rows -Codes @('000000269','000000272','000000008','000000009')
$templatePhoneRef = Select-FirstRefByCodes -Rows $rows -Codes @('000000236')
if ($null -eq $templateIntRef -or $null -eq $templateAreaRef -or $null -eq $templatePhoneRef -or $null -eq $parentLivingRef -or $null -eq $livingViewRef) {
  throw 'Required templates or refs were not found in target base'
}

$templateInt = Invoke-Com $templateIntRef 'GetObject' @()
$templateArea = Invoke-Com $templateAreaRef 'GetObject' @()
$templatePhone = Invoke-Com $templatePhoneRef 'GetObject' @()
$parentLsRef = $groupRefsByCode['000000162']
if ($null -eq $parentLsRef) {
  throw 'Required parent group ref for LS was not found in target base'
}

$itemsToAdd = @(
  @{ Name = D('0KLQtdC70LXRhNC+0L0='); IsArea = $false; ParentRef = $parentLsRef; ParentName = D('0JvQuNGG0LXQstC+0Lkg0YHRh9C10YI='); Template = 'phone' },
  @{ Name = D('0JrQvtC70LjRh9C10YHRgtCy0L4g0YEv0YUg0L/RgtC40YbRiyAo0LrRg9GA0Ysp'); IsArea = $false },
  @{ Name = D('0JrQvtC70LjRh9C10YHRgtCy0L4g0YEv0YUg0LbQuNCy0L7RgtC90YvRhSAo0JrQoNChKQ=='); IsArea = $false },
  @{ Name = D('0JrQvtC70LjRh9C10YHRgtCy0L4g0YEv0YUg0LbQuNCy0L7RgtC90YvRhSAo0L7QstGG0Ysp'); IsArea = $false },
  @{ Name = D('0JrQvtC70LjRh9C10YHRgtCy0L4g0LvQtdCz0LrQvtCy0YvRhSDQvNCw0YjQuNC9'); IsArea = $false },
  @{ Name = D('0J/QvtC70LjQstC90LDRjyDQv9C70L7RidCw0LTRjCDQt9C10LwuINGD0YfQsNGB0YLQutCw'); IsArea = $true }
)

foreach ($item in $itemsToAdd) {
  if ($null -eq $item.ParentRef) {
    $item.ParentRef = $parentLivingRef
    $item.ParentName = D('0JbQuNC70L7QtSDQv9C+0LzQtdGJ0LXQvdC40LU=')
    $item.Template = if ($item.IsArea) { 'area' } else { 'int' }
  }
}

$created = 0
$skipped = 0
foreach ($item in $itemsToAdd) {
  $key = 'False|' + $item.ParentName + '|' + $item.Name
  if ($existingKeys.ContainsKey($key)) {
    $skipped++
    $summary.Add('- skip existing: ' + $item.Name)
    continue
  }

  $newObj = Invoke-Com $manager 'CreateItem' @()
  Set-LoadMode $newObj
  $maxCode++
  Set-ComProp $newObj 'Code' ('{0:d9}' -f $maxCode)
  Set-ComProp $newObj 'Description' $item.Name
  Set-ComProp $newObj 'Parent' $item.ParentRef
  Set-ComProp $newObj 'IsFolder' $false
  Set-ComProp $newObj $propViewType $livingViewRef
  Set-ComProp $newObj $propCalcViewType $null
  Set-ComProp $newObj $propShowInList $true
  Set-ComProp $newObj $propCalcChar $false
  Set-ComProp $newObj $propArea $item.IsArea

  if ($item.Template -eq 'area') {
    Set-ComProp $newObj 'ValueType' (Get-ComProp $templateArea 'ValueType')
  } elseif ($item.Template -eq 'phone') {
    Set-ComProp $newObj 'ValueType' (Get-ComProp $templatePhone 'ValueType')
  } else {
    Set-ComProp $newObj 'ValueType' (Get-ComProp $templateInt 'ValueType')
  }

  Invoke-Com $newObj 'Write' @()
  $created++
  $summary.Add('- created: ' + $item.Name + '; code=' + ('{0:d9}' -f $maxCode))
}

$summary.Add('')
$summary.Add('- created total=' + $created)
$summary.Add('- skipped existing=' + $skipped)

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$summaryPath = Join-Path $OutDir ("{0}_merge_x3_pvh_union_{1}.md" -f $stamp, $Alias)
Save-Utf8Text -Path $summaryPath -Text ([string]::Join("`r`n", $summary))
Write-Output ('SUMMARY=' + $summaryPath)
