param(
  [string]$Alias = 'x17_pg2'
)

$ErrorActionPreference = 'Stop'

. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function Get-PropValue {
  param(
    [object]$Object,
    [string]$Name
  )

  try {
    return $Object.$Name
  } catch {
    return '<absent>'
  }
}

$targets = @(
  'Банковский счет для кап. ремонта',
  'Есть индивидуальный источник отопления (автономное отопление)',
  'Кол-во легковых автомобилей',
  'Количество земельных участков для полива',
  'Количество с/х животных',
  'Количество с/х животных (КРС)',
  'Количество с/х птицы (куры)'
)

$ctx = $null
try {
  $ctx = Connect-1CBase -Alias $Alias
  Write-Output ("CONNECT_OK alias=" + $ctx.Alias + " path=" + $ctx.Path)

  $conditions = @()
  for ($i = 0; $i -lt $targets.Count; $i++) {
    $conditions += ("ПВХ.Наименование = &Name{0}" -f $i)
  }

  $queryText = @"
ВЫБРАТЬ
| ПВХ.Ссылка КАК Ссылка,
| ПВХ.Наименование КАК Наименование
|ИЗ
| ПланВидовХарактеристик.икХарактеристикиОбъектовУчета КАК ПВХ
|ГДЕ
| НЕ ПВХ.ЭтоГруппа
| И ($($conditions -join " ИЛИ "))
|УПОРЯДОЧИТЬ ПО
| ПВХ.Наименование
"@

  $query = New-1CQuery -Connection $ctx.Connection -Text $queryText
  for ($i = 0; $i -lt $targets.Count; $i++) {
    $query.SetParameter(("Name{0}" -f $i), $targets[$i])
  }

  $rows = $query.Execute().Choose()
  while ($rows.Next()) {
    $obj = $rows.Reference.GetObject()
    $showObjects = Get-PropValue -Object $obj -Name 'ПоказыватьВСпискеХарактеристикОбъектов'
    $showGeneric = Get-PropValue -Object $obj -Name 'ПоказыватьВСпискеХарактеристик'
    $viewType = Get-PropValue -Object $obj -Name 'ВидОбъектаУчета'
    $isCalc = Get-PropValue -Object $obj -Name 'ЭтоВычисляемаяХарактеристика'
    Write-Output ("NAME=" + [string]$rows.Name)
    Write-Output ("  SHOW_OBJECTS=" + [string]$showObjects)
    Write-Output ("  SHOW_GENERIC=" + [string]$showGeneric)
    Write-Output ("  VIEW_TYPE=" + [string]$viewType)
    Write-Output ("  IS_CALC=" + [string]$isCalc)
  }
} finally {
  if ($null -ne $ctx) {
    $ctx.Connection = $null
    $ctx.Connector = $null
  }
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
}
