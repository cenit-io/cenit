#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${CENIT_COMPOSE_FILE:-$ROOT_DIR/docker-compose.yml}"

CENIT_SERVER_URL="${CENIT_SERVER_URL:-http://localhost:3000}"
CENIT_UI_URL="${CENIT_UI_URL:-http://localhost:3002}"
CENIT_E2E_EMAIL="${CENIT_E2E_EMAIL:-support@cenit.io}"
CENIT_E2E_PASSWORD="${CENIT_E2E_PASSWORD:-password}"
CENIT_E2E_AUTOSTART="${CENIT_E2E_AUTOSTART:-1}"
CENIT_PLAYWRIGHT_SESSION="${CENIT_PLAYWRIGHT_SESSION:-cuicf}"
CENIT_E2E_OUTPUT_DIR="${CENIT_E2E_OUTPUT_DIR:-$ROOT_DIR/output/playwright}"
CENIT_E2E_KEEP_BROWSER="${CENIT_E2E_KEEP_BROWSER:-0}"
CENIT_E2E_DRIVER="${CENIT_E2E_DRIVER:-auto}"
CENIT_E2E_RUN_ID="${CENIT_E2E_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
CENIT_E2E_DATATYPE_NAMESPACE="${CENIT_E2E_DATATYPE_NAMESPACE:-E2E_${CENIT_E2E_RUN_ID//[-:]/}}"
CENIT_E2E_DATATYPE_NAME="${CENIT_E2E_DATATYPE_NAME:-Contact}"
CENIT_E2E_RECORD_NAME="${CENIT_E2E_RECORD_NAME:-John Contact ${CENIT_E2E_RUN_ID}}"
CENIT_E2E_RECORD_COLLECTION="${CENIT_E2E_RECORD_COLLECTION:-${CENIT_E2E_DATATYPE_NAME}s}"

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
PWCLI="${PWCLI:-$CODEX_HOME/skills/playwright/scripts/playwright_cli.sh}"

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

run_pwcli_driver() {
  local stamp snapshot_file screenshot_file state_file report_file

  ensure_cmd npx
  if [[ ! -x "$PWCLI" ]]; then
    echo "Playwright wrapper not found or not executable: $PWCLI" >&2
    exit 1
  fi

  export PLAYWRIGHT_CLI_SESSION="$CENIT_PLAYWRIGHT_SESSION"
  export CENIT_UI_URL
  export CENIT_E2E_EMAIL
  export CENIT_E2E_PASSWORD
  export CENIT_E2E_DATATYPE_NAMESPACE
  export CENIT_E2E_DATATYPE_NAME
  export CENIT_E2E_RECORD_NAME
  export CENIT_E2E_RECORD_COLLECTION

  "$PWCLI" close >/dev/null 2>&1 || true
  "$PWCLI" open "$CENIT_UI_URL" >/dev/null

  read -r -d '' CONTACT_FLOW <<'JS' || true
const uiUrl = process.env.CENIT_UI_URL;
const email = process.env.CENIT_E2E_EMAIL;
const password = process.env.CENIT_E2E_PASSWORD;
const namespaceName = process.env.CENIT_E2E_DATATYPE_NAMESPACE;
const dataTypeName = process.env.CENIT_E2E_DATATYPE_NAME;
const recordName = process.env.CENIT_E2E_RECORD_NAME;
const recordCollection = process.env.CENIT_E2E_RECORD_COLLECTION;

const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const sectionByHeading = (regex) => page.locator('div').filter({
  has: page.getByRole('heading', { name: regex })
}).last();

await page.goto(uiUrl, { waitUntil: 'domcontentloaded' });

if (await page.getByRole('textbox', { name: 'Email' }).isVisible().catch(() => false)) {
  await page.getByRole('textbox', { name: 'Email' }).fill(email);
  await page.getByRole('textbox', { name: 'Password' }).fill(password);
  await page.getByRole('button', { name: /log in/i }).click();
}

if (await page.getByRole('button', { name: /allow/i }).isVisible().catch(() => false)) {
  await page.getByRole('button', { name: /allow/i }).click();
}

await page.waitForURL((url) => url.href.startsWith(uiUrl), { timeout: 30_000 }).catch(() => null);
await page.getByRole('heading', { name: 'Menu' }).waitFor({ timeout: 30_000 });

await page.getByRole('button', { name: 'Document Types' }).first().click();
await page.getByRole('heading', { name: /^Document Types/ }).last().waitFor({ timeout: 30_000 });

const docTypesSection = sectionByHeading(/^Document Types/);
await docTypesSection.getByRole('button', { name: 'New' }).click();

await page.getByRole('textbox', { name: 'Namespace' }).fill(namespaceName);
await page.getByRole('textbox', { name: 'Name', exact: true }).fill(dataTypeName);
await page.getByRole('button', { name: /^save$/i }).first().click();

await page.getByRole('heading', { name: 'Successfully created' }).last().waitFor({ timeout: 30_000 });
await page.getByRole('button', { name: 'View' }).last().click();

await page.getByRole('button', { name: 'Records' }).first().click();
const recordsHeading = new RegExp(`^${escapeRegex(recordCollection)}`);
await page.getByRole('heading', { name: recordsHeading }).last().waitFor({ timeout: 30_000 });

const recordsSection = sectionByHeading(recordsHeading);
await recordsSection.getByRole('button', { name: 'New' }).click();

const recordNewHeading = new RegExp(`^${escapeRegex(recordCollection)} \\| New$`);
const recordNewSection = sectionByHeading(recordNewHeading);
await page.getByRole('heading', { name: recordNewHeading }).last().waitFor({ timeout: 30_000 });

await recordNewSection.getByRole('textbox', { name: 'Name' }).fill(recordName);
await recordNewSection.getByRole('button', { name: /^save$/i }).click();

await page.getByRole('heading', { name: 'Successfully created' }).last().waitFor({ timeout: 30_000 });
await page.getByRole('button', { name: 'View' }).last().click();
await page.getByRole('heading', { name: recordName }).last().waitFor({ timeout: 30_000 });
JS

  echo "Executing Contact data type + record E2E flow (pwcli driver)..."
  "$PWCLI" run-code "$CONTACT_FLOW" >/dev/null

  stamp="$(date +%Y%m%d-%H%M%S)"
  snapshot_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-contact-flow-$stamp.md"
  screenshot_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-contact-flow-$stamp.png"
  state_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-contact-flow-auth-state-$stamp.json"
  report_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-contact-flow-$stamp.txt"

  "$PWCLI" snapshot --filename "$snapshot_file" >/dev/null
  "$PWCLI" screenshot --filename "$screenshot_file" --full-page >/dev/null
  "$PWCLI" state-save "$state_file" >/dev/null

  cat > "$report_file" <<EOF
E2E Contact flow completed successfully.
Namespace: ${CENIT_E2E_DATATYPE_NAMESPACE}
Data type: ${CENIT_E2E_DATATYPE_NAME}
Record: ${CENIT_E2E_RECORD_NAME}
Collection: ${CENIT_E2E_RECORD_COLLECTION}
Snapshot: ${snapshot_file}
Screenshot: ${screenshot_file}
Auth state: ${state_file}
EOF

  if [[ "$CENIT_E2E_KEEP_BROWSER" != "1" ]]; then
    "$PWCLI" close >/dev/null
  fi

  cat "$report_file"
}

run_node_driver() {
  local stamp
  if ! has_node_playwright; then
    echo "Node Playwright driver requested but 'playwright' package is not installed." >&2
    echo "Install it with: npm install --no-save playwright@1.52.0" >&2
    exit 1
  fi

  stamp="$(date +%Y%m%d-%H%M%S)"
  export CENIT_E2E_TIMESTAMP="$stamp"
  export CENIT_E2E_EMAIL
  export CENIT_E2E_PASSWORD
  export CENIT_UI_URL
  export CENIT_E2E_OUTPUT_DIR
  export CENIT_E2E_DATATYPE_NAMESPACE
  export CENIT_E2E_DATATYPE_NAME
  export CENIT_E2E_RECORD_NAME
  export CENIT_E2E_RECORD_COLLECTION

  echo "Executing Contact data type + record E2E flow (node-playwright driver)..."
  node "$ROOT_DIR/scripts/e2e/cenit_ui_contact_flow_playwright.mjs"
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

driver="$CENIT_E2E_DRIVER"
if [[ "$driver" == "auto" ]]; then
  if [[ -x "$PWCLI" ]]; then
    driver="pwcli"
  elif has_node_playwright; then
    driver="node"
  else
    echo "Unable to select an E2E driver." >&2
    echo "Expected either PWCLI at $PWCLI or a local Node 'playwright' package." >&2
    exit 1
  fi
fi

case "$driver" in
  pwcli)
    run_pwcli_driver
    ;;
  node)
    run_node_driver
    ;;
  *)
    echo "Invalid CENIT_E2E_DRIVER='$driver'. Use: auto | pwcli | node" >&2
    exit 1
    ;;
esac
