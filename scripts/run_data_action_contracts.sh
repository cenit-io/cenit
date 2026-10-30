#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Isolated Cenit-side checks, not the complete two-system acceptance runner.
if command -v rbenv >/dev/null 2>&1; then
  export PATH="$(rbenv root)/shims:$PATH"
fi
ruby --version
bundle check
container="cenit-data-action-contracts-$$-$RANDOM"
image='mongo@sha256:8bb4442761a63a8dda452744082cdac9644b429807eb977b42324a63cef59ca4'
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

docker run -d --rm --name "$container" -p 127.0.0.1::27017 "$image" --quiet >/dev/null
ready=0
for _attempt in {1..30}; do
  if docker exec "$container" mongosh --quiet --eval 'db.adminCommand({ping:1}).ok' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
[[ "$ready" == 1 ]] || { echo 'Disposable MongoDB failed to become ready.' >&2; exit 1; }
endpoint="$(docker port "$container" 27017/tcp)"
[[ "$endpoint" =~ ^127\.0\.0\.1:[0-9]+$ ]] || { echo 'Expected a loopback MongoDB endpoint.' >&2; exit 1; }
export RAILS_ENV=test DB_TEST_HOST="$endpoint" DB_TEST=cenit_data_action_contracts
export UNICORN_CENIT_SERVER=true SKIP_DB_INITIALIZATION=true
export CENIT_INBOX_TEST_URI="mongodb://$endpoint/cenit_data_action_inbox_contracts"

ruby test/data_action/client_test.rb
ruby test/data_action/receiver_test.rb
ruby test/data_action/mongo_inbox_test.rb
bundle exec rspec spec/integration/data_action/liquid_mapping_spec.rb spec/models/setup/delayed_message_spec.rb
