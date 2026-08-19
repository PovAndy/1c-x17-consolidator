param([string]$Alias = 'x1_21', [string]$DocNo = '21-005')
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
$ctx = Connect-1CFileBase -Alias $Alias
$q = New-1CQuery -Connection $ctx.Connection -Text @'
ВЫБРАТЬ
	Т.Номер КАК DocNo,
	Т.ЛицевойСчет КАК LsRef
ИЗ
	Документ.икОткрытиеЛицевогоСчета КАК Т
ГДЕ
	Т.Номер = &DocNo
'@
$q.SetParameter('DocNo', $DocNo)
try {
  $t = $q.Execute().Unload()
  Write-Output ('ROWS=' + $t.Count())
  if ($t.Count() -gt 0) {
    $row = $t.Get(0)
    Write-Output ('DOC=' + [string]$row.DocNo)
    Write-Output ('LS=' + [string]$row.LsRef)
  }
} catch {
  Write-Output ('FAIL: ' + $_.Exception.Message)
}
