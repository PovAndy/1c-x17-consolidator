param(
  [string]$Alias = 'x1_21'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

$ctx = Connect-1CFileBase -Alias $Alias
$mgr = $ctx.Connection.Catalogs.икВидыОбъектовУчета
$ref = $mgr.FindByCode('000000001')

Write-Output ('Alias=' + $Alias + '; Ref=' + [string]$ref)
