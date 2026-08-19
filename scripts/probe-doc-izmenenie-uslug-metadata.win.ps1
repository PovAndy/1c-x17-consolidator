param(
  [string]$Alias = 'x1_14',
  [string]$Out = 'T:\1S\wsl_exchange\work_epf_112_9\logs\probe_doc_izmenenie_uslug_metadata.txt'
)
$ErrorActionPreference = 'Stop'
. 'T:\1S\wsl_exchange\work_epf_112_9\scripts\1c-com-common.win.ps1'
$ctx = Connect-1CFileBase -Alias $Alias -ConfigPath 'T:\1S\wsl_exchange\work_epf_112_9\scripts\1c-bases.win.json' -EnvPath 'T:\1S\wsl_exchange\work_epf_112_9\.env'
$lines = New-Object System.Collections.Generic.List[string]
$item = $null
foreach($obj in $ctx.Connection.Metadata.Documents){
  try {
    if([string]$obj.Name -eq 'икИзменениеУслугЛицевогоСчета') { $item = $obj; break }
  } catch {}
}
if($null -eq $item){ throw 'Metadata object not found: Documents.икИзменениеУслугЛицевогоСчета' }
$lines.Add('OBJECT=' + [string]$item.Name)
try {
  foreach($r in $item.Requisites){
    $lines.Add('REQ=' + [string]$r.Name)
  }
} catch {
  $lines.Add('REQ_ERR=' + $_.Exception.Message)
}
try {
  foreach($t in $item.TabularSections){
    $lines.Add('TS=' + [string]$t.Name)
    foreach($r in $t.Requisites){
      $lines.Add('TSREQ=' + [string]$t.Name + ';' + [string]$r.Name)
    }
  }
} catch {
  $lines.Add('TS_ERR=' + $_.Exception.Message)
}
Save-Utf8Text -Path $Out -Text ([string]::Join("`r`n", $lines))
Write-Output ('OUT=' + $Out)
