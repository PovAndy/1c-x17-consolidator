$ErrorActionPreference = 'Stop'
Start-Process -FilePath 'regsvr32.exe' -ArgumentList '/s', 'C:\Program Files\1cv8\8.3.25.1560\bin\comcntr.dll' -Wait
Write-Output 'REGSVR_DONE'
