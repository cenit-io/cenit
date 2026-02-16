#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${CENIT_COMPOSE_FILE:-$ROOT_DIR/docker-compose.yml}"

CENIT_SERVER_URL="${CENIT_SERVER_URL:-http://localhost:3000}"
CENIT_UI_URL="${CENIT_UI_URL:-http://localhost:3002}"
CENIT_E2E_EMAIL="${CENIT_E2E_EMAIL:-support@cenit.io}"
CENIT_E2E_PASSWORD="${CENIT_E2E_PASSWORD:-password}"
CENIT_E2E_AUTOSTART="${CENIT_E2E_AUTOSTART:-1}"
CENIT_PLAYWRIGHT_SESSION="${CENIT_PLAYWRIGHT_SESSION:-cenit-ui-login-e2e}"
CENIT_E2E_OUTPUT_DIR="${CENIT_E2E_OUTPUT_DIR:-$ROOT_DIR/output/playwright}"
CENIT_E2E_KEEP_BROWSER="${CENIT_E2E_KEEP_BROWSER:-0}"

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
PWCLI="${PWCLI:-$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh}"

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
    if curl -fsS -o /dev/null "$url"; then
      echo "$label is ready: $url"
      return 0
    fi
    sleep "$sleep_secs"
  done
  echo "Timed out waiting for $label at $url" >&2
  return 1
}

ensure_cmd curl
ensure_cmd docker
ensure_cmd npx

if [[ ! -x "$PWCLI" ]]; then
  echo "Playwright wrapper not found or not executable: $PWCLI" >&2
  exit 1
fi

mkdir -p "$CENIT_E2E_OUTPUT_DIR"

if [[ "$CENIT_E2E_AUTOSTART" == "1" ]]; then
  echo "Starting cenit stack (server, ui, mongo, redis, rabbitmq)..."
  docker compose -f "$COMPOSE_FILE" up -d mongo_server redis rabbitmq server ui >/dev/null
fi

wait_http "$CENIT_SERVER_URL" "Cenit server"
wait_http "$CENIT_UI_URL" "Cenit UI"

export PLAYWRIGHT_CLI_SESSION="$CENIT_PLAYWRIGHT_SESSION"
export CENIT_E2E_EMAIL
export CENIT_E2E_PASSWORD
export CENIT_UI_URL

# Clean any previous browser for this session.
"$PWCLI" close >/dev/null 2>&1 || true

echo "Opening UI and executing login+consent flow..."
"$PWCLI" open "$CENIT_UI_URL" >/dev/null

read -r -d '' LOGIN_FLOW <<'JS' || true
const uiUrl = process.env.CENIT_UI_URL;
const email = process.env.CENIT_E2E_EMAIL;
const password = process.env.CENIT_E2E_PASSWORD;

await page.goto(uiUrl, { waitUntil: 'domcontentloaded' });
await page.waitForURL(/\/users\/sign_in/, { timeout: 30_000 });

await page.getByRole('textbox', { name: 'Email' }).fill(email);
await page.getByRole('textbox', { name: 'Password' }).fill(password);
await page.getByRole('button', { name: /log in/i }).click();

await page.waitForURL(/\/oauth\/authorize/, { timeout: 30_000 });
await page.getByRole('button', { name: /allow/i }).click();

await page.waitForURL((url) => url.href.startsWith(uiUrl), { timeout: 30_000 });
await page.getByRole('heading', { name: 'Menu' }).waitFor({ timeout: 30_000 });
JS

"$PWCLI" run-code "$LOGIN_FLOW" >/dev/null

stamp="$(date +%Y%m%d-%H%M%S)"
snapshot_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-login-$stamp.md"
screenshot_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-login-$stamp.png"
state_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-auth-state-$stamp.json"

"$PWCLI" snapshot --filename "$snapshot_file" >/dev/null
"$PWCLI" screenshot --filename "$screenshot_file" --full-page >/dev/null
"$PWCLI" state-save "$state_file" >/dev/null

if [[ "$CENIT_E2E_KEEP_BROWSER" != "1" ]]; then
  "$PWCLI" close >/dev/null
fi

echo "E2E login flow completed successfully."
echo "Snapshot:   $snapshot_file"
echo "Screenshot: $screenshot_file"
echo "Auth state: $state_file"
