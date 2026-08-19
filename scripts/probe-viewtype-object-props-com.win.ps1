param([string]$Alias='x1_21',[string]$Code='000000001')
$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function Get-ComProp([object]$obj,[string]$name){ try { $obj.GetType().InvokeMember($name,[System.Reflection.BindingFlags]::GetProperty,$null,$obj,@()) } catch { $null } }
function T([object]$v){ if($null -eq $v){'<null>'} else { try{[string]$v}catch{'<err>'}} }
$ctx = Connect-1CFileBase -Alias $Alias
$catalogs = $ctx.Connection.Catalogs
$mgr = Get-ComProp $catalogs 'икВидыОбъектовУчета'
if($null -eq $mgr){ Write-Output 'NO_MANAGER'; exit 0 }
$ref = $mgr.FindByCode($Code)
if($null -eq $ref){ Write-Output 'NO_REF'; exit 0 }
$obj = $ref.GetObject()
$props = @('Code','Description','DeletionMark','PredefinedDataName','Metadata','ThisObject','Ref')
foreach($p in $props){ $val = Get-ComProp $obj $p; Write-Output(('{0}={1}' -f $p, (T $val))) }
