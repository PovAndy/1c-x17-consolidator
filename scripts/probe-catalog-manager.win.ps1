param([string]$Alias='x1_21')
$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function D([string]$v) { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($v)) }
$ctx = Connect-1CFileBase -Alias $Alias
$catalogs = $ctx.Connection.GetType().InvokeMember('Catalogs',[System.Reflection.BindingFlags]::GetProperty,$null,$ctx.Connection,@())
$name = D('0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LA=')
try { $mgr = $catalogs.GetType().InvokeMember($name,[System.Reflection.BindingFlags]::GetProperty,$null,$catalogs,@()); Write-Output('MgrType=' + $mgr.GetType().FullName) } catch { Write-Output('ERR=' + $_.Exception.Message) }
