param(
  [string[]]$Aliases = @('x2','x3'),
  [string]$OutDir = 'T:\1S\wsl_exchange\work_epf_112_9\logs\auto'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function D([string]$Value) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value)) }
function T([object]$Value) { if ($null -eq $Value) { '<null>' } else { try { [string]$Value } catch { '<err>' } } }

$queries = @{
  ActiveDupGroups = D('0JLQq9CR0KDQkNCi0KwKCdCiLtCa0L7QtCDQmtCQ0JogQ29kZSwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogTmFtZSwKCdCa0J7Qm9CY0KfQldCh0KLQktCeKNCiLtCh0YHRi9C70LrQsCkg0JrQkNCaIENudArQmNCXCgnQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JLQuNC00YvQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsCDQmtCQ0Jog0KIK0JPQlNCVCgnQoi7Qn9C+0LzQtdGC0LrQsNCj0LTQsNC70LXQvdC40Y8gPSDQm9Ce0JbQrArQodCT0KDQo9Cf0J/QmNCg0J7QktCQ0KLQrCDQn9CeCgnQoi7QmtC+0LQsCgnQoi7QndCw0LjQvNC10L3QvtCy0LDQvdC40LUK0JjQnNCV0K7QqdCY0JUKCdCa0J7Qm9CY0KfQldCh0KLQktCeKNCiLtCh0YHRi9C70LrQsCkgPiAx')
  LsDeletedLinks = D('0JLQq9CR0KDQkNCi0KwKCdCa0J7Qm9CY0KfQldCh0KLQktCeKNCiLtCh0YHRi9C70LrQsCkg0JrQkNCaIENudArQmNCXCgnQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JvQuNGG0LXQstGL0LXQodGH0LXRgtCwINCa0JDQmiDQogoJCdCS0J3Qo9Ci0KDQldCd0J3QldCVINCh0J7QldCU0JjQndCV0J3QmNCVINCh0L/RgNCw0LLQvtGH0L3QuNC6LtC40LrQktC40LTRi9Ce0LHRitC10LrRgtC+0LLQo9GH0LXRgtCwINCa0JDQmiDQktCiCgkJ0J/QniDQoi7QktC40LTQntCx0YrQtdC60YLQsNCj0YfQtdGC0LAgPSDQktCiLtCh0YHRi9C70LrQsArQk9CU0JUKCdCiLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyA9INCb0J7QltCsCgnQmCDQktCiLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyA9INCY0KHQotCY0J3QkA==')
  OpenLsDeletedLinks = D('0JLQq9CR0KDQkNCi0KwKCdCa0J7Qm9CY0KfQldCh0KLQktCeKNCiLtCh0YHRi9C70LrQsCkg0JrQkNCaIENudArQmNCXCgnQlNC+0LrRg9C80LXQvdGCLtC40LrQntGC0LrRgNGL0YLQuNC10JvQuNGG0LXQstC+0LPQvtCh0YfQtdGC0LAg0JrQkNCaINCiCgkJ0JLQndCj0KLQoNCV0J3QndCV0JUg0KHQntCV0JTQmNCd0JXQndCY0JUg0KHQv9GA0LDQstC+0YfQvdC40Lou0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LAg0JrQkNCaINCS0KIKCQnQn9CeINCiLtCS0LjQtNCe0LHRitC10LrRgtCw0KPRh9C10YLQsCA9INCS0KIu0KHRgdGL0LvQutCwCtCT0JTQlQoJ0JLQoi7Qn9C+0LzQtdGC0LrQsNCj0LTQsNC70LXQvdC40Y8gPSDQmNCh0KLQmNCd0JA=')
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
foreach ($alias in $Aliases) {
  $ctx = Connect-1CFileBase -Alias $alias
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('# COM view type health')
  $lines.Add('')
  $lines.Add('- alias: ' + $alias)
  $lines.Add('- path: ' + $ctx.Path)
  $lines.Add('')

  foreach ($k in @('ActiveDupGroups','LsDeletedLinks','OpenLsDeletedLinks')) {
    try {
      $t = (New-1CQuery -Connection $ctx.Connection -Text $queries[$k]).Execute().Unload()
      $cnt = [int]$t.Count()
      if ($k -eq 'ActiveDupGroups') {
        $lines.Add('## ' + $k)
        $lines.Add('- rows: ' + $cnt)
        for ($i=0; $i -lt $cnt; $i++) {
          $r=$t.Get($i)
          $lines.Add('  - Code=' + (T $r.Get(0)) + '; Name=' + (T $r.Get(1)) + '; Cnt=' + (T $r.Get(2)))
        }
      } else {
        $v = if ($cnt -gt 0) { T ($t.Get(0).Get(0)) } else { '0' }
        $lines.Add('- ' + $k + ': ' + $v)
      }
    } catch {
      $lines.Add('- ' + $k + ': ERROR ' + $_.Exception.Message)
    }
  }

  $path = Join-Path $OutDir ("{0}_viewtype_health_{1}.md" -f $stamp, $alias)
  Save-Utf8Text -Path $path -Text ([string]::Join("`r`n", $lines))
  Write-Output ('SUMMARY_' + $alias + '=' + $path)
}
