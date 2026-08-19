param(
  [string]$Alias = 'x1_21'
)

. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

$ruSelectOne = [string]::Concat(
  [char]1042,[char]1067,[char]1041,[char]1056,[char]1040,[char]1058,[char]1068,
  ' 1 ',
  [char]1050,[char]1040,[char]1050,
  ' X'
)

$ctx = Connect-1CBase -Alias $Alias
Write-Output ('CONNECT_OK alias=' + $ctx.Alias + '; path=' + $ctx.Path + '; user=' + $ctx.User)
$query = New-1CQuery -Connection $ctx.Connection -Text $ruSelectOne
$table = $query.Execute().Unload()
Write-Output ('QUERY_OK rows=' + $table.Count())
