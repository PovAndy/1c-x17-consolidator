param(
  [string[]]$Aliases = @('x1_01','x1_10','x1_14','x1_20','x1_21','x2','x3'),
  [string]$OutDir = 'T:\1S\wsl_exchange\work_epf_112_9\logs\auto'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function Decode-Utf8Base64 {
  param([string]$Value)
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}

function To-Text {
  param([object]$Value)
  if ($null -eq $Value) { return '<null>' }
  try { return ([string]$Value).Trim() } catch { return '<unprintable>' }
}

function Exec-Table {
  param([object]$Connection,[string]$QueryText)
  $q = New-1CQuery -Connection $Connection -Text $QueryText
  $r = $q.Execute()
  if ($null -eq $r) { return $null }
  return $r.Unload()
}

$countViewQuery = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0Kwg0JrQntCb0JjQp9CV0KHQotCS0J4oKikg0JrQkNCaIENudCDQmNCXINCh0L/RgNCw0LLQvtGH0L3QuNC6LtC40LrQktC40LTRi9Ce0LHRitC10LrRgtC+0LLQo9GH0LXRgtCwINCa0JDQmiDQog=='
$dupViewQuery = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKCdCiLtCa0L7QtCDQmtCQ0JogQ29kZSwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogTmFtZSwKCdCa0J7Qm9CY0KfQldCh0KLQktCeKCopINCa0JDQmiBDbnQK0JjQlwoJ0KHQv9GA0LDQstC+0YfQvdC40Lou0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LAg0JrQkNCaINCiCtCh0JPQoNCj0J/Qn9CY0KDQntCS0JDQotCsINCf0J4KCdCiLtCa0L7QtCwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtQrQmNCc0JXQrtCp0JjQlQoJ0JrQntCb0JjQp9CV0KHQotCS0J4oKikgPiAx'
$countObjQuery = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0Kwg0JrQntCb0JjQp9CV0KHQotCS0J4oKikg0JrQkNCaIENudCDQmNCXINCf0LvQsNC90JLQuNC00L7QstCl0LDRgNCw0LrRgtC10YDQuNGB0YLQuNC6LtC40LrQpdCw0YDQsNC60YLQtdGA0LjRgdGC0LjQutC40J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LAg0JrQkNCaINCi'
$dupObjQuery = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKCdCiLtCa0L7QtCDQmtCQ0JogQ29kZSwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogTmFtZSwKCdCa0J7Qm9CY0KfQldCh0KLQktCeKCopINCa0JDQmiBDbnQK0JjQlwoJ0J/Qu9Cw0L3QktC40LTQvtCy0KXQsNGA0LDQutGC0LXRgNC40YHRgtC40Lou0LjQutCl0LDRgNCw0LrRgtC10YDQuNGB0YLQuNC60LjQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsCDQmtCQ0Jog0KIK0KHQk9Cg0KPQn9Cf0JjQoNCe0JLQkNCi0Kwg0J/QngoJ0KIu0JrQvtC0LAoJ0KIu0J3QsNC40LzQtdC90L7QstCw0L3QuNC1CtCY0JzQldCu0KnQmNCVCgnQmtCe0JvQmNCn0JXQodCi0JLQnigqKSA+IDE='
$countOtherQuery = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0Kwg0JrQntCb0JjQp9CV0KHQotCS0J4oKikg0JrQkNCaIENudCDQmNCXINCf0LvQsNC90JLQuNC00L7QstCl0LDRgNCw0LrRgtC10YDQuNGB0YLQuNC6LtC40LrQpdCw0YDQsNC60YLQtdGA0LjRgdGC0LjQutC40J/RgNC+0YfQuNGF0J7QsdGK0LXQutGC0L7QsiDQmtCQ0Jog0KI='
$dupOtherQuery = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKCdCiLtCa0L7QtCDQmtCQ0JogQ29kZSwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogTmFtZSwKCdCa0J7Qm9CY0KfQldCh0KLQktCeKCopINCa0JDQmiBDbnQK0JjQlwoJ0J/Qu9Cw0L3QktC40LTQvtCy0KXQsNGA0LDQutGC0LXRgNC40YHRgtC40Lou0LjQutCl0LDRgNCw0LrRgtC10YDQuNGB0YLQuNC60LjQn9GA0L7Rh9C40YXQntCx0YrQtdC60YLQvtCyINCa0JDQmiDQogrQodCT0KDQo9Cf0J/QmNCg0J7QktCQ0KLQrCDQn9CeCgnQoi7QmtC+0LQsCgnQoi7QndCw0LjQvNC10L3QvtCy0LDQvdC40LUK0JjQnNCV0K7QqdCY0JUKCdCa0J7Qm9CY0KfQldCh0KLQktCeKCopID4gMQ=='

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportPath = Join-Path $OutDir ("{0}_structure_health_matrix.md" -f $stamp)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Structure health matrix')
$lines.Add('')

foreach ($alias in $Aliases) {
  $lines.Add('## ' + $alias)
  try {
    $ctx = Connect-1CFileBase -Alias $alias
    $lines.Add('- path: ' + $ctx.Path)
    $lines.Add('- role: ' + $ctx.Role)

    $viewCountTable = Exec-Table -Connection $ctx.Connection -QueryText $countViewQuery
    $viewDupTable = Exec-Table -Connection $ctx.Connection -QueryText $dupViewQuery
    $objCountTable = Exec-Table -Connection $ctx.Connection -QueryText $countObjQuery
    $objDupTable = Exec-Table -Connection $ctx.Connection -QueryText $dupObjQuery
    $otherCountTable = Exec-Table -Connection $ctx.Connection -QueryText $countOtherQuery
    $otherDupTable = $null
    $otherDupError = ''
    try {
      $otherDupTable = Exec-Table -Connection $ctx.Connection -QueryText $dupOtherQuery
    } catch {
      $otherDupError = $_.Exception.Message
    }

    $viewCount = '0'
    $objCount = '0'
    $otherCount = '0'
    $viewDupCount = 0
    $objDupCount = 0
    $otherDupCount = 0

    try {
      if ($null -ne $viewCountTable -and [int]$viewCountTable.Count() -gt 0) {
        $viewCount = To-Text ($viewCountTable.Get(0).Get(0))
      }
    } catch {
    }
    try {
      if ($null -ne $objCountTable -and [int]$objCountTable.Count() -gt 0) {
        $objCount = To-Text ($objCountTable.Get(0).Get(0))
      }
    } catch {
    }
    try {
      if ($null -ne $otherCountTable -and [int]$otherCountTable.Count() -gt 0) {
        $otherCount = To-Text ($otherCountTable.Get(0).Get(0))
      }
    } catch {
    }
    try {
      if ($null -ne $viewDupTable) { $viewDupCount = [int]$viewDupTable.Count() }
    } catch {
    }
    try {
      if ($null -ne $objDupTable) { $objDupCount = [int]$objDupTable.Count() }
    } catch {
    }
    try {
      if ($null -ne $otherDupTable) { $otherDupCount = [int]$otherDupTable.Count() }
    } catch {
    }

    $lines.Add('- ikViewTypes count: ' + $viewCount)
    $lines.Add('- PVH object count: ' + $objCount)
    $lines.Add('- PVH other count: ' + $otherCount)
    $lines.Add('- ikViewTypes duplicates: ' + $viewDupCount)
    if ($viewDupCount -gt 0) {
      for ($i=0; $i -lt [Math]::Min($viewDupCount, 10); $i++) {
        $row = $viewDupTable.Get($i)
        $lines.Add('  - view dup: code=' + (To-Text $row.Get(0)) + '; name=' + (To-Text $row.Get(1)) + '; cnt=' + (To-Text $row.Get(2)))
      }
    }
    $lines.Add('- PVH object duplicates: ' + $objDupCount)
    if ($objDupCount -gt 0) {
      for ($i=0; $i -lt [Math]::Min($objDupCount, 10); $i++) {
        $row = $objDupTable.Get($i)
        $lines.Add('  - pvh obj dup: code=' + (To-Text $row.Get(0)) + '; name=' + (To-Text $row.Get(1)) + '; cnt=' + (To-Text $row.Get(2)))
      }
    }
    $lines.Add('- PVH other duplicates: ' + $otherDupCount)
    if (-not [string]::IsNullOrWhiteSpace($otherDupError)) {
      $lines.Add('  - pvh other error: ' + $otherDupError)
    }
    if ($otherDupCount -gt 0) {
      for ($i=0; $i -lt [Math]::Min($otherDupCount, 10); $i++) {
        $row = $otherDupTable.Get($i)
        $lines.Add('  - pvh other dup: code=' + (To-Text $row.Get(0)) + '; name=' + (To-Text $row.Get(1)) + '; cnt=' + (To-Text $row.Get(2)))
      }
    }
  } catch {
    $lines.Add('- error: ' + $_.Exception.Message)
  }
  $lines.Add('')
}

Save-Utf8Text -Path $reportPath -Text ([string]::Join("`r`n", $lines))
Write-Output ('REPORT=' + $reportPath)
