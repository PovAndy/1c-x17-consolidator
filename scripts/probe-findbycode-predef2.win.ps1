param([string]$Alias='x1_21')
$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function D([string]$v) { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($v)) }
$ctx = Connect-1CFileBase -Alias $Alias
$catalogs = $ctx.Connection.GetType().InvokeMember('Catalogs',[System.Reflection.BindingFlags]::GetProperty,$null,$ctx.Connection,@())
$mgr = $catalogs.GetType().InvokeMember((D('0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LA=')),[System.Reflection.BindingFlags]::GetProperty,$null,$catalogs,@())
$ref = $mgr.FindByCode('000000001')
$q = New-1CQuery -Connection $ctx.Connection -Text (D('0JLQq9CR0KDQkNCi0KwgJlJlZiA9INCX0J3QkNCn0JXQndCY0JUo0KHQv9GA0LDQstC+0YfQvdC40Lou0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LAu0JbQuNC70YvQtdCf0L7QvNC10YnQtdC90LjRjykg0JrQkNCaIElzUHJlZGVm'))
$q.SetParameter('Ref', $ref)
$t = $q.Execute().Unload()
$r = $t.Get(0)
Write-Output('Alias=' + $Alias + '; IsPredef=' + [string]$r.Get(0) + '; Ref=' + [string]$ref)
