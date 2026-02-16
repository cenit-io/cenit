#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${CENIT_COMPOSE_FILE:-$ROOT_DIR/docker-compose.yml}"

CENIT_SERVER_URL="${CENIT_SERVER_URL:-http://localhost:3000}"
CENIT_UI_URL="${CENIT_UI_URL:-http://localhost:3002}"
CENIT_E2E_EMAIL="${CENIT_E2E_EMAIL:-support@cenit.io}"
CENIT_E2E_PASSWORD="${CENIT_E2E_PASSWORD:-password}"
CENIT_E2E_AUTOSTART="${CENIT_E2E_AUTOSTART:-1}"
CENIT_E2E_OUTPUT_DIR="${CENIT_E2E_OUTPUT_DIR:-$ROOT_DIR/output/playwright}"
CENIT_E2E_HEADED="${CENIT_E2E_HEADED:-0}"
CENIT_E2E_CLEANUP="${CENIT_E2E_CLEANUP:-1}"
CENIT_E2E_JOURNEY_NAMESPACE="${CENIT_E2E_JOURNEY_NAMESPACE:-E2E_USER_JOURNEY}"
CENIT_E2E_JOURNEY_DATATYPE_NAME="${CENIT_E2E_JOURNEY_DATATYPE_NAME:-Contact}"
CENIT_E2E_JOURNEY_RECORD_ONE="${CENIT_E2E_JOURNEY_RECORD_ONE:-John Journey E2E}"
CENIT_E2E_JOURNEY_RECORD_TWO="${CENIT_E2E_JOURNEY_RECORD_TWO:-Jane Journey E2E}"
CENIT_E2E_JOURNEY_RECORD_COLLECTION="${CENIT_E2E_JOURNEY_RECORD_COLLECTION:-${CENIT_E2E_JOURNEY_DATATYPE_NAME}s}"

ensure_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

has_node_playwright() {
  command -v node >/dev/null 2>&1 && node -e "require.resolve('playwright')" >/dev/null 2>&1
}

wait_http() {
  local url="$1"
  local label="$2"
  local retries="${3:-60}"
  local sleep_secs="${4:-1}"
  local i
  for ((i = 1; i <= retries; i += 1)); do
    if curl -fsS -o /dev/null "$url"; then
      echo "$label is ready: $url"
      return 0
    fi
    sleep "$sleep_secs"
  done
  echo "Timed out waiting for $label at $url" >&2
  return 1
}

run_node_driver() {
  local stamp
  if ! has_node_playwright; then
    echo "Node Playwright driver requires the 'playwright' package in the cenit repo." >&2
    echo "Install it with: npm install --no-save playwright@1.52.0" >&2
    exit 1
  fi

  stamp="$(date +%Y%m%d-%H%M%S)"
  export CENIT_E2E_TIMESTAMP="$stamp"
  export CENIT_E2E_EMAIL
  export CENIT_E2E_PASSWORD
  export CENIT_SERVER_URL
  export CENIT_UI_URL
  export CENIT_E2E_OUTPUT_DIR
  export CENIT_E2E_HEADED
  export CENIT_E2E_CLEANUP
  export CENIT_E2E_JOURNEY_NAMESPACE
  export CENIT_E2E_JOURNEY_DATATYPE_NAME
  export CENIT_E2E_JOURNEY_RECORD_ONE
  export CENIT_E2E_JOURNEY_RECORD_TWO
  export CENIT_E2E_JOURNEY_RECORD_COLLECTION

  echo "Executing UI user journey E2E flow (node-playwright driver)..."
  node "$ROOT_DIR/scripts/e2e/cenit_ui_user_journey_playwright.mjs"
}

ensure_cmd curl
mkdir -p "$CENIT_E2E_OUTPUT_DIR"

if [[ "$CENIT_E2E_AUTOSTART" == "1" ]]; then
  ensure_cmd docker
  echo "Starting cenit stack (server, ui, mongo, redis, rabbitmq)..."
  docker compose -f "$COMPOSE_FILE" up -d mongo_server redis rabbitmq server ui >/dev/null
fi

wait_http "$CENIT_SERVER_URL" "Cenit server"
wait_http "$CENIT_UI_URL" "Cenit UI"

run_node_driver
