#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_FILE="${CENIT_BASE_COMPOSE_FILE:-$ROOT_DIR/docker-compose.yml}"
PROD_FILE="${CENIT_PROD_COMPOSE_FILE:-$ROOT_DIR/docker-compose.prod.yml}"

if [[ $# -eq 0 ]]; then
  echo "Usage: scripts/compose-prod.sh <docker compose args...>" >&2
  echo "Example: scripts/compose-prod.sh up -d" >&2
  exit 1
fi

exec docker compose -f "$BASE_FILE" -f "$PROD_FILE" "$@"
