# Deploy email Cloud Functions (signup + password reset).
# Run login-firebase.ps1 first if you are not logged in.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Set-Location $root

& (Join-Path $PSScriptRoot "sync-env.ps1")

if (-not (Test-Path "functions\.env")) {
  Write-Error "Missing functions\.env - copy functions\.env.example and set GMAIL_USER + GMAIL_APP_PASSWORD."
}

if (-not (Test-Path "functions\node_modules")) {
  Set-Location functions
  npm install
  Set-Location $root
}

$loginList = npx --yes firebase-tools@13 login:list 2>&1 | Out-String
if ($loginList -match "No authorized accounts") {
  Write-Host ""
  Write-Host "ERROR: Not logged in to Firebase."
  Write-Host "Run this first:  .\scripts\login-firebase.ps1"
  Write-Host ""
  exit 1
}

Write-Host "Deploying sendAuthEmail, sendPasswordResetEmail, sendReadingNudges + Firestore rules to booqlyapp-83777..."
$deployOutput = npx --yes firebase-tools@13 deploy --only functions,firestore:rules --project booqlyapp-83777 2>&1 | Out-String
Write-Host $deployOutput
if ($LASTEXITCODE -ne 0) {
  if ($deployOutput -match "Blaze" -or
      $deployOutput -match "Billing account .* is not open" -or
      $deployOutput -match "billing-disabled") {
    Write-Host ""
    Write-Host "Cloud Functions require the Blaze (pay-as-you-go) plan."
    Write-Host "Upgrade (free tier still applies for low usage):"
    Write-Host "  https://console.firebase.google.com/project/booqlyapp-83777/usage/details"
    Write-Host "After upgrading, re-run: .\scripts\deploy-email.ps1"
    Write-Host ""
    Write-Host "Until then, forgot-password uses Firebase's built-in email (check spam)."
    Write-Host "Free-time nudges still create local notifications, but server push/email need Blaze."
  }
  exit 1
}

Write-Host ""
Write-Host "Done. Restart the app (e.g. flutter run)."
