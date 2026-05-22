# Gmail credentials live ONLY in functions/.env (the server). They are never
# bundled into the mobile/web app. This script just makes sure that file
# exists and has the keys the Cloud Function expects.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$functionsEnv = Join-Path $root "functions\.env"
$example = Join-Path $root "functions\.env.example"

if (-not (Test-Path $functionsEnv)) {
  if (Test-Path $example) {
    Copy-Item $example $functionsEnv
    Write-Host "Created functions\.env from .env.example. Open it and fill in GMAIL_USER + GMAIL_APP_PASSWORD before deploying."
    exit 1
  }
  Write-Error "Missing functions\.env (and no .env.example to copy from)."
}

$content = Get-Content $functionsEnv -Raw
$required = @("GMAIL_USER", "GMAIL_APP_PASSWORD", "EMAIL_FROM")
$missing = @()
foreach ($name in $required) {
  if ($content -notmatch "(?m)^$name=.+") { $missing += $name }
}
if ($missing.Count -gt 0) {
  Write-Error ("functions\.env is missing: " + ($missing -join ", "))
}

if ($content -match "PASTE_16_CHAR_APP_PASSWORD_HERE") {
  Write-Error "functions\.env still has the placeholder GMAIL_APP_PASSWORD. Generate one at https://myaccount.google.com/apppasswords and paste it in."
}

Write-Host "functions\.env looks good."
