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
- UI repository checked out as a sibling directory at `../ui` (or set `CENIT_UI_CONTEXT`)

### 1) Clone repositories

```bash
# backend
git clone git@github.com:cenit-io/cenit.git

# UI (sibling directory required by default compose config)
git clone git@github.com:cenit-io/ui.git ../ui
```

If your UI checkout lives elsewhere:

```bash
export CENIT_UI_CONTEXT=/absolute/path/to/ui
```

### 2) Start the stack

```bash
cd /path/to/cenit
docker compose up -d --build
docker compose ps
```

### 3) Verify services

```bash
curl -I http://localhost:3000
curl -I http://localhost:3002
```

On first bootstrap (fresh database), default admin credentials:

- Email: `support@cenit.io`
- Password: `password`

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
- `CENIT_E2E_AUTOSTART` (`1` to auto-start stack in E2E scripts)
- `CENIT_E2E_RESET_STACK` (`1` to reset containers/volumes before E2E)
- `CENIT_E2E_BUILD_STACK` (`1` to rebuild images before E2E)
- `CENIT_E2E_HEADED` (`1` for headed browser runs)

## Testing and quality checks

### Login E2E smoke

```bash
scripts/e2e/cenit_ui_login.sh
```

### Contact data type + records E2E

```bash
scripts/e2e/cenit_ui_contact_flow.sh
```

Useful overrides:

```bash
# Reuse already-running stack
CENIT_E2E_AUTOSTART=0 scripts/e2e/cenit_ui_contact_flow.sh

# Run headed
CENIT_E2E_HEADED=1 scripts/e2e/cenit_ui_contact_flow.sh

# Slower machines
CENIT_E2E_SERVER_READY_RETRIES=240 \
CENIT_E2E_UI_READY_RETRIES=180 \
scripts/e2e/cenit_ui_contact_flow.sh
```

### UI user journey E2E

```bash
scripts/e2e/cenit_ui_user_journey.sh
```

### Flow execution + RabbitMQ smoke

```bash
scripts/e2e/cenit_flow_execution_smoke.sh
```

Artifacts are written under `output/playwright/`.

## Git hooks (pre-push E2E)

Install hooks:

```bash
npm install
npm run prepare
```

Current `pre-push` behavior:

- Runs `scripts/e2e/cenit_ui_contact_flow.sh`
- Uses fresh stack defaults:
  - `CENIT_E2E_RESET_STACK=1`
  - `CENIT_E2E_BUILD_STACK=1`
  - `CENIT_E2E_CLEANUP=0` (cleanup disabled for hook stability)

Overrides:

```bash
# Reuse running stack
CENIT_E2E_AUTOSTART=0 git push

# Keep current volumes/state
CENIT_E2E_RESET_STACK=0 git push

# Skip image rebuild
CENIT_E2E_BUILD_STACK=0 git push

# Force cleanup phase
CENIT_E2E_CLEANUP=1 git push

# Skip hooks once
HUSKY=0 git push
```

## Troubleshooting

### Backend does not become reachable on `:3000`

```bash
docker compose ps -a
docker compose logs --no-color --tail=200 server
```

If needed, run a full reset and rebuild:

```bash
docker compose down -v --remove-orphans
docker compose up -d --build
```

### E2E instability after many local runs

Use a clean boot:

```bash
CENIT_E2E_RESET_STACK=1 \
CENIT_E2E_BUILD_STACK=1 \
scripts/e2e/cenit_ui_contact_flow.sh
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
