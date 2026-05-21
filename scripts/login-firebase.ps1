# Log in to Firebase (opens browser). Use npx so you do not need firebase installed globally.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "Opening browser for Firebase login..."
npx --yes firebase-tools@13 login

Write-Host ""
Write-Host "Checking login..."
npx --yes firebase-tools@13 login:list
