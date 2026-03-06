#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "Pre-apply repro gate"
echo "  REPRO_SERVER_PORT=${REPRO_SERVER_PORT:-13000}"
echo "  REPRO_UI_PORT=${REPRO_UI_PORT:-13002}"

"$ROOT_DIR/scripts/smoke/repro_runtime_ports.sh"

ui_url="${CENIT_UI_URL:-http://localhost:${REPRO_UI_PORT:-13002}}"
CENIT_UI_URL="$ui_url" "$ROOT_DIR/scripts/smoke/cenit_ui_no_localhost_redirect.sh"

echo "PASS: pre-apply repro gate checks completed."
