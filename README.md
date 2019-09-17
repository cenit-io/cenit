![cenit_io](https://user-images.githubusercontent.com/4213488/40578188-bcbf8a58-60c4-11e8-96d7-19842c348c5e.png)

[![Code Climate](https://codeclimate.com/github/openjaf/cenit/badges/gpa.svg)](https://codeclimate.com/github/openjaf/cenit)
[![codebeat](https://codebeat.co/badges/1b596784-b6c1-4ce7-b739-c91b873e4b5d)](https://codebeat.co/projects/github-com-cenit-io-cenit)
[![license](https://img.shields.io/packagist/l/doctrine/orm.svg)]()

[![OpenAPIs in collection][numApis-image]][apisDir-link]
[![OpenAPI specs][numSpecs-image]][apisDir-link]
[![Endpoints][endpoints-image]][apisDir-link]

[![Follow on Twitter][twitterFollow-image]][twitterFollow-link]


* [Join our Slack][join-slack-link]
[(cenitio.slack.com)][join-slack-link]
* [docs](https://cenit-io.github.io/docs)
* [Shared Collections](https://cenit.io/setup~shared_collection)
* support@cenit.io

# Cenit IO [(https://cenit.io)](https://cenit.io)

Is a 100% open integration Platform (iPaaS) that's modern, powerful, yet hackable to the core, ready to use in the cloud https://cenit.io or on-premises. It is designed to solve unique integrations needs, orchestrate data flows that may involve types of protocols and data formats, and provide API management capabilities. All of which can support wide range of integration use cases. Is particular valuable to embrace a pervasive integration approach.

To install and learn more about the platform check the [documentation](https://cenit-io.github.io/docs)

## Why

The insatiable need for integration driven by social networks, open APIs, mobile apps, cloud services and, increasingly, the IoT is fertile ground for the growth in adoption of integration platforms.

Many are familiar with services such as Zapier and IFTTT, which addresses common integration problems but have limited capabilities to adapt to particular needs and to reflect business flows that are not simple. iPaaS platforms are designed to handle this issue, being in recent years in the state of the art for applications and data integration technologies used by large organizations, and gaining increasing interest in the general public.

The proliferation and growing importance of decentralized integration tasks driven by business and IT trends are forcing to rethink organizational models and technology platforms to an approach to pervasive integration.

None of the vendor leaders in the market really offers a completely open and transparent solution, with the freedom to use, customize or modified without restriction, we believe that is one of the keys to a wide adoption, and relevant to making the decision to use on-premise.

## Value

Cenit makes possible that benefits of a modern iPaaS should be accessible to the small and midsize organizations, particularly valuable to embrace as a strategic component of a pervasive integration approach that allows a complete automation of all operational processes. As well as adding value quickly and continuously, essential to be competitive in the actual economy.

## How

* Developing a 100% open source integration Platform (iPaaS).
* Provide options to use in the cloud https://cenit.io or on-premise server.
* Include open catalogs for formal API specs.
* Options to share integrations at different openness levels: inside a tenant, to specific tenants, or for everyone.
* Ensure that anyone can create, use and share integrations.
* Be ready for enterprise environments.

## Capabilities

* **Backendless**: After creating a new Data Type using a JSON Schema is generated on the fly a complete REST API and a CRUD UI to manage the data. Useful for mobile backend and API services.

* **Routing and orchestration**: Integration flow development, monitoring, and lifecycle management tools. Enables multi-step integration flows by compose atomic functionality (such as connection, transformation, data event, schedule, webhook).

* **Data integration**: Data validation, transformation, mapping, and data quality. Exchange support for multiple formats (JSON, XML, ASN), standards (EDIFACT, X12, UBL) and protocol connectors (HTTP(S), FTP, SFTP, SCP).

* **Third party service integrations**: Directory for OpenAPI Spec (Swagger) and Shared Collections - social feature to share integration settings - to connect services as ERP / Fulfilment / Marketing / Communication.


## Data Pipelines between APIs

It allows the creation of custom data pipelines to process, storage and move data between APIs. The flows could be trigger by data events or be scheduled.

There are now over 200 pre-built integration collections shared out the box to connect with online internet services,
fulfillment solutions, accounting, communications, ERP, multi-channels, etc.

[see this video for more details](https://youtu.be/IOEbTtEv8MQ)

An example of integration data flow (Fancy <=> Shipstation):

* Every 20 minutes Cenit trigger a flow to get orders from Fancy Marketplace.

* New or updated orders are received and persisted in Cenit.

* After the new or updated orders are saved, is trigger a Flow to send a shipment to Shipstation.

* The flow requires transforming the Fancy Order into a valid shipment on Shipstation.

* Each 20 minutes Cenit trigger a flow to fetch Shipped shipments from Shipstation.

* After the shipments are updated in Cenit, is trigger a Flow to send the tracking update to Fancy.

## Stack

* Ruby
* Mongodb
* RabbitMQ
* Redis

## Contributing

Cenit IO is an open source project and we encourage contributions.

In the spirit of [free software](http://www.fsf.org/licensing/essays/free-sw.html), **everyone** is encouraged to help
improve this project.

Here are some ways **you** can contribute:

* by using prerelease master branch
* by reporting [bugs](https://github.com/cenit-io/cenit/issues/new)
* by writing or editing [documentation](https://github.com/cenit-io/docs)
* by writing [needed code](https://github.com/cenit-io/cenit/labels/feature_request) or [finishing code](https://github.com/cenit-io/cenit/labels/address_feedback)
* by [refactoring code](https://github.com/cenit-io/cenit/labels/address_feedback)
* by reviewing [pull requests](https://github.com/cenit-io/cenit/pulls)

## To the Community

Since the challenge is great, we have to build the solution in community. We believe that a successful open source project provides confidence, facilitates creating a broad community, where everyone can share answers to questions, suggestions, and improvements to the platform.

We encourage the community to join the initiative and contribute to the dissemination of the project, sharing integration experiences, collaborating in the detection and resolution of errors or contributing to the development of the project. We hope that those who join us enjoy the collaborative work and the challenge of achieving something innovative and useful that can potentially serve many others.

## Screenshots

![dashboard](https://user-images.githubusercontent.com/4213488/40578423-8b132dc6-60c8-11e8-8754-e3d4f3fa95df.png)

![flows](https://user-images.githubusercontent.com/4213488/40578271-dad7e700-60c5-11e8-9eb3-0d1b75c69461.png)

![swagger](https://user-images.githubusercontent.com/4213488/40578290-4ca8697c-60c6-11e8-979f-b953d5dfb30c.png)

![open_api_directory](https://user-images.githubusercontent.com/4213488/40578339-41b5f844-60c7-11e8-8676-26a4ee494582.png)

[numApis-image]: https://api.apis.guru/badges/apis_in_collection.svg
[numSpecs-image]: https://api.apis.guru/badges/openapi_specs.svg
[endpoints-image]: https://api.apis.guru/badges/endpoints.svg
[apisDir-link]: https://github.com/APIs-guru/openapi-directory/tree/master/APIs
[twitterFollow-image]: https://img.shields.io/twitter/follow/cenit_io.svg?style=social
[twitterFollow-link]: https://twitter.com/intent/follow?screen_name=cenit_io
[join-slack-link]:
https://join.slack.com/t/cenitio/shared_invite/enQtNzI4MDUxMTM0NzUzLTJjMWRlNmRkMzUwYTQ1NTVhOTIyZTZjODI5MGFjZjU2NTA2ZDUzOWExMjY4NDUzOTA0OGUwM2JhMTNlNWQ0ZjU
