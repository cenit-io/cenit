#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_FILE="${CENIT_BASE_COMPOSE_FILE:-$ROOT_DIR/docker-compose.yml}"
DEV_FILE="${CENIT_DEV_COMPOSE_FILE:-$ROOT_DIR/docker-compose.dev.yml}"

if [[ $# -eq 0 ]]; then
  echo "Usage: scripts/compose-dev.sh <docker compose args...>" >&2
  echo "Example: scripts/compose-dev.sh up -d" >&2
  exit 1
fi

exec docker compose -f "$BASE_FILE" -f "$DEV_FILE" "$@"
