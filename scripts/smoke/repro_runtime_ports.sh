#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

REPRO_SERVER_PORT="${REPRO_SERVER_PORT:-13000}"
REPRO_UI_PORT="${REPRO_UI_PORT:-13002}"

UI_URL="${REPRO_UI_PUBLIC_URL:-http://localhost:${REPRO_UI_PORT}}"
SERVER_URL="${REPRO_SERVER_PUBLIC_URL:-http://localhost:${REPRO_SERVER_PORT}}"

CONFIG_URL="${UI_URL}/config.js"
CREDENTIALS_URL="${SERVER_URL}/app/admin/oauth2/client/credentials"
SIGN_IN_URL="${SERVER_URL}/users/sign_in"

tmp_config="$(mktemp)"
trap 'rm -f "$tmp_config"' EXIT

retry_curl() {
  local url="$1"
  local tries="${2:-40}"
  local sleep_seconds="${3:-2}"
  local i
  for ((i = 1; i <= tries; i += 1)); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$sleep_seconds"
  done
  return 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! rg -q "$pattern" "$file"; then
    echo "Expected pattern not found: $pattern" >&2
    return 1
  fi
}

echo "Runtime repro smoke checks"
echo "  UI_URL=${UI_URL}"
echo "  SERVER_URL=${SERVER_URL}"

# Guardrail: repro stack must not still publish default ports 3000/3002.
if command -v docker >/dev/null 2>&1; then
  server_ports="$(docker ps --format '{{.Names}} {{.Ports}}' | grep '^cenit-server-1 ' || true)"
  ui_ports="$(docker ps --format '{{.Names}} {{.Ports}}' | grep '^cenit-ui-1 ' || true)"
  if [[ "$server_ports" == *":3000->"* ]]; then
    echo "Repro stack is also publishing port 3000 (ambiguous host routing): $server_ports" >&2
    echo "Run: scripts/compose-repro.sh down && scripts/compose-repro.sh up -d --build --force-recreate" >&2
    exit 1
  fi
  if [[ "$ui_ports" == *":3002->"* ]]; then
    echo "Repro stack is also publishing port 3002 (ambiguous host routing): $ui_ports" >&2
    echo "Run: scripts/compose-repro.sh down && scripts/compose-repro.sh up -d --build --force-recreate" >&2
    exit 1
  fi
fi

if ! retry_curl "${CONFIG_URL}" 30 2; then
  echo "UI config endpoint is unreachable: ${CONFIG_URL}" >&2
  echo "Start stack with: ${ROOT_DIR}/scripts/compose-repro.sh up -d" >&2
  exit 1
fi

curl -fsS "${CONFIG_URL}" > "$tmp_config"

expected_server="REACT_APP_CENIT_HOST: \"${SERVER_URL}\""
expected_ui="REACT_APP_LOCALHOST: \"${UI_URL}\""

assert_contains "$tmp_config" "$expected_server"
assert_contains "$tmp_config" "$expected_ui"

if rg -q 'REACT_APP_CENIT_HOST: "http://localhost:3000"' "$tmp_config"; then
  echo "config.js still points to localhost:3000, repro override not applied." >&2
  exit 1
fi

if ! retry_curl "${SIGN_IN_URL}" 30 2; then
  echo "Backend sign-in endpoint is unreachable: ${SIGN_IN_URL}" >&2
  exit 1
fi

credentials_body="$(curl -fsS "${CREDENTIALS_URL}" || true)"
if [[ -z "$credentials_body" ]]; then
  echo "Credentials endpoint returned empty response: ${CREDENTIALS_URL}" >&2
  exit 1
fi

if ! rg -q '"client_id"|"client_token"' <<<"$credentials_body"; then
  echo "Credentials endpoint did not return expected client payload (client_id or client_token)." >&2
  echo "Response: $credentials_body" >&2
  exit 1
fi

echo "PASS: runtime config and backend endpoints match repro ports."
