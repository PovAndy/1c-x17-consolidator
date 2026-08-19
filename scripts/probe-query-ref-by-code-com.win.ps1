param(
  [string]$Alias = 'x1_21',
  [string]$Code = '000000001'
)
$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function D([string]$Value) { return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value)) }
function T([object]$Value) { if ($null -eq $Value) { return '<null>' } try { return [string]$Value } catch { return '<err>' } }
$queryText = D('0JLQq9CR0KDQkNCi0Kwg0J/QldCg0JLQq9CVIDEKICAgINCS0LjQtNGLLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmLAogICAg0JLQuNC00Ysu0JrQvtC0INCa0JDQmiBDb2RlLAogICAg0JLQuNC00Ysu0J3QsNC40LzQtdC90L7QstCw0L3QuNC1INCa0JDQmiBOYW1lCtCY0JcKICAgINCh0L/RgNCw0LLQvtGH0L3QuNC6LtC40LrQktC40LTRi9Ce0LHRitC10LrRgtC+0LLQo9GH0LXRgtCwINCa0JDQmiDQktC40LTRiwrQk9CU0JUKICAgINCS0LjQtNGLLtCa0L7QtCA9ICZDb2RlCg==')
$ctx = Connect-1CFileBase -Alias $Alias
$q = New-1CQuery -Connection $ctx.Connection -Text $queryText
$q.SetParameter('Code', $Code)
$res = $q.Execute()
$sel = $res.Choose()
if (-not $sel.Next()) { Write-Output('NO_ROWS'); exit 0 }
Write-Output ('Alias=' + $Alias + '; Code=' + $Code + '; Name=' + (T $sel.Name) + '; Ref=' + (T $sel.Ref))
