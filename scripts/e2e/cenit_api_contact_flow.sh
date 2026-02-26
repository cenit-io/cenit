#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init -)"
fi

echo "Running Cenit API contact-flow precheck..."
RABBITMQ_BIGWIG_TX_URL="${RABBITMQ_BIGWIG_TX_URL:-amqp://cenit_rabbit:cenit_rabbit@127.0.0.1:5672/cenit_rabbit_vhost}" \
bundle exec rake api:v3:contact_flow

