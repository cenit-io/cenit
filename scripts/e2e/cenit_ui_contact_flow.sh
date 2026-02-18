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
CENIT_E2E_HEADED="${CENIT_E2E_HEADED:-0}"
CENIT_E2E_CLEANUP="${CENIT_E2E_CLEANUP:-1}"
CENIT_E2E_RESET_STACK="${CENIT_E2E_RESET_STACK:-0}"
CENIT_E2E_BUILD_STACK="${CENIT_E2E_BUILD_STACK:-$CENIT_E2E_RESET_STACK}"
CENIT_E2E_RUN_ID="${CENIT_E2E_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
CENIT_E2E_DATATYPE_NAMESPACE="${CENIT_E2E_DATATYPE_NAMESPACE:-E2E_CONTACT_FLOW}"
CENIT_E2E_DATATYPE_NAME="${CENIT_E2E_DATATYPE_NAME:-Contact}"
CENIT_E2E_RECORD_NAME="${CENIT_E2E_RECORD_NAME:-John Contact E2E}"
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
    if curl -fsS -o /dev/null "$url" >/dev/null 2>&1; then
      echo "$label is ready: $url"
      return 0
    fi
    sleep "$sleep_secs"
  done
  echo "Timed out waiting for $label at $url" >&2
  return 1
}

run_pwcli_driver() {
  local stamp snapshot_file screenshot_file state_file report_file run_log_file run_output run_status

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
  if [[ "$CENIT_E2E_HEADED" == "1" ]]; then
    "$PWCLI" open "$CENIT_UI_URL" --headed >/dev/null
  else
    "$PWCLI" open "$CENIT_UI_URL" >/dev/null
  fi

  read -r -d '' CONTACT_FLOW <<'JS' || true
const uiUrl = process.env.CENIT_UI_URL;
const email = process.env.CENIT_E2E_EMAIL;
const password = process.env.CENIT_E2E_PASSWORD;
const namespaceName = process.env.CENIT_E2E_DATATYPE_NAMESPACE;
const dataTypeName = process.env.CENIT_E2E_DATATYPE_NAME;
const recordName = process.env.CENIT_E2E_RECORD_NAME;
const recordCollection = process.env.CENIT_E2E_RECORD_COLLECTION;

const escapeRegex = (value) => {
  let escaped = String(value ?? '');
  const specials = ['\\', '.', '*', '+', '?', '^', '$', '{', '}', '(', ')', '|', '[', ']'];
  specials.forEach((char) => {
    escaped = escaped.split(char).join('\\' + char);
  });
  return escaped;
};
const sectionByHeading = (regex) => page.locator('div').filter({
  has: page.getByRole('heading', { name: regex })
}).last();
const isSignIn = () => /\/users\/sign_in/.test(page.url());
const isOAuth = () => /\/oauth\/authorize/.test(page.url());

await page.goto(uiUrl, { waitUntil: 'domcontentloaded' });

if (await page.getByRole('textbox', { name: 'Email' }).isVisible().catch(() => false) || isSignIn()) {
  await page.getByRole('textbox', { name: 'Email' }).fill(email);
  await page.getByRole('textbox', { name: 'Password' }).fill(password);
  await page.getByRole('button', { name: /log in/i }).click();
  await page.waitForTimeout(1000);
}

if (isSignIn()) {
  const msg = await page.locator('body').innerText().catch(() => '');
  if (/invalid email or password/i.test(msg)) {
    throw new Error('Login failed: invalid email or password');
  }
  throw new Error('Login did not complete. Current URL: ' + page.url());
}

if (isOAuth() || await page.getByRole('button', { name: /(allow|authorize)/i }).isVisible().catch(() => false)) {
  await page.getByRole('button', { name: /(allow|authorize)/i }).first().click();
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
const recordsHeading = new RegExp('^' + escapeRegex(recordCollection));
await page.getByRole('heading', { name: recordsHeading }).last().waitFor({ timeout: 30_000 });

const recordsSection = sectionByHeading(recordsHeading);
await recordsSection.getByRole('button', { name: 'New' }).click();

const recordNewHeading = new RegExp('^' + escapeRegex(recordCollection) + ' \\| New$');
const recordNewSection = sectionByHeading(recordNewHeading);
await page.getByRole('heading', { name: recordNewHeading }).last().waitFor({ timeout: 30_000 });

await recordNewSection.getByRole('textbox', { name: 'Name' }).fill(recordName);
await recordNewSection.getByRole('button', { name: /^save$/i }).click();

await page.getByRole('heading', { name: 'Successfully created' }).last().waitFor({ timeout: 30_000 });
await page.getByRole('button', { name: 'View' }).last().click();
await page.getByRole('heading', { name: recordName }).last().waitFor({ timeout: 30_000 });
JS

  echo "Executing Contact data type + record E2E flow (pwcli driver)..."
  set +e
  run_output="$("$PWCLI" run-code "$CONTACT_FLOW" 2>&1)"
  run_status=$?
  set -e
  stamp="$(date +%Y%m%d-%H%M%S)"
  run_log_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-contact-flow-run-$stamp.log"
  printf '%s\n' "$run_output" > "$run_log_file"

  if printf '%s\n' "$run_output" | grep -Eq "SyntaxError: Unexpected token|ReferenceError: process is not defined"; then
    if has_node_playwright; then
      echo "pwcli run-code compatibility issue detected (see $run_log_file). Falling back to node-playwright driver..."
      run_node_driver
      return 0
    fi
  fi

  if [[ "$run_status" -ne 0 ]] || printf '%s\n' "$run_output" | grep -q "### Error"; then
    stamp="$(date +%Y%m%d-%H%M%S)"
    snapshot_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-contact-flow-failed-$stamp.md"
    screenshot_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-contact-flow-failed-$stamp.png"
    report_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-contact-flow-failed-$stamp.txt"
    "$PWCLI" snapshot --filename "$snapshot_file" >/dev/null || true
    "$PWCLI" screenshot --filename "$screenshot_file" --full-page >/dev/null || true
    cat > "$report_file" <<EOF
E2E Contact flow failed.
Namespace: ${CENIT_E2E_DATATYPE_NAMESPACE}
Data type: ${CENIT_E2E_DATATYPE_NAME}
Record: ${CENIT_E2E_RECORD_NAME}
Collection: ${CENIT_E2E_RECORD_COLLECTION}
Failure snapshot: ${snapshot_file}
Failure screenshot: ${screenshot_file}
Run log: ${run_log_file}
EOF
    cat "$report_file"
    exit 1
  fi

  snapshot_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-contact-flow-$stamp.md"
  screenshot_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-contact-flow-$stamp.png"
  state_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-contact-flow-auth-state-$stamp.json"
  report_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-contact-flow-$stamp.txt"

  "$PWCLI" snapshot --filename "$snapshot_file" >/dev/null
  if ! grep -Fq "$CENIT_E2E_RECORD_NAME" "$snapshot_file"; then
    screenshot_file="$CENIT_E2E_OUTPUT_DIR/cenit-ui-contact-flow-failed-$stamp.png"
    "$PWCLI" screenshot --filename "$screenshot_file" --full-page >/dev/null || true
    cat > "$report_file" <<EOF
E2E Contact flow failed verification.
Expected record heading not found in snapshot.
Namespace: ${CENIT_E2E_DATATYPE_NAMESPACE}
Data type: ${CENIT_E2E_DATATYPE_NAME}
Record: ${CENIT_E2E_RECORD_NAME}
Collection: ${CENIT_E2E_RECORD_COLLECTION}
Snapshot checked: ${snapshot_file}
Failure screenshot: ${screenshot_file}
Run log: ${run_log_file}
EOF
    cat "$report_file"
    exit 1
  fi
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
Run log: ${run_log_file}
EOF

  if [[ "$CENIT_E2E_KEEP_BROWSER" != "1" ]]; then
    "$PWCLI" close >/dev/null
  fi

  cat "$report_file"
}

run_node_driver() {
  local stamp preflight_attempt
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
  export CENIT_E2E_HEADED
  export CENIT_E2E_CLEANUP

  echo "Running auth preflight (node-playwright login driver)..."
  for preflight_attempt in 1 2 3; do
    if CENIT_E2E_TIMESTAMP="${stamp}-login-$preflight_attempt" node "$ROOT_DIR/scripts/e2e/cenit_ui_login_playwright.mjs" >/dev/null; then
      break
    fi
    if [[ "$preflight_attempt" -eq 3 ]]; then
      echo "Auth preflight failed after 3 attempts." >&2
      exit 1
    fi
    sleep 2
  done

  echo "Executing Contact data type + record E2E flow (node-playwright driver)..."
  node "$ROOT_DIR/scripts/e2e/cenit_ui_contact_flow_playwright.mjs"
}

ensure_cmd curl
mkdir -p "$CENIT_E2E_OUTPUT_DIR"

if [[ -z "${CENIT_E2E_SERVER_READY_RETRIES:-}" ]]; then
  if [[ "$CENIT_E2E_RESET_STACK" == "1" || "$CENIT_E2E_BUILD_STACK" == "1" ]]; then
    CENIT_E2E_SERVER_READY_RETRIES=180
  else
    CENIT_E2E_SERVER_READY_RETRIES=60
  fi
fi

if [[ -z "${CENIT_E2E_UI_READY_RETRIES:-}" ]]; then
  if [[ "$CENIT_E2E_RESET_STACK" == "1" || "$CENIT_E2E_BUILD_STACK" == "1" ]]; then
    CENIT_E2E_UI_READY_RETRIES=120
  else
    CENIT_E2E_UI_READY_RETRIES=60
  fi
fi

if [[ "$CENIT_E2E_AUTOSTART" == "1" ]]; then
  ensure_cmd docker
  if [[ "$CENIT_E2E_RESET_STACK" == "1" ]]; then
    echo "Resetting cenit docker stack and volumes before E2E..."
    docker compose -f "$COMPOSE_FILE" down -v --remove-orphans >/dev/null || true
  fi
  if [[ "$CENIT_E2E_BUILD_STACK" == "1" ]]; then
    echo "Starting cenit stack with image rebuild (server, ui, mongo, redis, rabbitmq)..."
    docker compose -f "$COMPOSE_FILE" up -d --build mongo_server redis rabbitmq server ui >/dev/null
  else
    echo "Starting cenit stack (server, ui, mongo, redis, rabbitmq)..."
    docker compose -f "$COMPOSE_FILE" up -d mongo_server redis rabbitmq server ui >/dev/null
  fi
fi

wait_http "$CENIT_SERVER_URL" "Cenit server" "$CENIT_E2E_SERVER_READY_RETRIES"
wait_http "$CENIT_UI_URL" "Cenit UI" "$CENIT_E2E_UI_READY_RETRIES"

driver="$CENIT_E2E_DRIVER"
if [[ "$driver" == "auto" ]]; then
  if has_node_playwright; then
    driver="node"
  elif [[ -x "$PWCLI" ]]; then
    driver="pwcli"
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
