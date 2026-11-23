# Install the Hackbots control plane on Windows (agents + harness deps + .env).
# Skills themselves are installed by the upstream scripts\install.ps1.
$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
Set-Location $Repo

$agentDirs = @(
  (Join-Path $env:USERPROFILE ".claude\agents"),
  (Join-Path $env:USERPROFILE ".config\opencode\agents")
)
foreach ($d in $agentDirs) {
  New-Item -ItemType Directory -Force -Path $d | Out-Null
  Get-ChildItem (Join-Path $Repo "agents\*.md") | ForEach-Object {
    $dest = Join-Path $d $_.Name
    if (-not (Test-Path $dest)) {
      Copy-Item $_.FullName $dest
      Write-Host "copied agent $($_.Name) -> $d"
    }
  }
}

$bun = (Get-Command bun -ErrorAction SilentlyContinue).Source
if (-not $bun) { $bun = Join-Path $env:USERPROFILE ".bun\bin\bun.exe" }
if (Test-Path $bun) {
  Push-Location (Join-Path $Repo "harness")
  & $bun install
  Pop-Location
} else {
  Write-Host "NOTE: Bun not found. Install from https://bun.sh then: cd harness; bun install"
}

if (-not (Test-Path (Join-Path $Repo ".env"))) {
  Copy-Item (Join-Path $Repo ".env.example") (Join-Path $Repo ".env")
}

Write-Host ""
Write-Host "Control plane installed. Next:"
Write-Host "  1. edit .env (API keys, Discord token/IDs, webhook)"
Write-Host "  2. .\start_stack.ps1"
Write-Host "  3. python harness\scripts\orchestrate.py hunt <target> --budget 10"
