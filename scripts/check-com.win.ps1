try {
  $c = New-Object -ComObject V83.COMConnector
  Write-Output 'COM_OK'
} catch {
  Write-Output ('COM_FAIL: ' + $_.Exception.Message)
  exit 1
}
