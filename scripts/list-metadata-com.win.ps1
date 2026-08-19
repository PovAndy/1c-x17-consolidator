param(
  [string]$Alias = 'x1_21',
  [string]$Kind = 'Catalogs',
  [string]$Out = 'T:\1S\wsl_exchange\work_epf_112_9\logs\auto\metadata_list.txt'
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
$metadata = $ctx.Connection.Metadata
if ($null -eq $metadata) {
  $metadata = $ctx.Connection.Metadata()
}
$lines = New-Object System.Collections.Generic.List[string]
$collection = Get-ComPropertyValue -Object $metadata -Name $Kind
$count = 0
try { $count = [int]$collection.Count } catch { $count = [int]$collection.Count() }
Write-Output ('COUNT=' + $count)
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
    $name = ''
    try { $name = [string]$obj.Name } catch {}
    if ([string]::IsNullOrWhiteSpace($name)) {
      try { $name = [string]$obj.FullName() } catch {}
    }
    if (-not [string]::IsNullOrWhiteSpace($name)) {
      $lines.Add($name)
    }
  } catch {}
}
Save-Utf8Text -Path $Out -Text ([string]::Join("`r`n", $lines))
Write-Output ('OUT=' + $Out)
