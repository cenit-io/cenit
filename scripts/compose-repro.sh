#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_FILE="${CENIT_BASE_COMPOSE_FILE:-$ROOT_DIR/docker-compose.yml}"
DEV_FILE="${CENIT_DEV_COMPOSE_FILE:-$ROOT_DIR/docker-compose.dev.yml}"
REPRO_FILE="${CENIT_REPRO_COMPOSE_FILE:-$ROOT_DIR/docker-compose.repro.yml}"

REPRO_SERVER_PORT="${REPRO_SERVER_PORT:-13000}"
REPRO_UI_PORT="${REPRO_UI_PORT:-13002}"

# Force base compose interpolation to repro ports, avoiding accidental 3000/3002 publishes.
export SERVER_PORT="${SERVER_PORT:-$REPRO_SERVER_PORT}"
export UI_PORT="${UI_PORT:-$REPRO_UI_PORT}"

if [[ $# -eq 0 ]]; then
  echo "Usage: scripts/compose-repro.sh <docker compose args...>" >&2
  echo "Example: REPRO_SERVER_PORT=13000 REPRO_UI_PORT=13002 scripts/compose-repro.sh up -d" >&2
  exit 1
fi

exec docker compose -f "$BASE_FILE" -f "$DEV_FILE" -f "$REPRO_FILE" "$@"
