# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
