param(
  [string]$Alias = 'x2'
)

$ErrorActionPreference = 'Stop'
. '\\wsl.localhost\Ubuntu\{PROJECT_ROOT}\scripts\1c-com-common.win.ps1'

function D([string]$Value) {
  return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}

function G([object]$Object, [string]$Name) {
  return $Object.GetType().InvokeMember(
    $Name,
    [System.Reflection.BindingFlags]::GetProperty,
    $null,
    $Object,
    @()
  )
}

$catalogName = D('0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LA=')
$queryText = D('0JLQq9CR0KDQkNCi0KwgJlJlZiA9INCX0J3QkNCn0JXQndCY0JUo0KHQv9GA0LDQstC+0YfQvdC40Lou0LjQutCS0LjQtNGL0J7QsdGK0LXQutGC0L7QstCj0YfQtdGC0LAu0JbQuNC70YvQtdCf0L7QvNC10YnQtdC90LjRjykg0JrQkNCaIElzUHJlZGVm')
$ctx = Connect-1CFileBase -Alias $Alias
$catalogs = G $ctx.Connection 'Catalogs'
$manager = G $catalogs $catalogName
$ref = $manager.FindByCode('000000001')
$query = New-1CQuery -Connection $ctx.Connection -Text $queryText
$query.SetParameter('Ref', $ref)
$table = $query.Execute().Unload()
$row = $table.Get(0)

Write-Output ('Alias=' + $Alias + '; IsPredef=' + [string]$row.Get(0) + '; Ref=' + [string]$ref)
