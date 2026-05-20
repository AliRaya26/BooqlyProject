# One-time setup so signup emails work on Flutter web (Chrome).
# Requires: firebase login (interactive), Blaze plan on booqlyapp-83777.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Set-Location $root

& (Join-Path $PSScriptRoot "sync-env.ps1")

if (-not (Test-Path "functions\.env")) {
  Write-Error "Missing functions\.env — copy functions\.env.example and set RESEND_API_KEY."
}

if (-not (Test-Path "functions\node_modules")) {
  Set-Location functions
  npm install
  Set-Location $root
}

Write-Host "Deploying sendAuthEmail + Firestore rules to booqlyapp-83777..."
npx --yes firebase-tools@13 deploy --only functions,firestore:rules --project booqlyapp-83777

Write-Host "Done. Restart the app: flutter run -d chrome"
