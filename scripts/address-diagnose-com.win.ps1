param(
  [string]$Alias = 'x2',
  [string]$DocNo,
  [string]$LsNo = '',
  [string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function Decode-Utf8Base64 {
  param([string]$Value)
  return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}

function To-Text {
  param([object]$Value)
  if ($null -eq $Value) { return '<null>' }
  try { return [string]$Value } catch { return '<unprintable>' }
}

function Get-TableCountSafe {
  param([object]$Table)
  if ($null -eq $Table) { return 0 }

  try {
    $value = $Table.Count()
    if ($null -ne $value) { return [int]$value }
  } catch {
  }

  try {
    $value = $Table.Count
    if ($null -ne $value) { return [int]$value }
  } catch {
  }

  return 0
}

$docQuery = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKCdCiLtCd0L7QvNC10YAg0JrQkNCaIERvY05vLAoJ0KIu0JTQsNGC0LAg0JrQkNCaIERvY0RhdGUsCgnQoi7QntGA0LPQsNC90LjQt9Cw0YbQuNGPLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogT3JnTmFtZSwKCdCiLtCb0LjRhtC10LLQvtC50KHRh9C10YIu0JrQvtC0INCa0JDQmiBMc0NvZGUsCgnQoi7Qm9C40YbQtdCy0L7QudCh0YfQtdGCLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogTHNOYW1lLAoJ0KIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogRG9jVmlld1R5cGVOYW1lLAoJ0J/QoNCV0JTQodCi0JDQktCb0JXQndCY0JUo0KIu0J7QsdGK0LXQutGC0KPRh9C10YLQsCkg0JrQkNCaIERvY09iamVjdFRleHQsCgnQn9Cg0JXQlNCh0KLQkNCS0JvQldCd0JjQlSjQoi7QodC/0L7RgdC+0LHQntC/0YDQtdC00LXQu9C10L3QuNGP0J/RgNC10LTQvtGB0YLQsNCy0LvRj9C10LzRi9GF0KPRgdC70YPQsykg0JrQkNCaIERvY1NlcnZpY2VNb2RlVGV4dCwKCdCiLtCb0LjRhtC10LLQvtC50KHRh9C10YIu0JLQuNC00J7QsdGK0LXQutGC0LDQo9GH0LXRgtCwLtCd0LDQuNC80LXQvdC+0LLQsNC90LjQtSDQmtCQ0JogTHNWaWV3VHlwZU5hbWUsCgnQn9Cg0JXQlNCh0KLQkNCS0JvQldCd0JjQlSjQoi7Qm9C40YbQtdCy0L7QudCh0YfQtdGCLtCe0LHRitC10LrRgtCj0YfQtdGC0LApINCa0JDQmiBMc09iamVjdFRleHQK0JjQlwoJ0JTQvtC60YPQvNC10L3Rgi7QuNC60J7RgtC60YDRi9GC0LjQtdCb0LjRhtC10LLQvtCz0L7QodGH0LXRgtCwINCa0JDQmiDQogrQk9CU0JUKCdCiLtCd0L7QvNC10YAgPSAmRG9jTm8='

$serviceQuery = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKCdCiLtCb0LjRhtC10LLQvtC50KHRh9C10YIu0JrQvtC0INCa0JDQmiBMc0NvZGUsCgnQn9Cg0JXQlNCh0KLQkNCS0JvQldCd0JjQlSjQoi7Qo9GB0LvRg9Cz0LApINCa0JDQmiBTZXJ2aWNlVGV4dArQmNCXCgnQoNC10LPQuNGB0YLRgNCh0LLQtdC00LXQvdC40Lku0LjQutCj0YHQu9GD0LPQuNCb0LjRhtC10LLRi9GF0KHRh9C10YLQvtCyINCa0JDQmiDQogrQk9CU0JUKCdCiLtCb0LjRhtC10LLQvtC50KHRh9C10YIu0JrQvtC0ID0gJkxzTm8='

$determinationQuery = Decode-Utf8Base64 '0JLQq9CR0KDQkNCi0KwKCdCiLtCb0LjRhtC10LLQvtC50KHRh9C10YIu0JrQvtC0INCa0JDQmiBMc0NvZGUsCgnQoi7QodC/0L7RgdC+0LHQntC/0YDQtdC00LXQu9C10L3QuNGP0J/RgNC10LTQvtGB0YLQsNCy0LvRj9C10LzRi9GF0KPRgdC70YPQsyDQmtCQ0JogU2VydmljZU1vZGVUZXh0CtCY0JcKCdCg0LXQs9C40YHRgtGA0KHQstC10LTQtdC90LjQuS7QuNC60J7Qv9GA0LXQtNC10LvQtdC90LjQtdCf0YDQtdC00L7RgdGC0LDQstC70Y/QtdC80YvRhdCj0YHQu9GD0LPQm9C40YbQtdCy0YvRhdCh0YfQtdGC0L7QsiDQmtCQ0Jog0KIK0JPQlNCVCgnQoi7Qm9C40YbQtdCy0L7QudCh0YfQtdGCLtCa0L7QtCA9ICZMc05v'

if ([string]::IsNullOrWhiteSpace($DocNo)) {
  throw 'DocNo is required'
}

$ctx = Connect-1CBase -Alias $Alias
$docQueryObject = New-1CQuery -Connection $ctx.Connection -Text $docQuery
$docQueryObject.SetParameter('DocNo', $DocNo)
$docTable = $docQueryObject.Execute().Unload()
$docCount = Get-TableCountSafe -Table $docTable

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# COM address diagnose')
$lines.Add('')
$lines.Add('- alias: ' + $Alias)
$lines.Add('- path: ' + $ctx.Path)
$lines.Add('- role: ' + $ctx.Role)
$lines.Add('- user: ' + $ctx.User)
$lines.Add('- doc: ' + $DocNo)
$lines.Add('- ls filter: ' + $(if ([string]::IsNullOrWhiteSpace($LsNo)) { '<empty>' } else { $LsNo }))
$lines.Add('')

if ($docCount -eq 0) {
  $lines.Add('## Result')
  $lines.Add('- document not found')
  $text = [string]::Join("`r`n", $lines)
  if (-not [string]::IsNullOrWhiteSpace($OutPath)) { Save-Utf8Text -Path $OutPath -Text $text }
  Write-Output $text
  exit 0
}

$doc = $docTable.Get(0)
$docNoValue = $doc.Get(0)
$docDate = $doc.Get(1)
$docOrgName = $doc.Get(2)
$lsCode = $doc.Get(3)
$lsName = $doc.Get(4)
$docViewTypeName = $doc.Get(5)
$docObjectText = $doc.Get(6)
$docServiceModeText = $doc.Get(7)
$lsViewTypeName = $doc.Get(8)
$lsObjectText = $doc.Get(9)

$resolvedLsNo = (To-Text $lsCode).Trim()
$serviceQueryObject = New-1CQuery -Connection $ctx.Connection -Text $serviceQuery
$serviceQueryObject.SetParameter('LsNo', $resolvedLsNo)
$serviceTable = $serviceQueryObject.Execute().Unload()
$serviceCount = Get-TableCountSafe -Table $serviceTable
$determinationTable = $null
$determinationCount = 0
$determinationError = ''

try {
  $determinationQueryObject = New-1CQuery -Connection $ctx.Connection -Text $determinationQuery
  $determinationQueryObject.SetParameter('LsNo', $resolvedLsNo)
  $determinationTable = $determinationQueryObject.Execute().Unload()
  $determinationCount = Get-TableCountSafe -Table $determinationTable
} catch {
  $determinationError = $_.Exception.Message
}

$lines.Add('## Document')
$lines.Add('- number: ' + (To-Text $docNoValue))
$lines.Add('- date: ' + (To-Text $docDate))
$lines.Add('- org: ' + (To-Text $docOrgName))
$lines.Add('- ls code: ' + (To-Text $lsCode))
$lines.Add('- ls name: ' + (To-Text $lsName))
$lines.Add('- doc view type: ' + (To-Text $docViewTypeName))
$lines.Add('- doc object: ' + (To-Text $docObjectText))
$lines.Add('- doc service mode: ' + (To-Text $docServiceModeText))
$lines.Add('')
$lines.Add('## LS card')

$lines.Add('- code: ' + (To-Text $lsCode))
$lines.Add('- name: ' + (To-Text $lsName))
$lines.Add('- ls view type: ' + (To-Text $lsViewTypeName))
$lines.Add('- ls object: ' + (To-Text $lsObjectText))

if (-not [string]::IsNullOrWhiteSpace($LsNo)) {
  if ($resolvedLsNo -ne $LsNo.Trim()) {
    $lines.Add('')
    $lines.Add('## Result')
    $lines.Add('- document found, but LS filter does not match')
    $lines.Add('- resolved ls code: ' + $resolvedLsNo)
    $text = [string]::Join("`r`n", $lines)
    if (-not [string]::IsNullOrWhiteSpace($OutPath)) { Save-Utf8Text -Path $OutPath -Text $text }
    Write-Output $text
    exit 0
  }
}

$lines.Add('')
$lines.Add('## Service register')
$lines.Add('- rows: ' + $serviceCount)
if ($serviceCount -gt 0) {
  for ($i = 0; $i -lt [Math]::Min($serviceCount, 10); $i++) {
    $row = $serviceTable.Get($i)
    $lines.Add('- service: ' + (To-Text $row.Get(1)))
  }
}

$lines.Add('')
$lines.Add('## Determination register')
$lines.Add('- rows: ' + $determinationCount)
if (-not [string]::IsNullOrWhiteSpace($determinationError)) {
  $lines.Add('- error: ' + $determinationError)
}
if ($determinationCount -gt 0) {
  for ($i = 0; $i -lt [Math]::Min($determinationCount, 10); $i++) {
    $row = $determinationTable.Get($i)
    $lines.Add('- mode: ' + (To-Text $row.Get(1)))
  }
}

$text = [string]::Join("`r`n", $lines)
if (-not [string]::IsNullOrWhiteSpace($OutPath)) { Save-Utf8Text -Path $OutPath -Text $text }
Write-Output $text
