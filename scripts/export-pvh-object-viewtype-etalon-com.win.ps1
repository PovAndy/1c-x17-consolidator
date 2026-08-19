param(
  [string[]]$Aliases = @('x1_01','x1_10','x1_14','x1_20','x1_21','x2','x3'),
  [string]$OutDir = 'T:\1S\wsl_exchange\work_epf_112_9\context\recovery\ls-structure\out',
  [string]$ShareDir = '{SHARE_ROOT}\epf1129\context\recovery\ls-structure\out'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function T([object]$v){ if($null -eq $v){ return '' }; try { return [string]$v } catch { return '' } }
function Csv([string]$v){ if($null -eq $v){ return '' }; if($v.Contains(';') -or $v.Contains('"') -or $v.Contains("`r") -or $v.Contains("`n")){ return '"' + $v.Replace('"','""') + '"' }; return $v }
function Get-ComProp([object]$obj,[string]$name){ try { $obj.GetType().InvokeMember($name,[System.Reflection.BindingFlags]::GetProperty,$null,$obj,@()) } catch { $null } }
function Norm-Text([string]$Text){
  if($null -eq $Text){ return '' }
  $s = $Text.ToLowerInvariant()
  $s = $s.Replace('ё','е')
  $s = [regex]::Replace($s, '["''`]+', ' ')
  $s = [regex]::Replace($s, '[()\\[\\]{}]+', ' ')
  $s = [regex]::Replace($s, '[_\\-]+', ' ')
  $s = [regex]::Replace($s, '\\s+', ' ')
  return $s.Trim()
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
if (-not (Test-Path $ShareDir)) { New-Item -ItemType Directory -Force -Path $ShareDir | Out-Null }

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$csvPath = Join-Path $OutDir ("pvh_obj_viewtype_etalon_{0}.csv" -f $stamp)
$currentPath = Join-Path $OutDir 'pvh_obj_viewtype_etalon_current.csv'
$sharePath = Join-Path $ShareDir 'pvh_obj_viewtype_etalon_current.csv'
$reportPath = Join-Path $OutDir ("pvh_obj_viewtype_etalon_{0}.md" -f $stamp)
$shareReportPath = Join-Path $ShareDir 'pvh_obj_viewtype_etalon_current.md'

$csv = New-Object System.Collections.Generic.List[string]
$csv.Add('source_alias;char_code;char_name;char_name_normalized;viewtype_code;viewtype_name') | Out-Null
$report = New-Object System.Collections.Generic.List[string]
$report.Add('# Export PVH object viewtype etalon') | Out-Null
$report.Add('') | Out-Null
$report.Add('- aliases: ' + ($Aliases -join ', ')) | Out-Null
$report.Add('') | Out-Null

foreach($alias in $Aliases){
  $ctx = $null
  try {
    $ctx = Connect-1CFileBase -Alias $alias
    $q = New-1CQuery -Connection $ctx.Connection -Text @"
ВЫБРАТЬ
    ПВХ.Ссылка КАК Ссылка,
    ПВХ.Код КАК Код,
    ПВХ.Наименование КАК Наименование,
    ПВХ.ЭтоГруппа КАК ЭтоГруппа,
    ПВХ.ПометкаУдаления КАК ПометкаУдаления
ИЗ
    ПланВидовХарактеристик.икХарактеристикиОбъектовУчета КАК ПВХ
УПОРЯДОЧИТЬ ПО
    Код,
    Наименование
"@
    $table = $q.Execute().Unload()
    $written = 0
    $read = 0
    for($i = 0; $i -lt $table.Count(); $i++){
      $row = $table.Get($i)
      $read++
      if([bool]$row.Get(3) -or [bool]$row.Get(4)){ continue }
      $ref = $row.Get(0)
      if($null -eq $ref){ continue }
      $obj = $null
      try { $obj = $ref.GetObject() } catch {}
      if($null -eq $obj){ continue }
      $viewRef = Get-ComProp $obj 'ВидОбъектаУчета'
      $viewCode = ''
      $viewName = ''
      if($null -ne $viewRef){
        try {
          $viewObj = $viewRef.GetObject()
          if($null -ne $viewObj){
            $viewCode = T (Get-ComProp $viewObj 'Code')
            $viewName = T (Get-ComProp $viewObj 'Description')
          }
        } catch {}
      }
      $charCode = (T $row.Get(1)).Trim()
      $charName = (T $row.Get(2)).Trim()
      if([string]::IsNullOrWhiteSpace($charName)){ continue }
      $csv.Add(([string]::Join(';', @(
        (Csv $alias),
        (Csv $charCode),
        (Csv $charName),
        (Csv (Norm-Text $charName)),
        (Csv $viewCode),
        (Csv $viewName)
      )))) | Out-Null
      $written++
    }
    $report.Add('## ' + $alias) | Out-Null
    $report.Add('- rows read: ' + $read) | Out-Null
    $report.Add('- rows written: ' + $written) | Out-Null
    $report.Add('') | Out-Null
  } finally {
    if($ctx){ $ctx.Connection = $null; $ctx.Connector = $null }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
  }
}

$csvText = [string]::Join("`r`n", $csv)
$reportText = [string]::Join("`r`n", $report)
Save-Utf8Text -Path $csvPath -Text $csvText
Save-Utf8Text -Path $currentPath -Text $csvText
Copy-Item -Force -Path $currentPath -Destination $sharePath
Save-Utf8Text -Path $reportPath -Text $reportText
Copy-Item -Force -Path $reportPath -Destination $shareReportPath
Write-Output ('CSV=' + $csvPath)
Write-Output ('CURRENT=' + $currentPath)
Write-Output ('SHARE=' + $sharePath)
Write-Output ('REPORT=' + $reportPath)
