# Stop the local Azure TTS shim started by tts-start.ps1.
# Usage: powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.dsh\tts-stop.ps1"
$ErrorActionPreference = "Stop"

$Port = 18321
$listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $listening) {
  Write-Output "not running (nothing listens on port $Port)"
  exit 0
}
foreach ($procId in ($listening | Select-Object -ExpandProperty OwningProcess -Unique)) {
  Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
  Write-Output "stopped pid $procId"
}
Start-Sleep -Milliseconds 500
if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
  Write-Output "port $Port is still listening"
  exit 1
}
exit 0
