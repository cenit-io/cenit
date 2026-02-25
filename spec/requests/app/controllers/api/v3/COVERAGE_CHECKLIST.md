# API v3 Spec-to-Test Coverage Checklist

Source docs:
- API spec: `/Users/sanchojaf/Documents/cenit-io/api-v2-specs/spec/v3/openapi.yaml`
- Route checklist: `/Users/sanchojaf/Documents/cenit-io/api-v2-specs/spec/V3_ROUTE_GAP_CHECKLIST.md`

## Route Matrix

| Route | Controller action | Covered by test files |
|---|---|---|
| `POST /api/v3/setup/user` | `new_user` | `user_api_spec.rb` |
| `GET /api/v3/{ns}/{model}` | `index` | `generic_crud_spec.rb`, `integration_journey_spec.rb` |
| `POST /api/v3/{ns}/{model}` | `new` | `generic_crud_spec.rb`, `integration_journey_spec.rb` |
| `GET /api/v3/{ns}/{model}/{id}` | `show` | `generic_crud_spec.rb` |
| `POST /api/v3/{ns}/{model}/{id}` | `update` | `generic_crud_spec.rb` |
| `DELETE /api/v3/{ns}/{model}/{id}` | `destroy` | `generic_crud_spec.rb`, `integration_journey_spec.rb` |
| `GET /api/v3/{ns}/{model}/{id}/digest` | `digest` | `digest_spec.rb` |
| `POST /api/v3/{ns}/{model}/{id}/digest` | `digest` | `digest_spec.rb`, `integration_journey_spec.rb` |
| `DELETE /api/v3/{ns}/{model}/{id}/digest` | `digest` | `digest_spec.rb` |
| `GET /api/v3/{ns}/{model}/{id}/digest/{path}` | `digest` | `digest_spec.rb` |
| `POST /api/v3/{ns}/{model}/{id}/digest/{path}` | `digest` | `digest_spec.rb` |
| `DELETE /api/v3/{ns}/{model}/{id}/digest/{path}` | `digest` | `digest_spec.rb` |
| `OPTIONS /api/v3/*path` | `cors_check` | `cors_spec.rb` |

## Priority UI-used Built-in Models

- `Setup::DataType`
- `Setup::Flow`
- `Setup::Collection`
- `Setup::Application`

Current test usage:
- Directly covered in request/integration specs:
  - `Setup::DataType`
  - `Setup::Flow`
- Generic route coverage for remaining models is in place; dedicated `Setup::Collection` and `Setup::Application` focused specs can be added next.

## Suite Tags

- `:api_v3_requests` for fast request coverage
- `:api_journey` for the full API integration journey
- `:api_v3_integration` umbrella tag for all v3 integration request specs

## Commands

- Request coverage:
  - `bundle exec rspec spec/requests/app/controllers/api/v3 --tag api_v3_requests`
- API journey only:
  - `bundle exec rspec spec/requests/app/controllers/api/v3/integration_journey_spec.rb --tag api_journey`
- API journey (stable command):
  - `bundle exec rake api:v3:journey`
- API journey (strict command, no fallbacks):
  - `bundle exec rake api:v3:journey:strict`
- Full v3 integration:
  - `bundle exec rspec spec/requests/app/controllers/api/v3 --tag api_v3_integration`
