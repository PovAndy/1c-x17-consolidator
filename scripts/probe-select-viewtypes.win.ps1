param([string]$Alias='x2')
$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function D([string]$v) { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($v)) }
function T([object]$v) { if($null -eq $v){'<null>'} else { try{[string]$v}catch{'<err>'} } }
$ctx = Connect-1CFileBase -Alias $Alias
$catalogs = $ctx.Connection.GetType().InvokeMember('Catalogs',[System.Reflection.BindingFlags]::GetProperty,$null,$ctx.Connection,@())
$mgr = $catalogs.GetType().InvokeMember((D('0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LA=')),[System.Reflection.BindingFlags]::GetProperty,$null,$catalogs,@())
$sel = $mgr.Select()
$limit = 0
while($sel.Next() -and $limit -lt 15) {
  Write-Output('Code=' + (T $sel.Code) + '; Name=' + (T $sel.Description) + '; Ref=' + (T $sel.Ref))
  $limit++
}
