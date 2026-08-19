param([string]$Alias='x2')
$ErrorActionPreference='Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function D([string]$v) { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($v)) }
function T([object]$v) { if($null -eq $v){'<null>'} else { try{[string]$v}catch{'<err>'} } }
$ctx=Connect-1CFileBase -Alias $Alias
$rowsQ=New-1CQuery -Connection $ctx.Connection -Text (D('0JLQq9CR0KDQkNCi0KwKICAgINCS0LjQtNGLLtCh0YHRi9C70LrQsCDQmtCQ0Jog0KHRgdGL0LvQutCwLAogICAg0JLQuNC00Ysu0JrQvtC0INCa0JDQmiDQmtC+0LQsCiAgICDQktC40LTRiy7QndCw0LjQvNC10L3QvtCy0LDQvdC40LUg0JrQkNCaINCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSwKICAgINCS0LjQtNGLLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyDQmtCQ0Jog0J/QvtC80LXRgtC60LDQo9C00LDQu9C10L3QuNGPCtCY0JcKICAgINCh0L/RgNCw0LLQvtGH0L3QuNC6LtC40LrQktC40LTRi9Ce0LHRitC10LrRgtC+0LLQo9GH0LXRgtCwINCa0JDQmiDQktC40LTRiwrQk9CU0JUKICAgINCS0LjQtNGLLtCa0L7QtCA9ICZDb2RlCg=='))
$cmpQ=New-1CQuery -Connection $ctx.Connection -Text (D('0JLQq9CR0KDQkNCi0KwKICAgICZSZWYgPSDQl9Cd0JDQp9CV0J3QmNCVKNCh0L/RgNCw0LLQvtGH0L3QuNC6LtC40LrQktC40LTRi9Ce0LHRitC10LrRgtC+0LLQo9GH0LXRgtCwLtCW0LjQu9GL0LXQn9C+0LzQtdGJ0LXQvdC40Y8pINCa0JDQmiBJc1Jlc2lkZW50aWFsLAogICAgJlJlZiA9INCX0J3QkNCn0JXQndCY0JUo0KHQv9GA0LDQstC+0YfQvdC40Lou0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LAu0JfQtNCw0L3QuNGP0JjQodC+0L7RgNGD0LbQtdC90LjRjykg0JrQkNCaIElzQnVpbGRpbmcsCiAgICAmUmVmID0g0JfQndCQ0KfQldCd0JjQlSjQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JLQuNC00YvQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsC7Qm9C40YbQtdCy0YvQtdCh0YfQtdGC0LApINCa0JDQmiBJc0xzLAogICAgJlJlZiA9INCX0J3QkNCn0JXQndCY0JUo0KHQv9GA0LDQstC+0YfQvdC40Lou0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LAu0J3QtdC20LjQu9GL0LXQn9C+0LzQtdGJ0LXQvdC40Y8pINCa0JDQmiBJc05vblJlcywKICAgICZSZWYgPSDQl9Cd0JDQp9CV0J3QmNCVKNCh0L/RgNCw0LLQvtGH0L3QuNC6LtC40LrQktC40LTRi9Ce0LHRitC10LrRgtC+0LLQo9GH0LXRgtCwLtCf0L7QtNGK0LXQt9C00YspINCa0JDQmiBJc0VudHJhbmNlLAogICAgJlJlZiA9INCX0J3QkNCn0JXQndCY0JUo0KHQv9GA0LDQstC+0YfQvdC40Lou0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LAu0KHQvtGB0YLQsNCy0JbQuNC70YvRhdCf0L7QvNC10YnQtdC90LjQuSkg0JrQkNCaIElzUmVzQ29tcCwKICAgICZSZWYgPSDQl9Cd0JDQp9CV0J3QmNCVKNCh0L/RgNCw0LLQvtGH0L3QuNC6LtC40LrQktC40LTRi9Ce0LHRitC10LrRgtC+0LLQo9GH0LXRgtCwLtCh0L7RgdGC0LDQstCd0LXQttC40LvRi9GF0J/QvtC80LXRidC10L3QuNC5KSDQmtCQ0JogSXNOb25SZXNDb21wCg=='))
$codes=@('000000001','000000002','000000003','000000004','000000005','000000006','000000007')
foreach($code in $codes){
  $rowsQ.SetParameter('Code',$code)
  $t=$rowsQ.Execute().Unload()
  $count=[int]$t.Count()
  Write-Output('CODE=' + $code + '; COUNT=' + $count)
  for($i=0;$i -lt $count;$i++){
    $r=$t.Get($i)
    $ref=$r.Get(0)
    $cmpQ.SetParameter('Ref',$ref)
    $ct=$cmpQ.Execute().Unload(); $cr=$ct.Get(0)
    Write-Output('  Row=' + $i + '; Name=' + (T $r.Get(2)) + '; Pred=' + ([string]$cr.Get(0)) + ',' + ([string]$cr.Get(1)) + ',' + ([string]$cr.Get(2)) + ',' + ([string]$cr.Get(3)) + ',' + ([string]$cr.Get(4)) + ',' + ([string]$cr.Get(5)) + ',' + ([string]$cr.Get(6)))
  }
}
