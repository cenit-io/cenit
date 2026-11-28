# API v2 retirement audit

Inventory from the last Slim commit with v2 (`faf0839c`), compared against the
v3 routes, controller handlers, and UI calls. Paths in the first column are
relative to `/api/v2` and paths in the third column to `/api/v3` unless noted.
The UI and checked-out internal gems had no direct Cenit v2 callers. This
does not establish that historical scripts or external integrations never
used it. The published v2 spec is a reference for older releases.

| v2 route | Disposition | v3 replacement or gap |
| --- | --- | --- |
| POST `/auth/ping` | Replace, not wire-compatible | Read a model with a scoped bearer token. No dedicated ping with the old status/body. |
| HEAD `/auth` | Replace, not wire-compatible | Same scoped read; no dedicated HEAD auth endpoint. |
| GET `/public/:model` | Deliberately retired | No unauthenticated catalog listing. Authenticated v3 list is not the same contract. |
| GET `/public/:model/:id(.:format)` | Deliberately retired | No unauthenticated catalog item API. Explicit public file delivery is a separate route and should not be repurposed for catalog reads. |
| POST `/setup/user` | Retained | v3 has CAPTCHA/bootstrap coverage. Clients should verify required fields and errors rather than assuming the v2 payload. |
| POST `/:ns/push` | Gap: F1 | v2 accepted batches keyed by model and reported success/errors per item. Use individual scoped v3 creates for smaller workloads. The v3 collection push digest is not bulk record creation. |
| POST `/:ns/:model` | Retained with payload changes | Send the record directly using the v3 contract; there is no promise of support for v2 model-root envelopes, bulk inputs, or XML. Request a viewport if the response must contain the new ID. |
| POST `/:ns/:model/digest` | Gap: F2 | v2 enqueued `Setup::DataTypeDigest` with the raw payload. v3 `POST /setup/data_type/:id/digest` invokes the model's create action; it is not the same ingestion task. |
| GET `/:ns/:model` | Retained with response changes | v3 uses `items` rather than a model-named array and has its own paging/selector contract. |
| GET `/:ns/:model/:id` | Retained for records; file gap F3 | v3 record read returns JSON. v2 could stream bytes for file records. v3 offers a separate file-data-type download workflow. |
| POST `/:ns/:model/:id` | Retained with payload changes | v3 uses its model parser and scope checks; do not depend on the v2 envelope or update response. |
| DELETE `/:ns/:model/:id` | Retained with response changes | v3 has model delete; validate status/body before migrating a client that checks the v2 response literal. |
| POST `/:ns/:model/:id/pull` | Remote catalog deliberately retired | Local JSON import/review is the replacement for portable integrations, not remote catalog install. Verify export/import under the Shared Collections slice. |
| POST `/:ns/:model/:id/run` | Retained for algorithms | POST `/setup/algorithm/:id/digest`. Existing Slim request coverage verifies scoped access and completed execution; v3 returns a bounded execution/task receipt, not the v2 task body. |
| GET `/:ns/:model/:id/retry` | Route exists; behavior follow-up F4 | UI calls GET `/setup/task/:id/digest/retry`. No claim of parity for v2's retryable states or response. |
| GET `/:ns/:model/:id/authorize` | Browser flow retained; gap F5 | The UI uses the tenant-aware `/authorization/:tenant_id/:id/authorize` route, which authenticates a browser session and redirects. It is not v2's JSON `authorize_url` contract. |
| GET `/:ns/:model/:id/:view` | Replace with projection | Use the v3 record read with a supported `X-Template-Options` viewport, or project client-side. No legacy path selector or exact wrapper parity. |
| OPTIONS `/*path` | Retained on v3 | v3 has a preflight request spec. Consumers must send preflight to the new URL with the v3 headers. |

Authentication change across all versioned routes: v2 accepted tenant and
user access key/token pairs and hub credentials, in addition to OAuth. The
v3 controller uses bearer tokens. Migrate versioned API clients to scoped
OAuth credentials. This audit does not remove the separate application or
webhook routes that still handle their own credential schemes.

## Follow-ups

These are open tasks, not implemented compatibility claims. Review known
launch integration configurations before adding any adapter.

- [ ] **F1: Batch writes.** If a launch client needs mixed-model batch ingestion,
  define a bounded v3 API and test per-item authorization, errors, and partial
  success. Do not reuse collection publication or restore the entire v2 controller.
- [ ] **F2: Asynchronous raw ingestion.** Identify integrations relying on the
  v2 digest task rather than synchronous record creation. If needed, expose a
  scoped v3 action with explicit accepted media types, parser settings, stored
  execution evidence, and tenant isolation. Until then, do not tell clients
  that v3's base digest is a compatible replacement.
- [ ] **F3: Files and XML clients.** Verify a file download by ID under the
  intended tenant and scope, including MIME/content disposition and denial
  from another tenant. Inventory XML and model-root payload consumers; port the
  ones required for relaunch or explicitly record them as unsupported.
- [ ] **F4: Task retry.** Add a v3 request spec for a retryable task, a running
  task, and a token without the required permission. Verify that the retry
  produces a readable, bounded receipt and does not enqueue a second task
  when the request is denied.
- [ ] **F5: Headless OAuth authorization.** Confirm whether any non-browser
  client used the legacy JSON URL response. If required, design a scoped
  replacement with a fixed/registered callback and cover the full round trip.
  Do not restore arbitrary redirect parameters.
