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

## Remaining increments and completion evidence

1. Durable receipt and pending work stored atomically in Cenit's own MongoDB,
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
