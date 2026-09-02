#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
if [[ -z "${LABO_BUCKET:-}" ]]; then
  LABO_BUCKET="$("$ROOT/scripts/resolve_bucket.sh")"
  export LABO_BUCKET
fi
export LABO_REPO="$ROOT"
