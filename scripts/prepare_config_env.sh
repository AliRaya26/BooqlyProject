#!/usr/bin/env bash
# Creates assets/config.env for CI (file is gitignored locally).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p assets

if [[ -n "${GEMINI_API_KEY:-}" || -n "${GOOGLE_WEB_CLIENT_ID:-}" || -n "${RESEND_API_KEY:-}" ]]; then
  cat > assets/config.env <<EOF
GEMINI_API_KEY=${GEMINI_API_KEY:-}
GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID:-}
RESEND_API_KEY=${RESEND_API_KEY:-}
EMAIL_FROM=${EMAIL_FROM:-Booqly <onboarding@resend.dev>}
EOF
  echo "Wrote assets/config.env from environment variables."
elif [[ ! -f assets/config.env ]]; then
  cp assets/config.env.example assets/config.env
  echo "Copied assets/config.env.example → assets/config.env"
else
  echo "Using existing assets/config.env"
fi
