param(
  [string[]]$Aliases = @('x1_01','x1_10','x1_14','x1_20','x1_21'),
  [string]$OutDir = 'T:\1S\wsl_exchange\work_epf_112_9\context\control\ls-viewtype-etalon',
  [string]$ShareDir = '{SHARE_ROOT}\epf1129\context\control\ls-viewtype-etalon'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function T([object]$v){ if($null -eq $v){ return '' }; try { return [string]$v } catch { return '<err>' } }
function Csv([string]$v){ '"' + (($v -replace '"','""')) + '"' }
function Get-ComProp([object]$obj,[string]$name){ try { $obj.GetType().InvokeMember($name,[System.Reflection.BindingFlags]::GetProperty,$null,$obj,@()) } catch { $null } }

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
if (-not (Test-Path $ShareDir)) { New-Item -ItemType Directory -Force -Path $ShareDir | Out-Null }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outPath = Join-Path $OutDir ("ls_viewtype_etalon_{0}.csv" -f $stamp)
$currentPath = Join-Path $OutDir 'ls_viewtype_etalon_current.csv'
$sharePath = Join-Path $ShareDir 'ls_viewtype_etalon_current.csv'
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('source_alias,ls_code,ls_name,object_name,viewtype_code,viewtype_name') | Out-Null

foreach($alias in $Aliases){
  $ctx = $null
  try {
    $ctx = Connect-1CFileBase -Alias $alias
    $q = New-1CQuery -Connection $ctx.Connection -Text @"
ВЫБРАТЬ
    ЛС.Ссылка КАК ЛС,
    ЛС.Код КАК ЛСКод,
    ЛС.Наименование КАК ЛСНаименование,
    ЛС.ОбъектУчета.Наименование КАК ОбъектУчетаНаименование
ИЗ
    Справочник.икЛицевыеСчета КАК ЛС
ГДЕ
    НЕ ЛС.ПометкаУдаления
"@
    $table = $q.Execute().Unload()
    for($i=0; $i -lt $table.Count(); $i++){
      $r = $table.Get($i)
      $lsRef = $r.Get(0)
      $viewCode = ''
      $viewName = ''
      try {
        $lsObj = $lsRef.GetObject()
        $viewRef = Get-ComProp $lsObj 'ВидОбъектаУчета'
        if ($null -ne $viewRef) {
          $viewObj = $viewRef.GetObject()
          $viewCode = T (Get-ComProp $viewObj 'Code')
          $viewName = T (Get-ComProp $viewObj 'Description')
        }
      } catch {}
      $lines.Add(((Csv $alias) + ',' + (Csv (T $r.Get(1)).Trim()) + ',' + (Csv (T $r.Get(2))) + ',' + (Csv (T $r.Get(3))) + ',' + (Csv $viewCode) + ',' + (Csv $viewName))) | Out-Null
    }
  } finally {
    if($ctx){ $ctx.Connection = $null; $ctx.Connector = $null }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
  }
}
$text = [string]::Join("`r`n", $lines)
Save-Utf8Text -Path $outPath -Text $text
Save-Utf8Text -Path $currentPath -Text $text
Copy-Item -Force -Path $currentPath -Destination $sharePath
Write-Output ('OUT=' + $outPath)
Write-Output ('CURRENT=' + $currentPath)
Write-Output ('SHARE=' + $sharePath)
