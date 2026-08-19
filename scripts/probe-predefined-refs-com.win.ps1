param([string]$Alias='x1_21')
$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function T([object]$Value) { if ($null -eq $Value) { '<null>' } else { try { [string]$Value } catch { '<err>' } } }
$qtxt = @'
ВЫБРАТЬ
    ЗНАЧЕНИЕ(Справочник.икВидыОбъектовУчета.ЖилыеПомещения) КАК Ref,
    "000000001" КАК Code,
    "Жилые помещения" КАК Name
ОБЪЕДИНИТЬ ВСЕ
ВЫБРАТЬ
    ЗНАЧЕНИЕ(Справочник.икВидыОбъектовУчета.ЗданияИСооружения),
    "000000002",
    "Здания и сооружения"
ОБЪЕДИНИТЬ ВСЕ
ВЫБРАТЬ
    ЗНАЧЕНИЕ(Справочник.икВидыОбъектовУчета.ЛицевыеСчета),
    "000000003",
    "Лицевые счета"
'@
$ctx = Connect-1CFileBase -Alias $Alias
$q = New-1CQuery -Connection $ctx.Connection -Text $qtxt
$res = $q.Execute()
$sel = $res.Choose()
while ($sel.Next()) {
  Write-Output ("Code={0}; Name={1}; Ref={2}" -f (T $sel.Code), (T $sel.Name), (T $sel.Ref))
}
