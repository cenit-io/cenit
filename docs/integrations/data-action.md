# Local data-action integration

## Goal and ownership

The active slice proves a real local order journey through Cenit. Data-action owns
business records, authorization, mutations, queries and committed revisions. Cenit
owns integration configuration, durable execution state, transformation and external
effects. This is local qualification; no deployment or production readiness claim.

The data-action review base is [PR #4](https://github.com/ebanux/data-action/pull/4),
which consolidates the operator console onto the still-open foundation PR #1.
Do not treat a merged stacked PR as a merge into master.

## Increment 1: public HTTP client

`Cenit::DataAction::Client` uses only `/api/integration/v1`. Supply a trusted
workspace, optional integration profile, HTTPS origin and a callable credential
provider. The provider is called on every request so rotation takes effect without
reconstructing the client. Keep credentials outside persisted flow definitions and
logs. Local HTTP requires explicit `allow_local: true` and a loopback or Docker host
origin. This opt-in is for the disposable runner only.

An invocation carries an application intent's stable idempotency key. An uncertain
POST result raises `TransportError` and never triggers an automatic retry. Reconcile
or retry the identical intent with the same key. Current authority is checked by
data-action. Redirects are rejected; credentials are never forwarded to another
origin. Exact revision queries carry both record identity and revision. Event
acknowledgments carry the delivery fencing token.

Run the isolated contract tests with `ruby test/data_action/client_test.rb`.
They also pass on the project's Ruby 3.2.2 runtime using the existing image and an
identical Gemfile.lock. These tests do not yet prove a running Cenit integration.

## Increment 2: durable acceptance and actual Cenit transformation

`Receiver` validates the pinned workspace, environment, object type, event version
and subject before querying the exact committed revision. It verifies the returned
record identity, type, workspace and revision. `MongoInbox` stores receipt and
pending work together with journaled majority acknowledgment. A deterministic
primary key deduplicates by trusted Cenit account, integration profile, workspace
and event. Repeated acceptance compares immutable references and digests, and
never resets existing work. The delivery fence belongs to data-action; acknowledgment
happens only after the local insert succeeds. An uncertain acknowledgment leaves
accepted work intact for a later delivery attempt.

`Setup::DataActionReceipt` derives the account from Cenit's current tenant context;
it exposes no built-in business DataType. The inbox stores bounded scalar references
and fingerprints, not an order body. `LiquidMapping` uses an actual persisted Cenit
LiquidTemplate without a source DataType, checks its code digest, and calls the
existing template interface with a detached `Document`. This document supports
`to_hash` and preserves declared business fields including `id`; it has no ORM
query or persistence methods.

Run `scripts/run_data_action_contracts.sh` with Docker, the project's Ruby 3.2.2
and installed bundle. It starts its own pinned MongoDB on an ephemeral loopback
port, tests public-client behavior, failure before acknowledgment, concurrent
receipt deduplication, reconnect recovery, payload exclusion and actual Rails
transformation, then removes only its own container. It does not prove a full
Cenit/data-action journey yet. Existing Mongoid delayed-message regressions exposed
a prior count-versus-boolean purge result; the prerequisite fix restores their
specified boolean contract without adding Redis to this local runner.

## Increment 3: fenced work and real local delivery

`MongoWork` leases each accepted work item atomically for 120 seconds using the
MongoDB server clock. Renew, completion and failure require the active fence;
expired workers cannot modify a newer claim. Failure uses bounded backoff and an
eight-attempt budget. Repeated process failure also exhausts that budget. Replay
requires a trusted operator and a nonempty review reason, preserves event/effect
identity and appends review evidence without erasing earlier attempt history.

`Worker` re-queries the exact immutable revision and checks its identity and data
fingerprint before transformation. It checks the pinned mapping version/code and
connector fingerprint, renews its work lease before delivery, and queries the sink
by stable effect key before sending. A verified receipt must match both that key
and the SHA-256 digest of the exact transformed bytes. Delivery retries are wholly
independent of the earlier event acknowledgment. Storage failure or a lost HTTP
response can leave an uncertain result; recovery reconciles rather than generating
a new effect key.

`CenitConnector` uses persisted real Cenit Connection and PlainWebhook definitions
for GET lookup and POST delivery. It is deliberately restricted to the local
loopback simulator protocol, plain fixed configuration and a 15-second request
budget. It suppresses request body attachments, including when notice logging is
enabled. Its fingerprint is pinned when accepting work. This adapter is not a
production TLS/credential integration or a claim that arbitrary providers support
safe retries; a future provider must supply idempotency or reconciliation.

The contract runner now covers lease contention, stale completion, crash-budget
exhaustion, reviewed replay, configuration/revision drift and actual Cenit HTTP
execution. A Rails composition test durably accepts work, loses the response after
a successful external effect, creates a fresh worker, reconciles and completes
without a second effect or a copied order. That composition test stubs the
source-query boundary; the full public-HTTP two-system runner is still required.

## Remaining increments and completion evidence

1. Wire receipt and work into a separately running Cenit consumer that uses only
   data-action's public HTTP contract and generated service credentials.
2. Demonstrate real process restarts, transient errors, lost responses, lease
   fencing, dead-letter recovery and reviewed replay in a disposable two-system
   runner. Correlate Command, record revision, event delivery, Cenit work and
   downstream receipt.
3. Publish the complete operator runbook and architecture checks, verify relevant
   existing regressions, and keep increments reviewable in separate PRs. No
   Mongoid remote query emulation or general workflow-engine changes are in scope.

Completion requires the complete runner against both checkouts, not merely client
unit tests or the earlier simulated consumer. Future provider retry safety depends
on provider idempotency or reconciliation support.
