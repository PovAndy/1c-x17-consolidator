param(
  [string]$Alias = 'x1_21',
  [string]$Kind = 'Catalogs',
  [string]$Name = 'икУслуги'
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function Get-ComPropertyValue {
  param(
    [object]$Object,
    [string]$Name
  )
  return $Object.GetType().InvokeMember($Name, 'GetProperty', $null, $Object, $null)
}

$ctx = Connect-1CFileBase -Alias $Alias
$md = $ctx.Connection.Metadata
if ($null -eq $md) {
  $md = $ctx.Connection.Metadata()
}
$collection = Get-ComPropertyValue -Object $md -Name $Kind
$item = $null
$count = 0
try { $count = [int]$collection.Count } catch { $count = [int]$collection.Count() }
for ($i = 0; $i -lt $count; $i++) {
  try {
    try {
      $obj = $collection.GetType().InvokeMember('Get', 'InvokeMethod', $null, $collection, @($i))
    } catch {
      try {
        $obj = $collection.GetType().InvokeMember('Get', 'InvokeMethod', $null, $collection, @($i + 1))
      } catch {
        try {
          $obj = $collection.GetType().InvokeMember('Item', 'GetProperty', $null, $collection, @($i))
        } catch {
          $obj = $collection.GetType().InvokeMember('Item', 'GetProperty', $null, $collection, @($i + 1))
        }
      }
    }
    $objName = ''
    try { $objName = [string]$obj.Name } catch {}
    $objFullName = ''
    try { $objFullName = [string]$obj.FullName() } catch {}
    if ($objName -eq $Name -or $objFullName -eq ($Kind.TrimEnd('s') + '.' + $Name) -or $objFullName.EndsWith('.' + $Name)) {
      $item = $obj
      break
    }
  } catch {}
}
if ($null -eq $item) { throw "Metadata object not found: $Kind.$Name" }
Write-Output ('OBJECT=' + $item.FullName())
try { Write-Output ('SYNONYM=' + [string]$item.Synonym) } catch {}
try {
  try {
    $requisites = Get-ComPropertyValue -Object $item -Name 'Requisites'
  } catch {
    $requisites = Get-ComPropertyValue -Object $item -Name 'Attributes'
  }
  try { $requisitesCount = [int]$requisites.Count } catch { $requisitesCount = [int]$requisites.Count() }
  Write-Output ('ATTRIBUTES=' + $requisitesCount)
  for ($i = 0; $i -lt $requisitesCount; $i++) {
    try {
      $r = $requisites.GetType().InvokeMember('Get', 'InvokeMethod', $null, $requisites, @($i))
    } catch {
      $r = $requisites.GetType().InvokeMember('Get', 'InvokeMethod', $null, $requisites, @($i + 1))
    }
    $attrName = ''
    try { $attrName = [string](Get-ComPropertyValue -Object $r -Name 'Name') } catch {}
    $attrSynonym = ''
    try { $attrSynonym = [string](Get-ComPropertyValue -Object $r -Name 'Synonym') } catch {}
    $type=''
    try { $type = [string](Get-ComPropertyValue -Object $r -Name 'Type') } catch {}
    Write-Output ('ATTR=' + $attrName + ';SYNONYM=' + $attrSynonym + ';TYPE=' + $type)
  } 
} catch { Write-Output ('REQ_ITER_ERR=' + $_.Exception.Message) }
try {
  $tabularSections = Get-ComPropertyValue -Object $item -Name 'TabularSections'
  try { $tsCount = [int]$tabularSections.Count } catch { $tsCount = [int]$tabularSections.Count() }
  for ($i = 0; $i -lt $tsCount; $i++) {
    try {
      $t = $tabularSections.GetType().InvokeMember('Get', 'InvokeMethod', $null, $tabularSections, @($i))
    } catch {
      $t = $tabularSections.GetType().InvokeMember('Get', 'InvokeMethod', $null, $tabularSections, @($i + 1))
    }
    $tsName = ''
    try { $tsName = [string](Get-ComPropertyValue -Object $t -Name 'Name') } catch {}
    Write-Output ('TS=' + $tsName)
  }
} catch {}
