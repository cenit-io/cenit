# Cenit

![Cenit banner](https://user-images.githubusercontent.com/4213488/150586701-53545c9b-b4f9-497f-9782-ef6a19715ecd.svg)

[![Smoke: Docker Compose + UI Login](https://github.com/cenit-io/cenit/actions/workflows/smoke-docker-compose.yml/badge.svg)](https://github.com/cenit-io/cenit/actions/workflows/smoke-docker-compose.yml)
[![codebeat](https://codebeat.co/badges/1b596784-b6c1-4ce7-b739-c91b873e4b5d)](https://codebeat.co/projects/github-com-cenit-io-cenit)
[![License](https://img.shields.io/github/license/cenit-io/cenit)](LICENSE)

Cenit is an open-source integration-platform-as-a-service (iPaaS). It helps teams design integrations, orchestrate data flows, expose APIs, and manage data pipelines across external systems.

- Cloud: [web.cenit.io](https://web.cenit.io)
- Product documentation: [docs.cenit.io](https://docs.cenit.io/)

## Table of contents

- [What you can build](#what-you-can-build)
- [Architecture and stack](#architecture-and-stack)
- [Project status](#project-status)
- [Quick start (local Docker Compose)](#quick-start-local-docker-compose)
- [Configuration](#configuration)
- [Testing and quality checks](#testing-and-quality-checks)
- [Git hooks (pre-push E2E)](#git-hooks-pre-push-e2e)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Security](#security)
- [Code of conduct](#code-of-conduct)
- [License](#license)

## What you can build

- Backendless data APIs from JSON Schema-based Data Types.
- Integration flows for routing, orchestration, and automation.
- Data transformation pipelines across JSON, XML, ASN, EDIFACT, X12, UBL, and more.
- API and integration connectors for third-party services.
- Event- and schedule-driven integration workloads.

## Architecture and stack

Core runtime:

- Ruby (Rails + Unicorn)
- MongoDB
- Redis
- RabbitMQ

Default local ports:

- Backend: `http://localhost:3000`
- UI: `http://localhost:3002`
- RabbitMQ management: `http://localhost:15672`

Related repository:

- UI repository: [cenit-io/ui](https://github.com/cenit-io/ui)

## Project status

The repository is actively maintained. Current local migration baseline in this branch/repo:

- Ruby `3.2.2`
- MongoDB `7.0`
- Docker Compose local runtime

Additional migration context is documented in `upgrading_notes.md`.

## Quick start (local Docker Compose)

### Prerequisites

- Docker Desktop (or Docker Engine + Compose v2 plugin)
- `git`

### 1) Clone the repository

```bash
git clone https://github.com/cenit-io/cenit.git
cd cenit
```

### 2) Start the stack

```bash
docker compose up -d --wait --wait-timeout 300
scripts/smoke/compose_stack.sh
```

The default stack runs the five published services needed to evaluate Cenit:

- UI: `http://localhost:3002`
- Backend: `http://localhost:3000`
- RabbitMQ management: `http://localhost:15672`

Default admin credentials on a fresh database:

- Email: `support@cenit.io`
- Password: `password`

No source checkout or local image build of the UI is required.

### 2.1) Contributor development mode

Clone the UI as a sibling repository before using the development override:

```bash
git clone https://github.com/cenit-io/ui.git ../ui
scripts/compose-dev.sh up -d --wait --wait-timeout 300
```

This builds both images from local source. Set `CENIT_UI_CONTEXT` if the UI
checkout is not at `../ui`.

#### Fast UI development mode (live reload)

Use this when iterating on UI code to avoid rebuilding the nginx UI image:

```bash
cd /path/to/cenit
scripts/compose-dev.sh --profile dev up -d mongo_server redis rabbitmq server ui_dev
scripts/compose-dev.sh --profile dev ps
```

Notes:

- `ui_dev` serves Vite on `http://localhost:3002` with source mounted from `${CENIT_UI_CONTEXT:-../ui}`.
- Keep `ui` (nginx image service) for production-like checks and CI parity.

### 2.2) Explicit image-only (prod-like) mode

```bash
cd /path/to/cenit
scripts/compose-prod.sh up -d
scripts/compose-prod.sh ps
```

This uses:

- `docker-compose.yml` + `docker-compose.prod.yml`
- published images from GHCR (`pull_policy` defaults to `missing`)

GHCR tag policy (from publish workflows):

- `master` branch -> `ghcr.io/cenit-io/cenit:latest` and `ghcr.io/cenit-io/ui:latest`
- `develop` branch -> `ghcr.io/cenit-io/cenit:develop` and `ghcr.io/cenit-io/ui:develop`
- release tags `v*.*.*` -> semver tags
- every publish -> immutable `sha-<gitsha>` tag

Run prod-like using `develop` images:

```bash
CENIT_SERVER_IMAGE=ghcr.io/cenit-io/cenit:develop \
CENIT_UI_IMAGE=ghcr.io/cenit-io/ui:develop \
scripts/compose-prod.sh up -d
```

Run prod-like pinned to immutable SHA tags:

```bash
CENIT_SERVER_IMAGE=ghcr.io/cenit-io/cenit:sha-<server_sha> \
CENIT_UI_IMAGE=ghcr.io/cenit-io/ui:sha-<ui_sha> \
scripts/compose-prod.sh up -d
```

For strict refresh from registry each run:

```bash
CENIT_PULL_POLICY=always scripts/compose-prod.sh up -d
```

### 2.3) Repro mode with non-default host ports (redirect/debug)

Use this to reproduce host/port redirect issues (for example, verify UI does not fall back to `localhost:3000`).

```bash
cd /path/to/cenit
REPRO_SERVER_PORT=13000 REPRO_UI_PORT=13002 scripts/compose-repro.sh up -d
REPRO_SERVER_PORT=13000 REPRO_UI_PORT=13002 scripts/smoke/repro_runtime_ports.sh
```

Default repro port mapping:

- Backend host port: `13000 -> container 8080`
- UI host port: `13002 -> container 80`

Optional public URL overrides (if not using localhost):

```bash
REPRO_SERVER_PUBLIC_URL=http://127.0.0.1:13000 \
REPRO_UI_PUBLIC_URL=http://127.0.0.1:13002 \
scripts/smoke/repro_runtime_ports.sh
```

### 3) Verify services

```bash
scripts/smoke/compose_stack.sh
```

RabbitMQ default credentials:

- User: `cenit_rabbit`
- Password: `cenit_rabbit`
- VHost: `cenit_rabbit_vhost`

### Common local operations

```bash
# Follow backend logs
docker compose logs -f server

# Restart backend only
docker compose restart server

# Stop all services
docker compose down

# Full reset (containers + volumes)
docker compose down -v --remove-orphans
```

## Configuration

Important environment knobs used by local scripts:

- `CENIT_SERVER_URL` (default `http://localhost:3000`)
- `CENIT_UI_URL` (default `http://localhost:3002`)
- `CENIT_UI_CONTEXT` (path to UI repository for Docker build)
- `CENIT_SERVER_IMAGE` (prod-like server image tag, default `ghcr.io/cenit-io/cenit:latest`)
- `CENIT_UI_IMAGE` (prod-like UI image tag, default `ghcr.io/cenit-io/ui:latest`)
- `CENIT_UNICORN_WORKERS` (backend worker count, default `2` for local evaluation)
- `CENIT_MAXIMUM_UNICORN_CONSUMERS` (RabbitMQ consumer workers, default `2`)
- `CENIT_PULL_POLICY` (prod-like pull policy, default `missing`; use `always` for strict pulls)
- `CENIT_COMPOSE_FILES` (default: `docker-compose.yml:docker-compose.dev.yml`)
- `CENIT_COMPOSE_FILE` (legacy single-file override, still supported)
- `CENIT_BASE_COMPOSE_FILE` (helper override for base file)
- `CENIT_DEV_COMPOSE_FILE` (helper override for dev file)
- `CENIT_PROD_COMPOSE_FILE` (helper override for prod-like file)
- `CENIT_REPRO_COMPOSE_FILE` (helper override for repro file)

Image labels:

- GHCR images are published with OCI metadata labels (source/revision/created) via `docker/metadata-action`.

## Testing and quality checks

### Backend API integration checks

```bash
scripts/e2e/cenit_api_login.sh
scripts/e2e/cenit_api_contact_flow.sh
scripts/e2e/cenit_api_integration_journey.sh
```

Browser journeys are owned by the [Cenit UI repository](https://github.com/cenit-io/ui).
From a sibling UI checkout, run `npm run e2e:login`, `npm run e2e:contact-flow`,
`npm run e2e:user-journey`, or `npm run e2e:integration-journey`.

### Browser smoke: no localhost redirect during auth bootstrap

```bash
# Default URL
scripts/smoke/cenit_ui_no_localhost_redirect.sh

# Repro stack URL
CENIT_UI_URL=http://localhost:13002 scripts/smoke/cenit_ui_no_localhost_redirect.sh
```

This smoke fails if any browser request hits `http://localhost:3000` during initial auth flow.

### Pre-apply repro gate (runtime + browser checks)

```bash
REPRO_SERVER_PORT=13000 REPRO_UI_PORT=13002 scripts/smoke/repro_preapply_gate.sh
```

Use this as the required gate before Terraform apply or other deploy steps when validating the localhost redirect fix path.

### Flow execution + RabbitMQ smoke

```bash
scripts/e2e/cenit_flow_execution_smoke.sh
```

## Git hooks (pre-push E2E)

Install hooks:

```bash
npm install
npm run prepare
```

Current `pre-push` behavior:

- Runs the backend API v3 login, contact-flow, and strict integration journey.
- Does not require or invoke the UI repository.

Overrides:

```bash
# Skip the backend API E2E gate once
SKIP_E2E_HOOKS=1 git push
```

## Troubleshooting

### Backend does not become reachable on `:3000`

```bash
scripts/compose-dev.sh ps -a
scripts/compose-dev.sh logs --no-color --tail=200 server
```

If needed, run a full reset and rebuild:

```bash
scripts/compose-dev.sh down -v --remove-orphans
scripts/compose-dev.sh up -d --build
```

## Contributing

Contributions are welcome and appreciated.

- Contribution guide: [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md)
- Open an issue: [github.com/cenit-io/cenit/issues](https://github.com/cenit-io/cenit/issues)
- Open a pull request: [github.com/cenit-io/cenit/pulls](https://github.com/cenit-io/cenit/pulls)

Before opening a PR:

- Reproduce and describe the problem clearly.
- Include tests or reproducible validation steps.
- Keep scope focused and documented.

## Security

Please do not report security vulnerabilities in public issues.

- Use GitHub Security Advisories: [Report a vulnerability](https://github.com/cenit-io/cenit/security/advisories/new)

## Code of conduct

This project follows the code of conduct in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## License

Distributed under the terms in [LICENSE](LICENSE).

## Screenshots

![menu](https://user-images.githubusercontent.com/81880890/138016967-c57c2dfb-7f1a-49e2-a266-24cb3312acd1.png)
![tenants](https://user-images.githubusercontent.com/81880890/138016971-58acec6d-7397-4f16-85bc-6aa995fb2021.png)
![cenit_type](https://user-images.githubusercontent.com/81880890/138016964-a537ce74-892a-4583-a7da-deb762876b86.png)
![mobile_view](https://user-images.githubusercontent.com/81880890/148653137-d3459280-425b-449f-b206-cb8da0d73e1f.png)
