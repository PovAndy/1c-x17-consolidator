param(
  [string]$LeftAlias = 'x1_21',
  [string]$RightAlias = 'x2',
  [string]$DocNo,
  [string]$LsNo = '',
  [string]$OutDir = 'T:\1S\wsl_exchange\work_epf_112_9\logs\auto'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($DocNo)) {
  throw 'DocNo is required'
}

$scriptPath = '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\address-diagnose-com.win.ps1'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$baseName = ($DocNo -replace '[^0-9A-Za-z_-]', '_')
$leftPath = Join-Path $OutDir ("{0}_{1}_{2}.md" -f $stamp, $LeftAlias, $baseName)
$rightPath = Join-Path $OutDir ("{0}_{1}_{2}.md" -f $stamp, $RightAlias, $baseName)
$summaryPath = Join-Path $OutDir ("{0}_compare_{1}_vs_{2}_{3}.md" -f $stamp, $LeftAlias, $RightAlias, $baseName)

function Invoke-AddressReport {
  param(
    [string]$Alias,
    [string]$DocNo,
    [string]$LsNo,
    [string]$OutPath
  )

  & $scriptPath -Alias $Alias -DocNo $DocNo -LsNo $LsNo -OutPath $OutPath | Out-Null
}

Invoke-AddressReport -Alias $LeftAlias -DocNo $DocNo -LsNo $LsNo -OutPath $leftPath
Invoke-AddressReport -Alias $RightAlias -DocNo $DocNo -LsNo $LsNo -OutPath $rightPath

$leftLines = Get-Content -LiteralPath $leftPath
$rightLines = Get-Content -LiteralPath $rightPath

$skipPrefixes = @('- alias:', '- path:', '- role:')
function Normalize-Lines {
  param([string[]]$Lines)
  $result = New-Object System.Collections.Generic.List[string]
  foreach ($line in $Lines) {
    $skip = $false
    foreach ($prefix in $skipPrefixes) {
      if ($line.StartsWith($prefix)) {
        $skip = $true
        break
      }
    }
    if (-not $skip) {
      $result.Add($line)
    }
  }
  return $result
}

$leftNorm = Normalize-Lines -Lines $leftLines
$rightNorm = Normalize-Lines -Lines $rightLines
$diff = Compare-Object -ReferenceObject $leftNorm -DifferenceObject $rightNorm

$summary = New-Object System.Collections.Generic.List[string]
$summary.Add('# COM compare address diagnose')
$summary.Add('')
$summary.Add('- left alias: ' + $LeftAlias)
$summary.Add('- right alias: ' + $RightAlias)
$summary.Add('- doc: ' + $DocNo)
$summary.Add('- ls: ' + $(if ([string]::IsNullOrWhiteSpace($LsNo)) { '<empty>' } else { $LsNo }))
$summary.Add('- left report: ' + $leftPath)
$summary.Add('- right report: ' + $rightPath)
$summary.Add('')

if ($diff.Count -eq 0) {
  $summary.Add('## Result')
  $summary.Add('- normalized reports are identical')
} else {
  $summary.Add('## Result')
  $summary.Add('- normalized reports differ')
  $summary.Add('')
  $summary.Add('## Diff')
  foreach ($item in $diff) {
    $summary.Add('- ' + $item.SideIndicator + ' ' + $item.InputObject)
  }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($summaryPath, $summary, $utf8NoBom)

Write-Output ('LEFT=' + $leftPath)
Write-Output ('RIGHT=' + $rightPath)
Write-Output ('SUMMARY=' + $summaryPath)
