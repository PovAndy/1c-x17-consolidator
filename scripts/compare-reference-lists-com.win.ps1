param(
  [string]$LeftAlias = 'x1_21',
  [string]$RightAlias = 'x2',
  [string]$OutDir = 'T:\1S\wsl_exchange\work_epf_112_9\logs\auto'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function Decode-Utf8Base64 { param([string]$Value) [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value)) }
function T([object]$Value) { if ($null -eq $Value) { '<null>' } else { try { ([string]$Value).Trim() } catch { '<err>' } } }

$queries = @{
  ViewTypes = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKCdCiLtCa0L7QtCDQmtCQ0JogQ29kZSwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogTmFtZSwKCdCiLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyDQmtCQ0JogRGVsTWFyawrQmNCXCgnQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JLQuNC00YvQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsCDQmtCQ0Jog0KIK0KPQn9Ce0KDQr9CU0J7Qp9CY0KLQrCDQn9CeCgnQoi7QmtC+0LQsCgnQoi7QndCw0LjQvNC10L3QvtCy0LDQvdC40LU='
  PvhObject = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKCdCiLtCa0L7QtCDQmtCQ0JogQ29kZSwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogTmFtZSwKCdCiLtCt0YLQvtCT0YDRg9C/0L/QsCDQmtCQ0JogSXNHcm91cCwKCdCf0KDQldCU0KHQotCQ0JLQm9CV0J3QmNCVKNCiLtCg0L7QtNC40YLQtdC70YwpINCa0JDQmiBQYXJlbnQK0JjQlwoJ0J/Qu9Cw0L3QktC40LTQvtCy0KXQsNGA0LDQutGC0LXRgNC40YHRgtC40Lou0LjQutCl0LDRgNCw0LrRgtC10YDQuNGB0YLQuNC60LjQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsCDQmtCQ0Jog0KIK0KPQn9Ce0KDQr9CU0J7Qp9CY0KLQrCDQn9CeCgnQoi7QmtC+0LQsCgnQoi7QndCw0LjQvNC10L3QvtCy0LDQvdC40LU='
  PvhOther = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKCdCiLtCa0L7QtCDQmtCQ0JogQ29kZSwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogTmFtZSwKCdCiLtCt0YLQvtCT0YDRg9C/0L/QsCDQmtCQ0JogSXNHcm91cCwKCdCf0KDQldCU0KHQotCQ0JLQm9CV0J3QmNCVKNCiLtCg0L7QtNC40YLQtdC70YwpINCa0JDQmiBQYXJlbnQK0JjQlwoJ0J/Qu9Cw0L3QktC40LTQvtCy0KXQsNGA0LDQutGC0LXRgNC40YHRgtC40Lou0LjQutCl0LDRgNCw0LrRgtC10YDQuNGB0YLQuNC60LjQn9GA0L7Rh9C40YXQntCx0YrQtdC60YLQvtCyINCa0JDQmiDQogrQo9Cf0J7QoNCv0JTQntCn0JjQotCsINCf0J4KCdCiLtCa0L7QtCwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtQ=='
}

function Fetch-Lines {
  param([string]$Alias,[string]$QueryText,[string[]]$Columns)
  $lines = New-Object System.Collections.Generic.List[string]
  try {
    $ctx = Connect-1CFileBase -Alias $Alias
    $q = New-1CQuery -Connection $ctx.Connection -Text $QueryText
    $t = $q.Execute().Unload()
    $count = 0
    try { $count = [int]$t.Count() } catch { $count = 0 }
    for ($i = 0; $i -lt $count; $i++) {
      $row = $t.Get($i)
      $parts = New-Object System.Collections.Generic.List[string]
      for ($j = 0; $j -lt $Columns.Count; $j++) {
        $parts.Add($Columns[$j] + '=' + (T $row.Get($j)))
      }
      $lines.Add([string]::Join('; ', $parts))
    }
  } catch {
    $lines.Add('__ERROR__ ' + $_.Exception.Message)
  }
  return $lines
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$summary = New-Object System.Collections.Generic.List[string]
$summary.Add('# COM compare reference lists')
$summary.Add('')
$summary.Add('- left alias: ' + $LeftAlias)
$summary.Add('- right alias: ' + $RightAlias)
$summary.Add('')

foreach ($name in @('ViewTypes','PvhObject','PvhOther')) {
  $cols = if ($name -eq 'ViewTypes') { @('Code','Name','DelMark') } else { @('Code','Name','IsGroup','Parent') }
  $left = Fetch-Lines -Alias $LeftAlias -QueryText $queries[$name] -Columns $cols
  $right = Fetch-Lines -Alias $RightAlias -QueryText $queries[$name] -Columns $cols
  $leftPath = Join-Path $OutDir ("{0}_{1}_{2}.txt" -f $stamp, $LeftAlias, $name)
  $rightPath = Join-Path $OutDir ("{0}_{1}_{2}.txt" -f $stamp, $RightAlias, $name)
  Save-Utf8Text -Path $leftPath -Text ([string]::Join("`r`n", $left))
  Save-Utf8Text -Path $rightPath -Text ([string]::Join("`r`n", $right))
  $diff = Compare-Object -ReferenceObject $left -DifferenceObject $right
  $summary.Add('## ' + $name)
  $summary.Add('- left count: ' + $left.Count)
  $summary.Add('- right count: ' + $right.Count)
  $summary.Add('- left file: ' + $leftPath)
  $summary.Add('- right file: ' + $rightPath)
  if ($diff.Count -eq 0) {
    $summary.Add('- result: identical')
  } else {
    $summary.Add('- result: differ')
    foreach ($item in $diff) { $summary.Add('  - ' + $item.SideIndicator + ' ' + $item.InputObject) }
  }
  $summary.Add('')
}

$summaryPath = Join-Path $OutDir ("{0}_compare_reference_lists_{1}_vs_{2}.md" -f $stamp, $LeftAlias, $RightAlias)
Save-Utf8Text -Path $summaryPath -Text ([string]::Join("`r`n", $summary))
Write-Output ('SUMMARY=' + $summaryPath)
