# Expose Ollama on Windows so WSL/Docker containers can reach it via host.docker.internal.
# Run in PowerShell (Admin not required for User-level env var):
#   powershell -ExecutionPolicy Bypass -File .\scripts\configure-ollama-windows.ps1

#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$hostValue = '0.0.0.0:11434'

Write-Host "Setting OLLAMA_HOST=$hostValue for your user account..."
[Environment]::SetEnvironmentVariable('OLLAMA_HOST', $hostValue, 'User')

Write-Host ""
Write-Host "Restart Ollama:"
Write-Host "  - Quit Ollama from the system tray, then start it again from the Start menu."
Write-Host "  - Or reboot Windows."
Write-Host ""
Write-Host "Verify from PowerShell:"
Write-Host "  curl http://127.0.0.1:11434/api/tags"
Write-Host ""
Write-Host "Then from WSL re-run:  ./bootstrap.sh"
Write-Host "Containers use: http://host.docker.internal:11434"
