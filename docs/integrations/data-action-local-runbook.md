# Run the real local Cenit/data-action journey

## Prerequisites

Use the matching review branches of both checkouts, Docker running locally,
Cenit's Ruby 3.2.2 with its installed bundle and rbenv, and data-action's Node
24.19.0 / pnpm 11.20.0 dependencies. Run `bundle check` in Cenit using rbenv and
`pnpm install --frozen-lockfile` in data-action if dependencies are missing.
No production credentials or existing databases are needed.

From the Cenit checkout:

```sh
node scripts/run_data_action_journey.mjs --data-action-root /absolute/path/to/data-action
```

The runner creates a private temporary directory, a disposable MongoDB container
and a uniquely named PostgreSQL Compose project. Both database ports bind only to
loopback and are allocated dynamically. It applies data-action's committed
migrations to that empty PostgreSQL database. Docker may pull the pinned MongoDB
and PostgreSQL images on first use. Existing stacks and checkout changes are not
reset. Allow several minutes: Cenit deliberately starts a fresh Rails process for
each consumer action and recovery check.

## What executes

Data-action's fixture hosts the actual `/api/integration/v1` transport handlers and
application composition with real PostgreSQL persistence. It does not start the
Next.js console. Identity/initial operator authority are synthetic bootstrap
fixtures; business schema, Query, Policy, Operations, profile, subscription and
service credential are established through the existing public operator CLI.
The service bearer secret is generated, its digest is persisted by data-action,
and its owner-only local file is read on each consumer request.

The separate Ruby process loads the actual Cenit Rails application. Cenit persists
its LiquidTemplate, Connection, PlainWebhook and private execution receipts/work
in its own MongoDB. The fixed versioned mapping is
`experiments/data_action/order.liquid`, outside the integration kernel. There is
no Mongoid remote-model facade. Cenit's consumer configuration contains public
HTTP references, the local credential file reference and the local sink origin;
it contains no PostgreSQL connection or fault-control credential.

The downstream simulator stores its effects and receipts in its own PostgreSQL
database/role. It accepts a stable effect key, deduplicates identical deliveries,
rejects a different body for the same key, and supports lookup by key. This is the
capability required for safe reconciliation after an uncertain HTTP result.

## Expected evidence

Each completed scenario prints a JSON line. The final line has `status: passed`
and correlates each committed Command, original record revision, event delivery,
Cenit job and downstream receipt. The acceptance assertions cover:

- Invalid nested quantity returns `items[0].quantity` with no business record.
- Two concurrent Cenit intake processes reuse one durable intent key and return
  one Command/record, with one order-created event.
- A process exits after journaled durable reception but before acknowledgment;
  redelivery and a fresh process retain one work item and acknowledge acceptance.
- A later order edit does not change the original revision used by the event.
- A transient delivery fails independently of event acknowledgment. The next
  successful delivery loses its response; a fresh worker reconciles it and
  completes with one effect, matching the original revision's transformation.
- A process exits after committing an external effect but before local completion;
  a reclaimed work lease completes by reconciliation without another effect.
- Eight failed attempts dead-letter the work. A reviewed replay preserves event
  and effect identity, retains old attempts, records the operator/reason and
  completes after recovery.
- A producer delivery also exhausts eight failed acceptances, then a public
  authorized replay retains its event identity, nine attempt records and an audit
  entry before Cenit accepts and completes it.
- Concurrent public event claims grant one active lease. An expired fencing token
  cannot acknowledge a newer claim.

The full runner starts five synthetic orders and edits one. The successful final
summary reports five business records, five acknowledged order-created deliveries,
five completed Cenit jobs and five downstream effects. The edited record has a
second revision; its earlier event/job still references revision one.

## Fault controls and cleanup

Fault switches live exclusively in the disposable experiments. The fixture owner
can expire event leases or make pending deliveries available, and the local Cenit
pilot can advance its own work leases/backoff. These changes shorten the failure
exercises; they never alter event identity, payloads, attempt counters or completed
business revisions. Production adapters retain their 120-second leases and bounded
backoff. No administrative SQL capability is exposed through the production API
or supplied to the consumer.

The Cenit pilot refuses a non-journey test database or a non-loopback source. Crash
switches/replay helpers are local operator commands with synthetic tenant context,
not new unauthenticated application endpoints. Event acknowledgment means durable
acceptance; downstream completion is reported separately.

Normal completion and Ctrl-C stop the fixture, remove its owned PostgreSQL
container/volume/network, remove the owned MongoDB container, and delete temporary
credential/input/intent files. If Docker or a process is forcibly killed, inspect
only the runner-owned `data-action-foundation-<fixture PID>` Compose project and
its printed process diagnostics before cleaning it up. Never use a global Docker
prune command. Re-run from empty disposable databases after diagnosing a failure;
do not reuse a successful intent file for changed input.

For a smaller Cenit-only regression run:

```sh
scripts/run_data_action_contracts.sh
node --test test/data_action/journey_architecture.test.mjs
CENIT_DATA_ACTION_ROOT=/absolute/path/to/data-action node --test test/data_action/journey_cleanup.test.mjs
```

Data-action regression commands are `pnpm test`, `pnpm typecheck`, `pnpm lint`,
`pnpm secrets:check`, `pnpm test:persistence` and
`pnpm test:business-foundation:local`. The existing console regression remains
part of data-action's test suite. Cenit's existing non-E2E and API journey request
specs remain separate regression gates.

This milestone qualifies a local explicit integration boundary and failure
recovery. It does not add a general scheduler, production connector, cloud
deployment, Mongoid compatibility or a universal exactly-once guarantee. A future
provider must offer idempotency or reliable reconciliation before applying the
same external-effect retry rule.

See [local qualification evidence](data-action-local-qualification.md) for the requirement-by-requirement audit.
