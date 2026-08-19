param(
  [string]$Alias,
  [string]$DocNo
)
$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function Decode-Utf8Base64 { param([string]$Value) [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value)) }
function T([object]$Value) { if ($null -eq $Value) { '<null>' } else { try { ([string]$Value).Trim() } catch { '<err>' } } }
$qtxt = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKICAgINCf0KDQldCU0KHQotCQ0JLQm9CV0J3QmNCVKNCiLtCS0LjQtNCe0LHRitC10LrRgtCw0KPRh9C10YLQsCkg0JrQkNCaIERvY1ZpZXcsCiAgICDQn9Cg0JXQlNCh0KLQkNCS0JvQldCd0JjQlSjQoi7Qm9C40YbQtdCy0L7QudCh0YfQtdGCLtCS0LjQtNCe0LHRitC10LrRgtCw0KPRh9C10YLQsCkg0JrQkNCaIExzVmlldywKICAgINCiLtCS0LjQtNCe0LHRitC10LrRgtCw0KPRh9C10YLQsCA9INCiLtCb0LjRhtC10LLQvtC50KHRh9C10YIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwINCa0JDQmiBEb2NFcUxzLAogICAg0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwID0g0JfQndCQ0KfQldCd0JjQlSjQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JLQuNC00YvQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsC7QltC40LvRi9C10J/QvtC80LXRidC10L3QuNGPKSDQmtCQ0JogRG9jSXNSZXNpZGVudGlhbCwKICAgINCiLtCb0LjRhtC10LLQvtC50KHRh9C10YIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwID0g0JfQndCQ0KfQldCd0JjQlSjQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JLQuNC00YvQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsC7QltC40LvRi9C10J/QvtC80LXRidC10L3QuNGPKSDQmtCQ0JogTHNJc1Jlc2lkZW50aWFsLAogICAg0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwID0g0JfQndCQ0KfQldCd0JjQlSjQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JLQuNC00YvQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsC7Ql9C00LDQvdC40Y/QmNCh0L7QvtGA0YPQttC10L3QuNGPKSDQmtCQ0JogRG9jSXNCdWlsZGluZwrQmNCXCiAgICDQlNC+0LrRg9C80LXQvdGCLtC40LrQntGC0LrRgNGL0YLQuNC10JvQuNGG0LXQstC+0LPQvtCh0YfQtdGC0LAg0JrQkNCaINCiCtCT0JTQlQogICAg0KIu0J3QvtC80LXRgCA9ICZEb2NObwo='
$ctx = Connect-1CFileBase -Alias $Alias
try {
  $q = New-1CQuery -Connection $ctx.Connection -Text $qtxt
  $q.SetParameter('DocNo', $DocNo)
  $t = $q.Execute().Unload()
  if ([int]$t.Count() -eq 0) { Write-Output ("Alias={0}; Doc={1}; ERROR=NOT_FOUND" -f $Alias,$DocNo); exit 0 }
  $r = $t.Get(0)
  Write-Output ("Alias={0}; Doc={1}; DocView={2}; LsView={3}; DocEqLs={4}; DocIsResidential={5}; LsIsResidential={6}; DocIsBuilding={7}" -f $Alias,$DocNo,(T $r.Get(0)),(T $r.Get(1)),(T $r.Get(2)),(T $r.Get(3)),(T $r.Get(4)),(T $r.Get(5)))
} catch {
  Write-Output ("Alias={0}; Doc={1}; ERROR={2}" -f $Alias,$DocNo,$_.Exception.Message)
}
