# Run Booqly on Chrome with a fixed localhost port so Google OAuth origins match.
# Add the origins below once in Google Cloud → Credentials → Web client:
#   http://localhost:54141
#   http://127.0.0.1:54141

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

& "$PSScriptRoot\sync-google-oauth.ps1"
flutter run -d chrome --web-hostname=localhost --web-port=54141
