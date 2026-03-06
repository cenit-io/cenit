#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js is required to run this smoke test." >&2
  exit 1
fi

if ! node -e "require.resolve('playwright')" >/dev/null 2>&1; then
  echo "The 'playwright' package is required for this smoke test." >&2
  echo "Install it with: npm install --no-save playwright@1.52.0" >&2
  exit 1
fi

node "$ROOT_DIR/scripts/smoke/cenit_ui_no_localhost_redirect_playwright.mjs"
