# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - Unreleased

Moves the SDK to the next-generation OctaSpace API (`https://api-dev.octa.space`). This release is
not compatible with the legacy API; see [docs/migration-next.md](docs/migration-next.md).

### Added

- `client.compute`: `list`, `start`, `start_batch`, `restart`.
- `client.render`: `list`, `start`, `start_batch`.
- `client.sessions`: `list`, `get`, `logs(tail:)`, `stop`, `wait_ready`, `wait_stopped`.
- `client.hosting`: `nodes`, `set_prices`.
- `client.stats`: `gpu_current`, `gpu_history` (with `GpuHistory#points`), `gpu_locations`.
- Typed read-only models (`OctaSpace::Model`, `OctaSpace::Types::*`) that keep unknown fields.
- `OctaSpace::Money` for integer micro-USD.
- `OctaSpace::ConflictError` (409), `SessionStoppedError`, `WaitTimeoutError`.
- `OctaSpace::RateLimit`, `client.rate_limit`, `ApiError#retry_after` / `#rate_limit` / `#body`.
- `bin/smoke` live checks and a CI smoke job; `bundler-audit` in CI; Dependabot.

### Changed

- Default base URL is `https://api-dev.octa.space`; authentication is `Authorization: Bearer <key>`
  with `octa_ak_…` keys.
- Resource methods return models, uuids or `nil` instead of `OctaSpace::Response`.
- 400 maps to `ValidationError`; error messages come from the API's `{"message"}`.
- Retries only for GET and the idempotent session stop, honouring `Retry-After` up to 60 s;
  failover across `base_urls` only for GET.
- Logging never includes headers or bodies; `on_request` no longer receives headers.
- Requires Ruby 3.3+ and faraday 2.14.3+; `faraday-retry` is no longer a dependency.

### Removed

- Legacy resources: `nodes`, `apps`, `idle_jobs`, `services` (`mr`, `vpn`, `render`, `session`),
  `accounts.profile`, `accounts.generate_wallet`.
- `ProvisionRejectedError`, `PayloadHelpers`, the old `Types::Account/Balance/Node/Session`.
- The Rails playground (`bin/playground`, `test/dummy`), `MockTransport`, the Rails Engine and the
  Appraisal matrix.

## [0.2.0] - 2026-04-16

### Added

- Support for `client.services.session(uuid).logs(recent: true)` for finished-session log retrieval.
- `OctaSpace::ProvisionRejectedError` for MR create requests that are transport-successful but rejected by the API payload contract.
- `OctaSpace::PayloadHelpers` with targeted helpers for stringified app port lists and marketplace bandwidth normalization.
- Diagnostics preset and manual runner support for recent session logs.
- Live-shaped fixtures for recent sessions and render marketplace responses.

### Changed

- `services.mr.list`, `services.render.list`, and `services.vpn.list` are now documented and tested as marketplace catalog endpoints rather than session collections.
- `services.mr.create` now forwards optional `organization_id` and `project_id`.
- Playground Services now presents marketplace-oriented summaries with normalized bandwidth display.
- Playground and README copy now reflect live API quirks for app ports, recent sessions, and finished-session logs.
- Publishing guidance now uses an explicit manual release flow, and the local `rake release` helper is disabled to avoid accidental RubyGems publication.

### Fixed

- Corrected the Ruby public API gap for recent finished-session logs.
- Corrected MR create handling for `HTTP 200` batch-style rejection responses.
- Corrected fixtures and tests that modeled `/services/mr` and `/services/vpn` as session lists.
- Corrected logs fixtures and tests to match the live `{system, container}` payload shape.
- Corrected the playground Apps page so port counts work when the live API returns stringified JSON arrays.
- Corrected test coverage for `sessions?recent=true` by using live-shaped string telemetry fields.

## [0.1.0] - 2026-04-12

### Added

- Initial release of the official OctaSpace Ruby SDK.
- Support for core resources: Accounts, Nodes, Sessions, Apps, Network, and Idle Jobs.
- Resource-oriented client: `client.nodes.list`, `client.services.session(uuid).stop`.
- Persistent HTTP connections (keep-alive mode) via `ConnectionPool`.
- Automatic URL rotation and failover for high availability.
- Retry with exponential backoff and jitter for transient errors.
- Typed error hierarchy based on HTTP status codes.
- Rails integration with automatic client sharing and graceful shutdown.
- Interactive Playground app for manual testing and diagnostics.

[0.2.0]: https://github.com/octaspace/ruby-sdk/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/octaspace/ruby-sdk/releases/tag/v0.1.0
