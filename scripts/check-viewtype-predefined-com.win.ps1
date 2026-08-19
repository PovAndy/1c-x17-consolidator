param(
  [string[]]$Aliases = @('x1_01','x1_21','x2','x2_exp','x3','x3_exp'),
  [string]$OutDir = 'T:\1S\wsl_exchange\work_epf_112_9\logs\auto'
)
$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'
function T([object]$v){ if($null -eq $v){'<null>'} else { try{([string]$v).Trim()}catch{'<err>'} } }
function D([string]$b64){ [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)) }
$prefix = D('0KHQv9GA0LDQstC+0YfQvdC40Lou0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LAu')
$names = @(
  (D '0JbQuNC70YvQt9C10J/QvtC80LXRidC10L3QuNGP'),
  (D '0J3QtdC20LjQu9GL0J/QvtC80LXRidC10L3QuNGP'),
  (D '0JfQtNCw0L3QuNGP0JjQodC+0L7RgNGD0LbQtdC90LjRjw=='),
  (D '0JvQuNGG0LXQstGL0LXRodGH0LXRgtCw'),
  (D '0KHQvtGB0YLQsNCy0JbQuNC70YvRh9Cl0J/QvtC80LXRidC10L3QuNC5'),
  (D '0KHQvtGB0YLQsNCy0J3QtdC20LjQu9GL0J/QvtC80LXRidC10L3QuNC5')
)
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$path = Join-Path $OutDir ("{0}_viewtype_predefined_matrix.md" -f $stamp)
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# ViewType predefined matrix')
$lines.Add('')
foreach($alias in $Aliases){
  $lines.Add('## ' + $alias)
  try {
    $ctx = Connect-1CFileBase -Alias $alias
    foreach($name in $names){
      try {
        $exprRef = $prefix + $name
        $exprCode = $exprRef + (D '0JrQvtC0')
        $exprDel = $exprRef + (D 'LtCf0L7QvNC10YLQutCw0KPQtNCw0LvQtdC90LjRjw==')
        $exprEmpty = $exprRef + (D 'LtCf0YPRgdGC0LDRjygp')
        $ref = $ctx.Connection.Eval($exprRef)
        $code = $ctx.Connection.Eval($exprCode)
        $del = $ctx.Connection.Eval($exprDel)
        $empty = $ctx.Connection.Eval($exprEmpty)
        $lines.Add('- ' + $name + ': ref=' + (T $ref) + '; empty=' + (T $empty) + '; code=' + (T $code) + '; del=' + (T $del))
      } catch {
        $lines.Add('- ' + $name + ': ERROR ' + $_.Exception.Message)
      }
    }
  } catch {
    $lines.Add('- error: ' + $_.Exception.Message)
  }
  $lines.Add('')
}
Save-Utf8Text -Path $path -Text ([string]::Join("`r`n", $lines))
Write-Output ('REPORT=' + $path)
