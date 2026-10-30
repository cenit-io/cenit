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

## Remaining increments and completion evidence

1. Wire durable acceptance into the separately running consumer. Receipt and pending work are stored atomically in Cenit's own MongoDB,
   deduplicated by trusted account, workspace, profile and event identity. Store
   revision references and fingerprints, without a second managed order record.
   Acknowledge only after durable acceptance; detect inconsistent redelivery.
2. Use a real Cenit LiquidTemplate with a pinned mapping and explicit read-only
   source, then a real Connection/Webhook for delivery and reconciliation. Keep
   external-effect retries independent of event acknowledgment.
3. Demonstrate process restarts, transient errors, lost responses, lease fencing,
   dead-letter recovery and reviewed replay in a disposable runner. Correlate
   Command, record revision, event delivery, Cenit work and downstream receipt.
4. Publish reproducible instructions, run relevant regressions and architecture
   checks, and keep each increment reviewable in a separate PR. No Mongoid remote
   query emulation or general workflow engine changes are in scope.

Completion requires the complete runner against both checkouts, not merely client
unit tests or the earlier simulated consumer. Future provider retry safety depends
on provider idempotency or reconciliation support.
