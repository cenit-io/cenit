# Cenit Slim migration

## OpenAPI catalog and import

Cenit no longer installs API specifications from a URL, uploaded archive, or
the API Specs screen. The `Setup::ApiSpec`, `Setup::ApiSpecImport`, and
`Setup::ApiPull` models are no longer available. This does not remove the
external OpenAPI documentation repository, HTTP Connections, Resource Paths,
or local collection import/export.

Before upgrading an existing database, take a backup and use the previous
release to export any raw specifications you want to keep. Finish or cancel
pending API import/pull tasks there. Keep the generated integrations as
ordinary collection exports; this change does not regenerate them. Do not
restore the retired task records into a fresh Slim installation.

The upgrade does not delete or rewrite MongoDB documents, including old
catalog entries and tasks. For historical task review or spec recovery, use
the previous release with an isolated copy of the backup; Slim does not
provide a viewer or runner for these types.

The repository audit found no versioned OpenAI spec or catalog seed in the
backend, UI, or checked-out internal gems. The sitemap and ignore-file
references to APIs.guru were stale. No Docker app was running when the
inventory started, so this is not a claim that existing databases are empty.
The API regression spec covers model withdrawal and the surviving gateway.

## API v1

The legacy `/api/v1` routes and controller have been removed. The checked-out
UI and internal dependencies had no Cenit v1 HTTP callers. This repository
inventory cannot establish which external clients were deployed historically.

Use OAuth bearer tokens and the v3 model routes for CRUD. For an authenticated
connectivity check, read a model for which the token has scope instead of
calling the retired auth ping. Anonymous catalog reads and bulk push do not
have a drop-in prefix replacement; migrate callers to scoped v3 operations
and check the contract before promoting the upgrade. No compatibility
redirect is provided. API v2 is unchanged by the v1 removal.
