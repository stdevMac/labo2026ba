#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
if [[ -n "${LABO_BUCKET:-}" ]]; then
  printf '%s\n' "$LABO_BUCKET"
  exit 0
fi
found="$(find "$HOME/Library/CloudStorage" -maxdepth 5 -type d -name labo1 2>/dev/null | head -n 1 || true)"
if [[ -n "$found" ]]; then
  printf '%s\n' "$found"
  exit 0
fi
echo "LABO_BUCKET no esta seteado. Crea labo1 en Google Drive y pega el path en .env (ver .env.example)." >&2
exit 1
