param([string]$Alias='x1_21')
$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
$ctx = Connect-1CFileBase -Alias $Alias
Write-Output ('ConnType=' + $ctx.Connection.GetType().FullName)
try { $catalogs = $ctx.Connection.GetType().InvokeMember('Catalogs',[System.Reflection.BindingFlags]::GetProperty,$null,$ctx.Connection,@()); Write-Output('CatalogsType=' + $catalogs.GetType().FullName) } catch { Write-Output('CatalogsERR=' + $_.Exception.Message) }
