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

## API v1 and v2

The legacy `/api/v1` and `/api/v2` routes and controllers have been removed.
The checked-out UI and internal dependencies had no Cenit v1/v2 HTTP callers.
This inventory cannot establish which external clients ran historically.

Use OAuth bearer tokens and the v3 model routes for CRUD. For an authenticated
connectivity check, read a model for which the token has scope instead of
calling the retired auth ping. Anonymous catalog reads and bulk push do not
have a drop-in prefix replacement; migrate callers to scoped v3 operations
and check the contract before promoting the upgrade. No compatibility
redirect is provided.

| Legacy operation | Relaunch contract |
| --- | --- |
| User bootstrap and CRUD | Use v3 model endpoints. Confirm the v3 JSON envelope; it differs from v2. |
| Namespace bulk push | Use scoped v3 creates per model. There is no equivalent bulk write in the relaunch API. |
| Public catalog reads | Removed; authenticated model access remains scoped. |
| Data type digest by slug | v3's base digest can create a record. It is not a replacement for v2's asynchronous raw ingestion task. |
| Algorithm execution | Use POST on the v3 algorithm digest, as the UI does. |
| Task retry | Use the v3 task digest retry. |
| OAuth provider authorization | Use the tenant-aware authorization flow. Do not port the legacy redirect parameter. |
| Property view | Use a v3 item read, with the documented viewport when applicable. |
| Shared collection pull | See the collection migration below; use local import for relaunch integrations. |

The older public API v2 documentation is for previous versions of Cenit.
See the [v2 retirement audit](api-v2-retirement.md) for the route-by-route
differences, credential changes, and follow-up acceptance criteria.

## Local collections

Shared Collections, publishing, push, and reinstall have been retired.
Finish pending requests for those tasks in the older release. Back up or
export historical packages before upgrading; Slim does not delete their
MongoDB documents or install their catalog definitions. Recover old
packages using the previous release on an isolated copy of the backup.

In Slim, open a local Collection and use **Export JSON**. The API endpoint
is `GET /api/v3/setup/collection/:id/digest/export`. It checks the current
tenant and requires digest permission and read permission for the collection
and each exported member. The JSON keeps logical references so the records
can be rebound on import. Fields marked protected by Cenit (such as Basic
Authorization credentials) are excluded; inspect arbitrary metadata,
headers, and scripts before sharing any export.

Use Collections **Pull Import** to upload the local JSON in the destination
tenant, then review and apply the changes in the import task. The API
accepts JSON or a multipart file at `POST /api/v3/setup/collection/import`
with create and digest permission. Configure
credentials separately at the destination. The old catalog installation
parameters and remote updates are not part of the local import contract.
