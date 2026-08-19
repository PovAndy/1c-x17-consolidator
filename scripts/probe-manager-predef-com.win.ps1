param([string]$Alias='x1_21')
$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function Get-ComProp([object]$obj,[string]$name){ $obj.GetType().InvokeMember($name,[System.Reflection.BindingFlags]::GetProperty,$null,$obj,@()) }
function T([object]$v){ if($null -eq $v){'<null>'} else { try{[string]$v}catch{'<err>'}} }
$ctx = Connect-1CFileBase -Alias $Alias
$catalogs = Get-ComProp $ctx.Connection 'Catalogs'
$catName = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LA='))
$manager = Get-ComProp $catalogs $catName
$names = @(
 [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('0JbQuNC70YvQtdCf0L7QvNC10YnQtdC90LjRjw==')),
 [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('0JfQtNCw0L3QuNGP0JjQodC+0L7RgNGD0LbQtdC90LjRjw==')),
 [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('0JvQuNGG0LXQstGL0LUg0YHRh9C10YLQsA==')).Replace(' ','')
)
foreach($n in $names){ try { $ref = Get-ComProp $manager $n; Write-Output("Name=$n; Ref=$(T $ref)") } catch { Write-Output("Name=$n; ERROR=$($_.Exception.Message)") } }
