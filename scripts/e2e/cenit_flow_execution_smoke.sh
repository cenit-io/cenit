#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${CENIT_COMPOSE_FILE:-$ROOT_DIR/docker-compose.yml}"

CENIT_SERVER_URL="${CENIT_SERVER_URL:-http://localhost:3000}"
CENIT_E2E_AUTOSTART="${CENIT_E2E_AUTOSTART:-1}"
CENIT_E2E_OUTPUT_DIR="${CENIT_E2E_OUTPUT_DIR:-$ROOT_DIR/output/playwright}"
CENIT_E2E_TIMESTAMP="${CENIT_E2E_TIMESTAMP:-$(date +%Y%m%d%H%M%S)}"
CENIT_E2E_CLEANUP="${CENIT_E2E_CLEANUP:-1}"
CENIT_E2E_EMAIL="${CENIT_E2E_EMAIL:-support@cenit.io}"

CENIT_E2E_FLOW_NAMESPACE="${CENIT_E2E_FLOW_NAMESPACE:-E2E_FLOW_EXECUTION}"
CENIT_E2E_FLOW_DATATYPE_NAME="${CENIT_E2E_FLOW_DATATYPE_NAME:-Contact}"
CENIT_E2E_FLOW_TRANSLATOR_NAME="${CENIT_E2E_FLOW_TRANSLATOR_NAME:-ContactNameUpdater}"
CENIT_E2E_FLOW_NAME="${CENIT_E2E_FLOW_NAME:-ContactNameFlow}"
CENIT_E2E_FLOW_RECORD_NAME="${CENIT_E2E_FLOW_RECORD_NAME:-John Flow E2E}"
CENIT_E2E_FLOW_SUFFIX="${CENIT_E2E_FLOW_SUFFIX:-FLOW-$CENIT_E2E_TIMESTAMP}"
CENIT_E2E_FLOW_TIMEOUT="${CENIT_E2E_FLOW_TIMEOUT:-120}"
CENIT_E2E_FLOW_POLL_SECONDS="${CENIT_E2E_FLOW_POLL_SECONDS:-1}"

CENIT_RABBIT_USER="${CENIT_RABBIT_USER:-cenit_rabbit}"
CENIT_RABBIT_PASSWORD="${CENIT_RABBIT_PASSWORD:-cenit_rabbit}"
CENIT_RABBIT_VHOST="${CENIT_RABBIT_VHOST:-cenit_rabbit_vhost}"
CENIT_RABBIT_QUEUE="${CENIT_RABBIT_QUEUE:-cenit}"
CENIT_RABBIT_API_URL="${CENIT_RABBIT_API_URL:-http://localhost:15672/api/queues/$CENIT_RABBIT_VHOST/$CENIT_RABBIT_QUEUE}"

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

wait_rabbit_queue_api() {
  local retries="${1:-60}"
  local sleep_secs="${2:-1}"
  local i
  for ((i = 1; i <= retries; i += 1)); do
    if curl -fsS -u "$CENIT_RABBIT_USER:$CENIT_RABBIT_PASSWORD" -o /dev/null "$CENIT_RABBIT_API_URL"; then
      echo "RabbitMQ queue API is ready: $CENIT_RABBIT_API_URL"
      return 0
    fi
    sleep "$sleep_secs"
  done
  echo "Timed out waiting for RabbitMQ queue API at $CENIT_RABBIT_API_URL" >&2
  return 1
}

rabbit_metric() {
  local key="$1"
  local payload
  payload="$(curl -fsS -u "$CENIT_RABBIT_USER:$CENIT_RABBIT_PASSWORD" "$CENIT_RABBIT_API_URL")"
  RABBIT_JSON="$payload" RABBIT_KEY="$key" ruby -rjson -e 'data = JSON.parse(ENV.fetch("RABBIT_JSON")); value = ENV.fetch("RABBIT_KEY").split(".").inject(data) { |memo, token| memo.is_a?(Hash) ? memo[token] : nil }; print((value || 0).to_i)'
}

wait_metric_increase() {
  local key="$1"
  local before="$2"
  local retries="${3:-20}"
  local sleep_secs="${4:-1}"
  local current="$before"
  local i
  for ((i = 1; i <= retries; i += 1)); do
    current="$(rabbit_metric "$key")"
    if (( current > before )); then
      echo "$current"
      return 0
    fi
    sleep "$sleep_secs"
  done
  echo "$current"
  return 1
}

ensure_cmd curl
ensure_cmd docker
ensure_cmd ruby
mkdir -p "$CENIT_E2E_OUTPUT_DIR"

if [[ "$CENIT_E2E_AUTOSTART" == "1" ]]; then
  echo "Starting cenit stack (server, ui, mongo, redis, rabbitmq)..."
  docker compose -f "$COMPOSE_FILE" up -d mongo_server redis rabbitmq server ui >/dev/null
fi

wait_http "$CENIT_SERVER_URL" "Cenit server"
wait_rabbit_queue_api

publish_before="$(rabbit_metric "message_stats.publish")"
ack_before="$(rabbit_metric "message_stats.ack")"

runner_log_file="$CENIT_E2E_OUTPUT_DIR/cenit-flow-execution-smoke-runner-$CENIT_E2E_TIMESTAMP.log"
report_file="$CENIT_E2E_OUTPUT_DIR/cenit-flow-execution-smoke-$CENIT_E2E_TIMESTAMP.txt"

echo "Executing Flow + RabbitMQ E2E smoke..."
set -o pipefail
docker compose -f "$COMPOSE_FILE" exec -T \
  -e CENIT_E2E_TIMESTAMP="$CENIT_E2E_TIMESTAMP" \
  -e CENIT_E2E_EMAIL="$CENIT_E2E_EMAIL" \
  -e CENIT_E2E_CLEANUP="$CENIT_E2E_CLEANUP" \
  -e CENIT_E2E_FLOW_NAMESPACE="$CENIT_E2E_FLOW_NAMESPACE" \
  -e CENIT_E2E_FLOW_DATATYPE_NAME="$CENIT_E2E_FLOW_DATATYPE_NAME" \
  -e CENIT_E2E_FLOW_TRANSLATOR_NAME="$CENIT_E2E_FLOW_TRANSLATOR_NAME" \
  -e CENIT_E2E_FLOW_NAME="$CENIT_E2E_FLOW_NAME" \
  -e CENIT_E2E_FLOW_RECORD_NAME="$CENIT_E2E_FLOW_RECORD_NAME" \
  -e CENIT_E2E_FLOW_SUFFIX="$CENIT_E2E_FLOW_SUFFIX" \
  -e CENIT_E2E_FLOW_TIMEOUT="$CENIT_E2E_FLOW_TIMEOUT" \
  -e CENIT_E2E_FLOW_POLL_SECONDS="$CENIT_E2E_FLOW_POLL_SECONDS" \
  server bundle exec rails runner - < "$ROOT_DIR/scripts/e2e/cenit_flow_execution_smoke_runner.rb" | tee "$runner_log_file"

publish_after="$(wait_metric_increase "message_stats.publish" "$publish_before" 20 1)" || {
  echo "RabbitMQ publish counter did not increase (before=$publish_before, after=$publish_after)" >&2
  exit 1
}

ack_after="$(wait_metric_increase "message_stats.ack" "$ack_before" 20 1)" || {
  echo "RabbitMQ ack counter did not increase (before=$ack_before, after=$ack_after)" >&2
  exit 1
}

cat > "$report_file" <<EOF
E2E Flow + RabbitMQ smoke completed successfully.
Server URL: $CENIT_SERVER_URL
Namespace: $CENIT_E2E_FLOW_NAMESPACE
Data type: $CENIT_E2E_FLOW_DATATYPE_NAME
Translator: $CENIT_E2E_FLOW_TRANSLATOR_NAME
Flow: $CENIT_E2E_FLOW_NAME
Record name: $CENIT_E2E_FLOW_RECORD_NAME
Cleanup: $CENIT_E2E_CLEANUP
Rabbit queue API: $CENIT_RABBIT_API_URL
Rabbit publish count before/after: $publish_before -> $publish_after
Rabbit ack count before/after: $ack_before -> $ack_after
Runner log: $runner_log_file
EOF

cat "$report_file"
