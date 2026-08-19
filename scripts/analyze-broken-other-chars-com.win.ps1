param(
  [string]$Alias = 'x17',
  [string]$OutPath = ''
)
$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function Save-Result($text, $path) {
  if (-not [string]::IsNullOrWhiteSpace($path)) { Save-Utf8Text -Path $path -Text $text }
  Write-Output $text
}

$ctx = Connect-1CBase -Alias $Alias

# Read all records and classify broken characteristic refs by string form.
$qText = @"
ВЫБРАТЬ
    Регистр.Период КАК Period,
    Регистр.Объект КАК ObjectRef,
    ПРЕДСТАВЛЕНИЕ(Регистр.Объект) КАК ObjectText,
    Регистр.Характеристика КАК CharRef,
    ПРЕДСТАВЛЕНИЕ(Регистр.Характеристика) КАК CharText,
    Регистр.Значение КАК Val
ИЗ
    РегистрСведений.икХарактеристикиПрочихОбъектов КАК Регистр
"@
$q = New-1CQuery -Connection $ctx.Connection -Text $qText
$table = $q.Execute().Unload()

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Broken other chars via COM')
$lines.Add('')
$lines.Add('- alias: ' + $ctx.Alias)
$lines.Add('- path: ' + $ctx.Path)
$lines.Add('- role: ' + $ctx.Role)
$lines.Add('- user: ' + $ctx.User)
$lines.Add('- total rows: ' + $table.Count())
$lines.Add('')

$broken = @{}
$examples = @{}
for ($i = 0; $i -lt $table.Count(); $i++) {
  $row = $table.Get($i)
  $charText = Convert-1CValueToString $row.Get(4)
  if (-not $charText.StartsWith('<')) { continue }
  $charRef = Convert-1CValueToString $row.Get(3)
  $key = $charRef
  if (-not $broken.ContainsKey($key)) { $broken[$key] = 0 }
  $broken[$key]++
  if (-not $examples.ContainsKey($key)) {
    $examples[$key] = [pscustomobject]@{
      ObjectText = Convert-1CValueToString $row.Get(2)
      ValueText = Convert-1CValueToString $row.Get(5)
      CharText = $charText
    }
  }
}

$lines.Add('## Broken keys')
$lines.Add('- unique broken keys: ' + $broken.Keys.Count)
$lines.Add('')
foreach ($key in ($broken.Keys | Sort-Object)) {
  $ex = $examples[$key]
  $lines.Add('- key=' + $key + '; rows=' + $broken[$key] + '; object=' + $ex.ObjectText + '; value=' + $ex.ValueText + '; char=' + $ex.CharText)
}

$text = [string]::Join("`r`n", $lines)
Save-Result $text $OutPath
