param([string]$Alias = 'x1_21')

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function D([string]$b64) {
  return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64))
}

function TryQ([object]$conn, [string]$label, [string]$text) {
  Write-Output ('TEST=' + $label)
  try {
    $q = New-1CQuery -Connection $conn -Text $text
    $r = $q.Execute()
    if ($null -eq $r) { Write-Output 'EXEC_NULL'; return }
    $t = $r.Unload()
    if ($null -eq $t) { Write-Output 'TABLE_NULL'; return }
    Write-Output ('ROWS=' + $t.Count())
  } catch {
    Write-Output ('FAIL: ' + $_.Exception.Message)
  }
}

$q1 = '0JLQq9CR0KDQkNCi0KwKCdEg0JrQkNCaIFg='
$q2 = '0JLQq9CR0KDQkNCi0KwKCdCf0JXQoNCi0KvQlSAxINCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmINCY0Jc g0JTQvtC60YPQvNC10L3Rgi7QuNC60J7RgtC60YDRi9GC0LjQtdCb0LjRhtC10LLQvtCz0L7QodGH0LXRgtCwINCa0JDQmiDQog=='
$q3 = '0JLQq9CR0KDQkNCi0KwKCdCf0JXQoNCi0KvQlSAxINCiLtCh0YHRi9C70LrQsCDQmtCQ0JogUmVmINCY0Jc g0KHQv9GA0LDQstC+0YfQvdC40Lou0LjQutCb0LjRhtC10LLRi9C10KHRh9C10YLQsCDQmtCQ0Jog0KI='

$ctx = Connect-1CFileBase -Alias $Alias
TryQ $ctx.Connection 'const' (D $q1)
TryQ $ctx.Connection 'doc_ref' (D ($q2 -replace ' ', ''))
TryQ $ctx.Connection 'catalog_ref' (D ($q3 -replace ' ', ''))
