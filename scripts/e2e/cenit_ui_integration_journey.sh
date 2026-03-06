#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_COMPOSE_FILES="$ROOT_DIR/docker-compose.yml:$ROOT_DIR/docker-compose.dev.yml"
COMPOSE_FILES="${CENIT_COMPOSE_FILES:-${CENIT_COMPOSE_FILE:-$DEFAULT_COMPOSE_FILES}}"
IFS=':' read -r -a COMPOSE_FILE_LIST <<< "$COMPOSE_FILES"
COMPOSE_CMD=(docker compose)
for compose_file in "${COMPOSE_FILE_LIST[@]}"; do
  COMPOSE_CMD+=(-f "$compose_file")
done

CENIT_SERVER_URL="${CENIT_SERVER_URL:-http://localhost:3000}"
CENIT_UI_URL="${CENIT_UI_URL:-http://localhost:3002}"
CENIT_E2E_EMAIL="${CENIT_E2E_EMAIL:-support@cenit.io}"
CENIT_E2E_PASSWORD="${CENIT_E2E_PASSWORD:-password}"
CENIT_E2E_AUTOSTART="${CENIT_E2E_AUTOSTART:-1}"
CENIT_E2E_OUTPUT_DIR="${CENIT_E2E_OUTPUT_DIR:-$ROOT_DIR/output/playwright}"
CENIT_E2E_DRIVER="${CENIT_E2E_DRIVER:-node}"
CENIT_E2E_HEADED="${CENIT_E2E_HEADED:-0}"
CENIT_E2E_CLEANUP="${CENIT_E2E_CLEANUP:-1}"
CENIT_E2E_AUTH_PREFLIGHT="${CENIT_E2E_AUTH_PREFLIGHT:-0}"
CENIT_E2E_RESET_STACK="${CENIT_E2E_RESET_STACK:-1}"
CENIT_E2E_BUILD_STACK="${CENIT_E2E_BUILD_STACK:-0}"
CENIT_E2E_STEP1_ONLY="${CENIT_E2E_STEP1_ONLY:-0}"
CENIT_E2E_RUN_ID="${CENIT_E2E_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
CENIT_E2E_JOURNEY_NAMESPACE="${CENIT_E2E_JOURNEY_NAMESPACE:-E2E_INTEGRATION}"
export CENIT_E2E_JOURNEY_DATATYPE_NAME="${CENIT_E2E_JOURNEY_DATATYPE_NAME:-Lead}"
export CENIT_E2E_JOURNEY_RECORD_NAME="${CENIT_E2E_JOURNEY_RECORD_NAME:-John Lead E2E}"

ensure_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

wait_http() {
  local url="$1"
  local label="$2"
  local retries="${3:-60}"
  local sleep_secs="${4:-1}"
  local i
  for ((i = 1; i <= retries; i += 1)); do
    if curl -fsS -o /dev/null "$url" >/dev/null 2>&1; then
      echo "$label is ready: $url"
      return 0
    fi
    sleep "$sleep_secs"
  done
  echo "Timed out waiting for $label at $url" >&2
  return 1
}

run_node_driver() {
  local stamp preflight_attempt preflight_stamp preflight_state_file
  
  stamp="$(date +%Y%m%d-%H%M%S)"
  export CENIT_E2E_TIMESTAMP="$stamp"
  export CENIT_E2E_EMAIL
  export CENIT_E2E_PASSWORD
  export CENIT_UI_URL
  export CENIT_E2E_OUTPUT_DIR
  export CENIT_E2E_JOURNEY_NAMESPACE
  export CENIT_E2E_JOURNEY_DATATYPE_NAME
  export CENIT_E2E_JOURNEY_RECORD_NAME
  export CENIT_E2E_HEADED
  export CENIT_E2E_CLEANUP
  export CENIT_E2E_STEP1_ONLY

  unset CENIT_E2E_AUTH_STATE_FILE
  if [[ "$CENIT_E2E_AUTH_PREFLIGHT" == "1" ]]; then
    echo "Running auth preflight (node-playwright login driver)..."
    for preflight_attempt in 1 2 3; do
      preflight_stamp="${stamp}-login-$preflight_attempt"
      preflight_state_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-auth-state-${preflight_stamp}.json"
      echo "Auth preflight attempt $preflight_attempt/3 (stamp: $preflight_stamp)"
      if command -v timeout >/dev/null 2>&1; then
        if CENIT_E2E_TIMESTAMP="$preflight_stamp" timeout 180 node "$ROOT_DIR/scripts/e2e/cenit_ui_login_playwright.mjs"; then
          if [[ -f "$preflight_state_file" ]]; then
            export CENIT_E2E_AUTH_STATE_FILE="$preflight_state_file"
          fi
          break
        fi
      elif CENIT_E2E_TIMESTAMP="$preflight_stamp" node "$ROOT_DIR/scripts/e2e/cenit_ui_login_playwright.mjs"; then
        if [[ -f "$preflight_state_file" ]]; then
          export CENIT_E2E_AUTH_STATE_FILE="$preflight_state_file"
        fi
        break
      fi
      if [[ "$preflight_attempt" -eq 3 ]]; then
        echo "Auth preflight failed after 3 attempts." >&2
        exit 1
      fi
      sleep 2
    done
  else
    echo "Skipping auth preflight; integration driver will authenticate inline."
  fi

  echo "Executing Full Integration Journey E2E flow (node-playwright driver)..."
  node "$ROOT_DIR/scripts/e2e/cenit_ui_integration_journey_playwright.mjs"
}

ensure_cmd curl
mkdir -p "$CENIT_E2E_OUTPUT_DIR"

echo "Integration Journey wrapper (Cenit):"
echo "  CENIT_UI_URL=$CENIT_UI_URL"
echo "  CENIT_SERVER_URL=$CENIT_SERVER_URL"
echo "  CENIT_E2E_AUTOSTART=$CENIT_E2E_AUTOSTART"
echo "  CENIT_E2E_STEP1_ONLY=$CENIT_E2E_STEP1_ONLY"

if [[ "$CENIT_E2E_AUTOSTART" == "1" ]]; then
  ensure_cmd docker
  if [[ "$CENIT_E2E_RESET_STACK" == "1" ]]; then
    echo "Resetting cenit docker stack and volumes before E2E..."
    "${COMPOSE_CMD[@]}" down -v --remove-orphans >/dev/null || true
  fi
  echo "Starting cenit stack (server, ui, mongo, redis, rabbitmq)..."
  "${COMPOSE_CMD[@]}" up -d mongo_server redis rabbitmq server ui >/dev/null
else
  echo "Autostart disabled; expecting services to be running already."
fi

wait_http "$CENIT_SERVER_URL" "Cenit server" 180
wait_http "$CENIT_UI_URL" "Cenit UI" 120

run_node_driver

if [[ "$CENIT_E2E_STEP1_ONLY" == "1" ]]; then
  echo "Skipping DB verification for Step 1 only mode."
else
  "$ROOT_DIR/scripts/e2e/verify_integration_journey_db_state.sh"
fi
