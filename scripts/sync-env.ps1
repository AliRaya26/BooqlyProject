# Copies RESEND + EMAIL_FROM from assets/config.env into functions/.env
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root "assets\config.env"
$functionsEnv = Join-Path $root "functions\.env"

if (-not (Test-Path $configPath)) {
  Write-Error "Missing assets\config.env"
}

$lines = Get-Content $configPath
$out = @()
foreach ($name in @("RESEND_API_KEY", "EMAIL_FROM")) {
  $match = $lines | Where-Object { $_ -match "^$name=" } | Select-Object -First 1
  if ($match) { $out += $match }
}
if ($out.Count -eq 0) {
  Write-Error "config.env must contain RESEND_API_KEY and EMAIL_FROM"
}

Set-Content -Path $functionsEnv -Value ($out -join "`n") -Encoding utf8
Write-Host "Updated functions\.env from assets\config.env"
