$ErrorActionPreference = 'Stop'
$key1 = Get-Item 'Registry::HKEY_CLASSES_ROOT\V83.COMConnector\CLSID'
$clsid = $key1.GetValue('')
Write-Output ('CLSID=' + $clsid)
$key2 = Get-Item ("Registry::HKEY_CLASSES_ROOT\\CLSID\\$clsid\\InprocServer32")
$dll = $key2.GetValue('')
Write-Output ('DLL=' + $dll)
