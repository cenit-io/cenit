# Local Cenit integration qualification — 2026-10-30

This records the current local milestone, separately from the original simulated
consumer evidence and historical architecture documents. The checked journey
completed with five data-action business records, six committed record revisions
(one later edit), five acknowledged created-event deliveries, five completed Cenit
jobs and five deduplicated downstream effects.

| Requirement | Current implementation and observed evidence |
| --- | --- |
| Consolidated data-action base | Foundation PR #4 merges the missing console/core history onto the PR #1 source; the Cenit fixture branch starts from that consolidated base. No master merge or deployment is required for this local qualification. |
| Authoritative business writes | Real Cenit processes invoke published Operations through the public client. The consumer has no data-action SQL connection; source/transport architecture tests guard this boundary. Invalid nested input creates no record; concurrent identical intake returns one Command/record and one revision/event fact. |
| Current authentication and governance | Public handlers use generated service credentials and existing Identity/Membership/Policy evaluation. The unchanged foundation acceptance additionally verifies expiry, revocation, Workspace isolation, exact publication selection and denied management authority. |
| Atomic mutation evidence | The foundation PostgreSQL acceptance injects failures at record, Command, revision, event and audit writes. The existing persistence suite passes 25 tests, retaining copy/import/restore/link coverage and current adapters. |
| Immutable event revision | An order is edited from Miami/quantity 2 to Barcelona/quantity 99 after its created event. Actual Cenit Liquid/HTTP delivery still produces Miami/quantity 2 from revision one. Correlated final status matches event, Command, record/revision and job references. |
| Durable acceptance before ack | A real process exits with code 75 after journaled receipt/work insertion. The event remains leased. Redelivery to another process keeps one work item and acknowledges acceptance. |
| Actual Cenit transformation and connector | Persisted LiquidTemplate, Connection and PlainWebhook models execute in the Rails runtime; there is no remote record model. MongoDB stores private execution references/digests, not an Order business DataType. Request payload attachments are suppressed and covered by a Rails test. |
| Local work and source fencing | Actual MongoDB tests cover concurrent claims, renewal, stale completion, clock skew and crash exhaustion. The full journey concurrently claims public events and rejects an expired token with STALE_LEASE. |
| Retry and reconciliation | A transient failure occurs after event acknowledgment. A subsequent successful effect loses its response. A new process looks up the stable key and completes with one effect/verified receipt. Another process exits with code 76 after an effect and recovers by the same rule. |
| Dead letters and reviewed replay | Eight worker failures retain eight attempts. Trusted local replay preserves effect/event identity, appends reviewer/reason, and completes with nine attempts retained. Separately, eight public event failures dead-letter delivery; authorized public replay preserves the event, retains nine attempts after acknowledgment and commits one review audit entry. |
| Reproducibility and cleanup | The single Node runner launches both checkouts with isolated stores and correlated JSON output. The interruption test verifies owner-only temporary files/directories and owned containers disappear while pre-existing containers remain. Failure-clock injection is restricted to the disposable experiment. |
| Regression and architecture gates | Data-action full tests, types, lint and secret scan pass; its earlier simulated-consumer HTTP acceptance and 25 PostgreSQL regressions pass. Cenit contract tests and 16 Rails composition/adapter examples pass, with source/transport checks in CI. Existing Cenit non-E2E and API journey request specs remain required commit/push gates. |

Reproduce the evidence using the [operator runbook](data-action-local-runbook.md).
The local runner uses production data-action HTTP handlers in its fixture server,
not the Next.js console or a fake business API. Existing console regressions remain
separate evidence; historical evidence has not been rewritten.

This proves the explicit local order boundary and recovery behavior. It does not
qualify general Flow/Mongoid compatibility, production security/operations, cloud
deployment or arbitrary provider retries. A future provider must offer idempotency
or reliable reconciliation. No broker, marketplace connector or production-data
migration is introduced.
