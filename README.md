![cenit_io](https://user-images.githubusercontent.com/4213488/150586701-53545c9b-b4f9-497f-9782-ef6a19715ecd.svg)

[![codebeat](https://codebeat.co/badges/1b596784-b6c1-4ce7-b739-c91b873e4b5d)](https://codebeat.co/projects/github-com-cenit-io-cenit)
[![license](https://img.shields.io/packagist/l/doctrine/orm.svg)]()

# [Cenit](https://web.cenit.io)

Is a 100% open integration-platform-as-a-service (iPaaS) that's modern, powerful, yet hackable to the core, ready to [use in the cloud](https://web.cenit.io) or on-premises. It is designed to solve unique integrations needs, orchestrate data flows that may involve types of protocols and data formats, and provide API management capabilities. All of which can support a wide range of integration use cases. It is particularly valuable to embrace a pervasive integration approach.

To install and learn more about the platform check the [documentation](https://docs.cenit.io/)

## Installation

General product documentation is available at [docs.cenit.io](https://docs.cenit.io/).

### Run Locally with Docker Compose

Prerequisites:

- Docker Desktop (or Docker Engine + Compose v2 plugin)
- `git`
- The UI repository checked out as a sibling folder at `../ui` (or update `services.ui.build.context` in `docker-compose.yml`)

Start the full local stack:

```bash
cd /path/to/cenit
docker compose up -d --build
docker compose ps
```

Verify services:

```bash
curl -I http://localhost:3000
```

- Backend: `http://localhost:3000`
- UI: `http://localhost:3002`
- RabbitMQ admin: `http://localhost:15672` (`cenit_rabbit` / `cenit_rabbit`)

On first bootstrap (fresh DB), the default super admin user is:

- Email: `support@cenit.io`
- Password: `password`

Useful operations:

```bash
# Follow backend logs
docker compose logs -f server

# Restart only backend
docker compose restart server

# Stop everything
docker compose down

# Stop and remove volumes (full reset)
docker compose down -v
```

### Migration Runtime Notes

- Current migration baseline in this repository uses Ruby `3.2.2` and MongoDB `7.0` in `docker-compose.yml`.
- The backend container boots with Rails in production mode and exposes Unicorn on `localhost:3000`.
- Non-fatal startup warnings may still appear during migration (autoload/deprecation noise), but the stack can boot and serve requests.

### Repeatable UI Login E2E Check

To run the login + OAuth consent flow on demand:

```bash
scripts/e2e/cenit_ui_login.sh
```

Optional overrides:

```bash
CENIT_E2E_EMAIL="support@cenit.io" \
CENIT_E2E_PASSWORD="password" \
CENIT_SERVER_URL="http://localhost:3000" \
CENIT_UI_URL="http://localhost:3002" \
CENIT_E2E_AUTOSTART=1 \
scripts/e2e/cenit_ui_login.sh
```

## Why

The insatiable need for integration driven by social networks, open APIs, mobile apps, cloud services, and increasingly, the IoT is fertile ground for the growth of integration platform adoption.

Many are familiar with services such as Zapier and IFTTT, which addresses common integration problems but have limited capabilities to adapt to particular needs and to reflect business flows that are not simple. iPaaS platforms are designed to handle this issue, being in recent years in the state of the art for applications and data integration technologies used by large organizations, and gaining increasing interest from the general public.

The proliferation and growing importance of decentralized integration tasks driven by business and IT trends are forcing us to rethink organizational models and technology platforms to an approach to pervasive integration.

None of the vendor leaders in the market offers a completely open and transparent solution, with the freedom to use, customize, or modified without restriction. We believe that is one of the keys to wide adoption, and it is relevant in deciding to use on-premise.

## Value

Cenit makes it possible that the benefits of a modern iPaaS can be accessible to the small and midsize organizations, It is particularly valuable to embrace as a strategic component of a pervasive integration approach that allows complete automation of all operational processes. As well as adding value quickly and continuously, essential to be competitive in the actual economy.

## How

- Developing a 100% open source integration Platform (iPaaS).
- Providing options to [use in the cloud](https://web.cenit.io) or [on-premise server](https://docs.cenit.io/docs/installation/alternative).
- Including open catalogs for formal API specs.
- Giving options to share integrations at different openness levels: inside a tenant, to specific tenants, or for everyone.
- Ensuring that anyone can create, use and share integrations.
- Being ready for enterprise environments.

## Capabilities

- **Backendless**: After creating a new Data Type using a JSON Schema, a complete REST API and a CRUD UI to manage the data are generated on the fly. Useful for mobile backend and API services.

- **Routing and orchestration**: Integration flow development, monitoring, and lifecycle management tools. Enables multi-step integration flows by composing atomic functionality (such as connection, transformation, data event, schedule, webhook).

- **Data integration**: Data validation, transformation, mapping, and data quality. Exchange support for multiple formats (JSON, XML, ASN), standards (EDIFACT, X12, UBL) and protocol connectors (HTTP(S), FTP, SFTP, SCP).

- **Third-party service integrations**: Directory of Shared Collections to connect services as ERP / Fulfilment / Marketing / Communication.

## Data Pipelines between APIs

It allows the creation of custom data pipelines to process, store and move data between APIs. The flows could be trigger by data events or be scheduled.

There are now over 200 pre-built integration collections shared out of the box to connect with online internet services,
fulfillment solutions, accounting, communications, ERP, multi-channel, etc.

[see this video for more details](https://youtu.be/IOEbTtEv8MQ)

An example of integration data flow (Fancy <=> Shipstation):

- Every 20 minutes Cenit triggers a flow to get orders from Fancy Marketplace.

- New or updated orders are received and persisted in Cenit.

- After the new or updated orders are saved, a Flow is triggered to send a shipment to Shipstation.

- The flow requires transforming the Fancy Order into a valid shipment on Shipstation.

- Every 20 minutes Cenit triggers a flow to fetch Shipped shipments from Shipstation.

- After the shipments are updated in Cenit, a Flow is triggered to send the tracking update to Fancy.

## Stack

- Ruby
- MongoDB
- RabbitMQ
- Redis

## Contributing

Cenit IO is an open-source project and we encourage contributions.

In the spirit of [free software](http://www.fsf.org/licensing/essays/free-sw.html), **everyone** is encouraged to help
improve this project.

Here are some ways **you** can contribute:

- by using prerelease master branch
- by reporting [bugs](https://github.com/cenit-io/cenit/issues/new)
- by writing or editing [documentation](https://github.com/cenit-io/cenit-docs)
- by writing [needed code](https://github.com/cenit-io/cenit/labels/feature_request) or [finishing code](https://github.com/cenit-io/cenit/labels/address_feedback)
- by [refactoring code](https://github.com/cenit-io/cenit/labels/address_feedback)
- by reviewing [pull requests](https://github.com/cenit-io/cenit/pulls)

## To the Community

Since the challenge is great, we have to build the solution in the community. We believe that a successful open source project provides confidence, facilitates creating a broad community, where everyone can share answers to questions, suggestions, and improvements to the platform.

We encourage the community to join the initiative and contribute to the dissemination of the project, sharing integration experiences, collaborating in the detection and resolution of errors, or contributing to the development of the project. We hope that those who join us enjoy the collaborative work and the challenge of achieving something innovative and useful that can potentially serve many others.

## Screenshots

![menu](https://user-images.githubusercontent.com/81880890/138016967-c57c2dfb-7f1a-49e2-a266-24cb3312acd1.png)

![tenants](https://user-images.githubusercontent.com/81880890/138016971-58acec6d-7397-4f16-85bc-6aa995fb2021.png)

![cenit_type](https://user-images.githubusercontent.com/81880890/138016964-a537ce74-892a-4583-a7da-deb762876b86.png)

![mobile_view](https://user-images.githubusercontent.com/81880890/148653137-d3459280-425b-449f-b206-cb8da0d73e1f.png)
