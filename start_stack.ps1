# Start the local hackbot stack on Windows. Run each time you boot.
#   .\start_stack.ps1
$ErrorActionPreference = "Continue"
$Repo = $PSScriptRoot
Set-Location $Repo
New-Item -ItemType Directory -Force -Path (Join-Path $Repo "logs") | Out-Null

# load .env into process env
if (Test-Path (Join-Path $Repo ".env")) {
  Get-Content (Join-Path $Repo ".env") | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
      Set-Item -Path ("Env:" + $Matches[1]) -Value $Matches[2]
    }
  }
}
$env:PORT = "13337"

$bun = (Get-Command bun -ErrorAction SilentlyContinue).Source
if (-not $bun) { $bun = Join-Path $env:USERPROFILE ".bun\bin\bun.exe" }
$py = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $py) { $py = (Get-Command python3 -ErrorAction SilentlyContinue).Source }

function Test-Harness {
  try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:13337/api/health" -TimeoutSec 2 -UseBasicParsing
    return $r.StatusCode -eq 200
  } catch { return $false }
}

if (Test-Harness) {
  Write-Host "harness: already running"
} elseif (Test-Path $bun) {
  Start-Process -FilePath $bun -ArgumentList "run","server.ts" `
    -WorkingDirectory (Join-Path $Repo "harness") `
    -RedirectStandardOutput (Join-Path $Repo "logs\harness.log") `
    -RedirectStandardError (Join-Path $Repo "logs\harness.err.log") `
    -WindowStyle Hidden
  Start-Sleep -Seconds 3
  if (Test-Harness) { Write-Host "harness: started -> http://127.0.0.1:13337" }
  else { Write-Host "harness: FAILED (see logs\harness.log)" }
} else {
  Write-Host "harness: Bun not found"
}

$bridgeRunning = Get-CimInstance Win32_Process -Filter "Name like '%python%'" |
  Where-Object { $_.CommandLine -like '*discord_bot/bridge.py*' -or $_.CommandLine -like '*discord_bot\bridge.py*' }
if ($bridgeRunning) {
  Write-Host "discord bridge: already running"
} elseif ($py) {
  Start-Process -FilePath $py -ArgumentList "discord_bot\bridge.py" `
    -WorkingDirectory $Repo `
    -RedirectStandardOutput (Join-Path $Repo "logs\bridge.log") `
    -RedirectStandardError (Join-Path $Repo "logs\bridge.err.log") `
    -WindowStyle Hidden
  Start-Sleep -Seconds 4
  if (Select-String -Path (Join-Path $Repo "logs\bridge.log") -Pattern "Logged in as" -Quiet) {
    Write-Host "discord bridge: started"
  } else { Write-Host "discord bridge: check logs\bridge.log" }
} else {
  Write-Host "discord bridge: python not found"
}

Write-Host ""
Write-Host "Dashboard : http://127.0.0.1:13337"
Write-Host "Hunt      : python harness\scripts\orchestrate.py hunt <target> --budget 10"
Write-Host "Logs      : logs\"
