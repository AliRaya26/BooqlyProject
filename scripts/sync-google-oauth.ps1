# Syncs GOOGLE_WEB_CLIENT_ID from assets/config.env into web/index.html meta tag.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root "assets\config.env"
$indexPath = Join-Path $root "web\index.html"

if (-not (Test-Path $configPath)) {
  Write-Error "Missing assets\config.env"
}

$line = Get-Content $configPath | Where-Object { $_ -match '^GOOGLE_WEB_CLIENT_ID=' } | Select-Object -First 1
if (-not $line) {
  Write-Error "config.env must contain GOOGLE_WEB_CLIENT_ID=..."
}

$clientId = ($line -split '=', 2)[1].Trim()
if ([string]::IsNullOrWhiteSpace($clientId)) {
  Write-Error "GOOGLE_WEB_CLIENT_ID is empty in config.env"
}

if ($clientId -notmatch '^87414724762-') {
  Write-Warning "Client ID should start with 87414724762- (booqlyapp-83777). Current: $($clientId.Substring(0, [Math]::Min(30, $clientId.Length)))..."
}

$html = Get-Content $indexPath -Raw
$pattern = '(<meta name="google-signin-client_id" content=")[^"]*(">)'
$replacement = "`${1}$clientId`${2}"
if ($html -notmatch $pattern) {
  Write-Error "google-signin-client_id meta tag not found in web/index.html"
}

$newHtml = [regex]::Replace($html, $pattern, $replacement)
Set-Content -Path $indexPath -Value $newHtml -Encoding utf8 -NoNewline
Write-Host "Synced web/index.html meta tag with GOOGLE_WEB_CLIENT_ID from config.env"
Write-Host "Client: $($clientId.Substring(0, [Math]::Min(40, $clientId.Length)))..."
