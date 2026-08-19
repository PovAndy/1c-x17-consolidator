param([string]$Alias)
$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function Decode-Utf8Base64 { param([string]$Value) [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value)) }
function T([object]$Value) { if ($null -eq $Value) { '<null>' } else { try { ([string]$Value).Trim() } catch { '<err>' } } }
$qtxt = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKICAgINCf0KDQldCU0KHQotCQ0JLQm9CV0J3QmNCVKNCX0J3QkNCn0JXQndCY0JUo0KHQv9GA0LDQstC+0YfQvdC40Lou0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LAu0JbQuNC70YvQtdCf0L7QvNC10YnQtdC90LjRjykpINCa0JDQmiDQltC40LvRi9C1LAogICAg0J/QoNCV0JTQodCi0JDQktCb0JXQndCY0JUo0JfQndCQ0KfQldCd0JjQlSjQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JLQuNC00YvQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsC7Ql9C00LDQvdC40Y/QmNCh0L7QvtGA0YPQttC10L3QuNGPKSkg0JrQkNCaINCX0LTQsNC90LjRjywKICAgINCf0KDQldCU0KHQotCQ0JLQm9CV0J3QmNCVKNCX0J3QkNCn0JXQndCY0JUo0KHQv9GA0LDQstC+0YfQvdC40Lou0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LAu0JvQuNGG0LXQstGL0LXQodGH0LXRgtCwKSkg0JrQkNCaINCb0KEK'
$ctx = Connect-1CFileBase -Alias $Alias
try {
  $q = New-1CQuery -Connection $ctx.Connection -Text $qtxt
  $t = $q.Execute().Unload()
  $r = $t.Get(0)
  Write-Output ("Alias={0}; Жилые={1}; Здания={2}; ЛС={3}" -f $Alias, (T $r.Get(0)), (T $r.Get(1)), (T $r.Get(2)))
} catch {
  Write-Output ("Alias={0}; ERROR={1}" -f $Alias, $_.Exception.Message)
}
