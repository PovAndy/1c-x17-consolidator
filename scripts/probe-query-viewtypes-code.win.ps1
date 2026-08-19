param([string]$Alias='x2',[string]$Code='000000001')
$ErrorActionPreference='Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function D([string]$v) { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($v)) }
function T([object]$v) { if($null -eq $v){'<null>'} else { try{[string]$v}catch{'<err>'} } }
$ctx=Connect-1CFileBase -Alias $Alias
$q=New-1CQuery -Connection $ctx.Connection -Text (D('0JLQq9CR0KDQkNCi0KwKICAgINCS0LjQtNGLLtCh0YHRi9C70LrQsCDQmtCQ0Jog0KHRgdGL0LvQutCwLAogICAg0JLQuNC00Ysu0JrQvtC0INCa0JDQmiDQmtC+0LQsCiAgICDQktC40LTRiy7QndCw0LjQvNC10L3QvtCy0LDQvdC40LUg0JrQkNCaINCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSwKICAgINCS0LjQtNGLLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyDQmtCQ0Jog0J/QvtC80LXRgtC60LDQo9C00LDQu9C10L3QuNGPCtCY0JcKICAgINCh0L/RgNCw0LLQvtGH0L3QuNC6LtC40LrQktC40LTRi9Ce0LHRitC10LrRgtC+0LLQo9GH0LXRgtCwINCa0JDQmiDQktC40LTRiwrQk9CU0JUKICAgINCS0LjQtNGLLtCa0L7QtCA9ICZDb2RlCg=='))
$q.SetParameter('Code',$Code)
$t=$q.Execute().Unload()
$count=[int]$t.Count()
Write-Output('Count=' + $count)
for($i=0;$i -lt $count;$i++){ $r=$t.Get($i); Write-Output('Row=' + $i + '; Ref=' + (T $r.Get(0)) + '; Code=' + (T $r.Get(1)) + '; Name=' + (T $r.Get(2)) + '; Del=' + (T $r.Get(3))) }
