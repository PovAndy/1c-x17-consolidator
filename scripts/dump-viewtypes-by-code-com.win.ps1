param(
  [string]$Alias,
  [string]$OutFile
)
$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function T([object]$Value) { if ($null -eq $Value) { '<null>' } else { try { ([string]$Value).Trim() } catch { '<err>' } } }
$ctx = Connect-1CFileBase -Alias $Alias
$q = New-1CQuery -Connection $ctx.Connection -Text @'
ВЫБРАТЬ
    Виды.Код КАК Код,
    Виды.Наименование КАК Наименование,
    Виды.ПометкаУдаления КАК ПометкаУдаления,
    Виды.ЭтоГруппа КАК ЭтоГруппа,
    Виды.Ссылка КАК Ссылка
ИЗ
    Справочник.икВидыОбъектовУчета КАК Виды
УПОРЯДОЧИТЬ ПО
    Виды.Код,
    Виды.Ссылка
'@
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Alias=$Alias")
try {
  $t = $q.Execute().Unload()
  $count = [int]$t.Count()
  for ($i = 0; $i -lt $count; $i++) {
    $row = $t.Get($i)
    $lines.Add(("Code={0}; Name={1}; Del={2}; Folder={3}; Ref={4}" -f (T $row.Get(0)), (T $row.Get(1)), (T $row.Get(2)), (T $row.Get(3)), (T $row.Get(4))))
  }
} catch {
  $lines.Add('__ERROR__ ' + $_.Exception.Message)
}
$dir = Split-Path -Parent $OutFile
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[System.IO.File]::WriteAllLines($OutFile, $lines, [System.Text.Encoding]::UTF8)
Write-Host $OutFile
