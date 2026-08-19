param(
  [string]$LeftAlias = 'x1_21',
  [string]$RightAlias = 'x2',
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

function Run-QueryTable {
  param(
    [object]$Connection,
    [string]$QueryText,
    [hashtable]$Parameters
  )
  $q = New-1CQuery -Connection $Connection -Text $QueryText
  if ($Parameters) {
    foreach($k in $Parameters.Keys){ $q.SetParameter($k, $Parameters[$k]) }
  }
  $result = $q.Execute()
  if ($null -eq $result) { return $null }
  return $result.Unload()
}

function Table-ToLines {
  param(
    [object]$Table,
    [string[]]$Columns
  )
  $lines = New-Object System.Collections.Generic.List[string]
  if ($null -eq $Table) {
    $lines.Add('<null table>')
    return $lines
  }
  $count = 0
  try { $count = [int]$Table.Count() } catch { $count = 0 }
  for ($i = 0; $i -lt $count; $i++) {
    $row = $Table.Get($i)
    $parts = New-Object System.Collections.Generic.List[string]
    for ($j = 0; $j -lt $Columns.Count; $j++) {
      $parts.Add(($Columns[$j] + '=' + (To-Text $row.Get($j))))
    }
    $lines.Add([string]::Join('; ', $parts))
  }
  return $lines
}

function Get-BaseReport {
  param([string]$Alias)

  $ctx = Connect-1CFileBase -Alias $Alias
  $report = New-Object System.Collections.Generic.List[string]
  $report.Add('# Support structures')
  $report.Add('')
  $report.Add('- alias: ' + $Alias)
  $report.Add('- path: ' + $ctx.Path)
  $report.Add('- role: ' + $ctx.Role)
  $report.Add('')

  $viewTypesQuery = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKCdCiLtCa0L7QtCDQmtCQ0JogQ29kZSwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogTmFtZSwKCdCiLtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjyDQmtCQ0JogRGVsTWFyawrQmNCXCgnQodC/0YDQsNCy0L7Rh9C90LjQui7QuNC60JLQuNC00YvQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsCDQmtCQ0Jog0KIK0JPQlNCVCgnQoi7QndCw0LjQvNC10L3QvtCy0LDQvdC40LUg0J/QntCU0J7QkdCd0J4gItCW0LjQu9GLJSI='
  $pvhObjectsQuery = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKCdCiLtCa0L7QtCDQmtCQ0JogQ29kZSwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogTmFtZSwKCdCiLtCt0YLQvtCT0YDRg9C/0L/QsCDQmtCQ0JogSXNHcm91cCwKCdCf0KDQldCU0KHQotCQ0JLQm9CV0J3QmNCVKNCiLtCg0L7QtNC40YLQtdC70YwpINCa0JDQmiBQYXJlbnQsCgnQoi7Qn9C+0LzQtdGC0LrQsNCj0LTQsNC70LXQvdC40Y8g0JrQkNCaIERlbE1hcmsK0JjQlwoJ0J/Qu9Cw0L3QktC40LTQvtCy0KXQsNGA0LDQutGC0LXRgNC40YHRgtC40Lou0LjQutCl0LDRgNCw0LrRgtC10YDQuNGB0YLQuNC60LjQntCx0YrQtdC60YLQvtCy0KPRh9C10YLQsCDQmtCQ0Jog0KIK0JPQlNCVCgnQndCg0LXQsyjQoi7QndCw0LjQvNC10L3QvtCy0LDQvdC40LUpINCf0J7QlNCe0JHQndCeICIl0LbQuNC7JSI='
  $pvhOtherQuery = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKCdCiLtCa0L7QtCDQmtCQ0JogQ29kZSwKCdCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogTmFtZSwKCdCiLtCt0YLQvtCT0YDRg9C/0L/QsCDQmtCQ0JogSXNHcm91cCwKCdCf0KDQldCU0KHQotCQ0JLQm9CV0J3QmNCVKNCiLtCg0L7QtNC40YLQtdC70YwpINCa0JDQmiBQYXJlbnQsCgnQoi7Qn9C+0LzQtdGC0LrQsNCj0LTQsNC70LXQvdC40Y8g0JrQkNCaIERlbE1hcmsK0JjQlwoJ0J/Qu9Cw0L3QktC40LTQvtCy0KXQsNGA0LDQutGC0LXRgNC40YHRgtC40Lou0LjQutCl0LDRgNCw0LrRgtC10YDQuNGB0YLQuNC60LjQn9GA0L7Rh9C40YXQntCx0YrQtdC60YLQvtCyINCa0JDQmiDQogrQk9CU0JUKCdCd0KDQtdCzKNCiLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSkg0J/QntCU0J7QkdCd0J4gIiXQttC40LslIg=='

  $report.Add('## ikViewTypes')
  $table = Run-QueryTable -Connection $ctx.Connection -QueryText $viewTypesQuery -Parameters @{}
  foreach($line in (Table-ToLines -Table $table -Columns @('Code','Name','DelMark'))) { $report.Add('- ' + $line) }
  $report.Add('')

  $report.Add('## PVH ikObjectCharacteristics (filter: %zhil%)')
  try {
    $table = Run-QueryTable -Connection $ctx.Connection -QueryText $pvhObjectsQuery -Parameters @{}
    foreach($line in (Table-ToLines -Table $table -Columns @('Code','Name','IsGroup','Parent','DelMark'))) { $report.Add('- ' + $line) }
  } catch {
    $report.Add('- error: ' + $_.Exception.Message)
  }
  $report.Add('')

  $report.Add('## PVH ikOtherObjectCharacteristics (filter: %zhil%)')
  try {
    $table = Run-QueryTable -Connection $ctx.Connection -QueryText $pvhOtherQuery -Parameters @{}
    foreach($line in (Table-ToLines -Table $table -Columns @('Code','Name','IsGroup','Parent','DelMark'))) { $report.Add('- ' + $line) }
  } catch {
    $report.Add('- error: ' + $_.Exception.Message)
  }
  $report.Add('')

  return [string]::Join("`r`n", $report)
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$leftPath = Join-Path $OutDir ("{0}_{1}_support.md" -f $stamp, $LeftAlias)
$rightPath = Join-Path $OutDir ("{0}_{1}_support.md" -f $stamp, $RightAlias)
$summaryPath = Join-Path $OutDir ("{0}_compare_support_{1}_vs_{2}.md" -f $stamp, $LeftAlias, $RightAlias)

$leftText = Get-BaseReport -Alias $LeftAlias
$rightText = Get-BaseReport -Alias $RightAlias
Save-Utf8Text -Path $leftPath -Text $leftText
Save-Utf8Text -Path $rightPath -Text $rightText

$leftLines = Get-Content -LiteralPath $leftPath
$rightLines = Get-Content -LiteralPath $rightPath
$skipPrefixes = @('- alias:', '- path:', '- role:')
$leftNorm = @($leftLines | Where-Object { $line = $_; -not ($skipPrefixes | Where-Object { $line.StartsWith($_) }) })
$rightNorm = @($rightLines | Where-Object { $line = $_; -not ($skipPrefixes | Where-Object { $line.StartsWith($_) }) })
$diff = Compare-Object -ReferenceObject $leftNorm -DifferenceObject $rightNorm

$summary = New-Object System.Collections.Generic.List[string]
$summary.Add('# COM compare support structures')
$summary.Add('')
$summary.Add('- left alias: ' + $LeftAlias)
$summary.Add('- right alias: ' + $RightAlias)
$summary.Add('- left report: ' + $leftPath)
$summary.Add('- right report: ' + $rightPath)
$summary.Add('')
if ($diff.Count -eq 0) {
  $summary.Add('## Result')
  $summary.Add('- normalized support reports are identical')
} else {
  $summary.Add('## Result')
  $summary.Add('- normalized support reports differ')
  $summary.Add('')
  $summary.Add('## Diff')
  foreach($item in $diff){ $summary.Add('- ' + $item.SideIndicator + ' ' + $item.InputObject) }
}
Save-Utf8Text -Path $summaryPath -Text ([string]::Join("`r`n", $summary))
Write-Output ('LEFT=' + $leftPath)
Write-Output ('RIGHT=' + $rightPath)
Write-Output ('SUMMARY=' + $summaryPath)
