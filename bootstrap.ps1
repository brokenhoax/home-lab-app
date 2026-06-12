# Bootstrap home-lab-app from Windows via WSL.
# Requires: Windows 11, WSL 2, Docker Engine running inside WSL.
# Usage (PowerShell):  cd C:\path\to\home-lab-app   .\bootstrap.ps1

#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

function Test-Command($Name) {
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

if (-not (Test-Command 'wsl')) {
    Write-Error @"
WSL is not available. Install WSL 2 first:
  wsl --install
See docs/windows.md
"@
}

$distro = (
    wsl -l -q 2>$null |
    Where-Object { $_ -and $_ -notmatch '^\s*$' -and $_ -notmatch '^docker-desktop' } |
    Select-Object -First 1
)
if (-not $distro) {
    Write-Error "No WSL Linux distribution found. Run: wsl --install -d Ubuntu"
}

$RepoWin = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoWsl = (wsl wslpath -a $RepoWin).Trim()
if (-not $RepoWsl) {
    Write-Error "Could not map repo path into WSL: $RepoWin"
}

Write-Host "=== Home Lab App bootstrap (Windows → WSL) ==="
Write-Host "WSL distro: $distro"
Write-Host "Repo (WSL): $RepoWsl"
Write-Host ""
Write-Host "Prerequisites: Docker Engine running in WSL ('$distro') — docker info must succeed there."
Write-Host "Ollama runs in Docker on WSL — no separate Ollama install required."
Write-Host "See docs/windows.md if this fails."
Write-Host ""

$RepoWslQuoted = $RepoWsl.Replace("'", "'\''")
$bashCmd = "cd '$RepoWslQuoted' && chmod +x bootstrap.sh 2>/dev/null; ./bootstrap.sh"
wsl -d $distro -- bash -lc $bashCmd
exit $LASTEXITCODE
