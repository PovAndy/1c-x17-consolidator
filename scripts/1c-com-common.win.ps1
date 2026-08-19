$ErrorActionPreference = 'Stop'

function Read-DotEnvMap {
  param([string]$Path)

  $map = @{}
  if (-not (Test-Path -LiteralPath $Path)) {
    return $map
  }

  $utf8 = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::ReadAllLines($Path, $utf8) | ForEach-Object {
    if ([string]::IsNullOrWhiteSpace($_)) { return }
    if ($_.TrimStart().StartsWith('#')) { return }
    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) {
      $map[$parts[0].Trim()] = $parts[1].Trim()
    }
  }

  return $map
}

function Read-BaseConfig {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Base config not found: $Path"
  }

  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $json = [System.IO.File]::ReadAllText($Path, $utf8)
  return ($json | ConvertFrom-Json)
}

function Get-BaseInfo {
  param(
    [object]$Config,
    [string]$Alias
  )

  if ([string]::IsNullOrWhiteSpace($Alias)) {
    throw 'Base alias is required'
  }

  $base = $Config.bases.PSObject.Properties[$Alias]
  if ($null -eq $base) {
    throw "Unknown base alias: $Alias"
  }

  return $base.Value
}

function Get-BaseKind {
  param([object]$Base)

  if ($null -eq $Base) {
    throw 'Base info is empty'
  }

  if ($Base.PSObject.Properties.Name -contains 'type') {
    $kind = [string]$Base.type
    if (-not [string]::IsNullOrWhiteSpace($kind)) {
      return $kind.ToLowerInvariant()
    }
  }

  return 'file'
}

function Test-ComConnector {
  try {
    $null = New-Object -ComObject V83.COMConnector
    return $true
  } catch {
    return $false
  }
}

function New-ComConnector {
  if (-not (Test-ComConnector)) {
    throw 'V83.COMConnector is not available on this machine'
  }

  return (New-Object -ComObject V83.COMConnector)
}

function Build-1CConnectionString {
  param(
    [object]$Base,
    [string]$User,
    [string]$Pwd
  )

  $kind = Get-BaseKind -Base $Base
  if ($kind -eq 'server') {
    if ([string]::IsNullOrWhiteSpace([string]$Base.server)) {
      throw 'Server base config is missing "server"'
    }
    if ([string]::IsNullOrWhiteSpace([string]$Base.ref)) {
      throw 'Server base config is missing "ref"'
    }

    return "Srvr=`"$($Base.server)`";Ref=`"$($Base.ref)`";Usr=`"$User`";Pwd=`"$Pwd`";"
  }

  if ([string]::IsNullOrWhiteSpace([string]$Base.path)) {
    throw 'File base config is missing "path"'
  }

  return "File=`"$($Base.path)`";Usr=`"$User`";Pwd=`"$Pwd`";"
}

function Connect-1CBase {
  param(
    [string]$Alias,
    [string]$ConfigPath = '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-bases.win.json',
    [string]$EnvPath = '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\.env'
  )

  $config = Read-BaseConfig -Path $ConfigPath
  $base = Get-BaseInfo -Config $config -Alias $Alias
  $envMap = Read-DotEnvMap -Path $EnvPath

  $user = $envMap['EPF_DB_USER']
  $pwd = $envMap['EPF_DB_PWD']

  if ([string]::IsNullOrWhiteSpace($user)) {
    throw 'EPF_DB_USER is empty'
  }

  $connectionString = Build-1CConnectionString -Base $base -User $user -Pwd $pwd
  $connector = New-ComConnector
  $connection = $connector.Connect($connectionString)
  $kind = Get-BaseKind -Base $base
  $location = if ($kind -eq 'server') {
    "$($base.server)\$($base.ref)"
  } else {
    $base.path
  }

  return [pscustomobject]@{
    Alias = $Alias
    Kind = $kind
    Path = $location
    Role = $base.role
    User = $user
    Connector = $connector
    Connection = $connection
  }
}

function Connect-1CFileBase {
  param(
    [string]$Alias,
    [string]$ConfigPath = '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-bases.win.json',
    [string]$EnvPath = '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\.env'
  )

  return Connect-1CBase -Alias $Alias -ConfigPath $ConfigPath -EnvPath $EnvPath
}

function New-1CQuery {
  param(
    [object]$Connection,
    [string]$Text
  )

  $query = $Connection.NewObject('Query')
  $query.Text = $Text
  return $query
}

function Convert-1CValueToString {
  param([object]$Value)

  if ($null -eq $Value) { return '<null>' }

  try {
    if ($Value -is [System.DBNull]) { return '<dbnull>' }
  } catch {
  }

  try {
    return [string]$Value
  } catch {
    return '<unprintable>'
  }
}

function Save-Utf8Text {
  param(
    [string]$Path,
    [string]$Text
  )

  $dir = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}
