param([string]$Alias = 'x1_21', [string]$DocNo = '21-005')
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function RunQ($conn, $text, $params) {
  $q = New-1CQuery -Connection $conn -Text $text
  foreach ($k in $params.Keys) { $q.SetParameter($k, $params[$k]) }
  $r = $q.Execute()
  if ($null -eq $r) { Write-Output 'EXEC_NULL'; return $null }
  Write-Output ('EXEC_TYPE=' + $r.GetType().FullName)
  try {
    $t = $r.Unload()
    if ($null -eq $t) { Write-Output 'UNLOAD_NULL'; return $null }
    Write-Output ('UNLOAD_TYPE=' + $t.GetType().FullName)
    Write-Output ('ROWS=' + $t.Count())
    return $t
  } catch {
    Write-Output ('UNLOAD_FAIL: ' + $_.Exception.Message)
    return $null
  }
}
$ctx = Connect-1CFileBase -Alias $Alias
$q = @'
ВЫБРАТЬ
	Т.Номер КАК DocNo
ИЗ
	Документ.икОткрытиеЛицевогоСчета КАК Т
ГДЕ
	Т.Номер = &DocNo
'@
RunQ $ctx.Connection $q @{ DocNo = $DocNo } | Out-Null
