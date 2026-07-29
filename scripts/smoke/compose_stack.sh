#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UI_URL="${CENIT_UI_URL:-http://localhost:${UI_PORT:-3002}}"
SERVER_URL="${CENIT_SERVER_URL:-http://localhost:${SERVER_PORT:-3000}}"
SERVICES=(mongo_server redis rabbitmq server ui)

cd "$ROOT_DIR"

check_url() {
  local label="$1"
  local url="$2"
  local output="${3:-/dev/null}"

  if ! curl -fsS "$url" >"$output"; then
    echo "$label is not reachable at $url" >&2
    exit 1
  fi
}

for service in "${SERVICES[@]}"; do
  container_id="$(docker compose ps -q "$service")"
  if [[ -z "$container_id" ]]; then
    echo "Compose service is not running: $service" >&2
    exit 1
  fi

  status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_id")"
  if [[ "$status" != "healthy" ]]; then
    echo "Compose service is not healthy: $service ($status)" >&2
    exit 1
  fi
done

config_file="$(mktemp)"
trap 'rm -f "$config_file"' EXIT

check_url "Cenit UI" "$UI_URL/"
check_url "Cenit UI runtime config" "$UI_URL/config.js" "$config_file"
check_url "Cenit backend" "$SERVER_URL/users/sign_in"

grep -F "$UI_URL" "$config_file" >/dev/null || {
  echo "UI runtime config does not reference $UI_URL" >&2
  exit 1
}
grep -F "$SERVER_URL" "$config_file" >/dev/null || {
  echo "UI runtime config does not reference $SERVER_URL" >&2
  exit 1
}

docker compose exec -T mongo_server mongosh --quiet \
  --eval 'quit(db.adminCommand({ ping: 1 }).ok ? 0 : 1)'
docker compose exec -T redis redis-cli ping | grep -qx PONG
docker compose exec -T rabbitmq rabbitmq-diagnostics -q ping

echo "Compose stack smoke passed:"
echo "  UI: $UI_URL"
echo "  Backend: $SERVER_URL"
