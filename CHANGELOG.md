# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

The SDK follows the current OctaSpace API. Most resources changed; see the
[resources](docs/resources.md) and [sessions](docs/sessions.md) guides.

### Added

- `client.compute`: `list`, `start`, `start_batch` and `restart`.
- `client.render`: `list`, `start` and `start_batch`.
- `client.sessions`: `get`, `logs`, `stop`, `wait_ready` and `wait_stopped`.
- `client.hosting`: `nodes` and `set_prices`.
- `client.stats`: `gpu_current`, `gpu_history` and `gpu_locations`.
- Read-only response models under `OctaSpace::Types`, with `[]`, `to_h` and
  pattern matching.
- `OctaSpace::Money` for amounts in micro-USD.
- `ConflictError` (HTTP 409), `SessionStoppedError` and `WaitTimeoutError`.
- `retry_after`, `rate_limit` and `body` on `ApiError`, and `client.rate_limit`.
- The `max_retry_after` and `max_retry_interval` options.
- `OctaSpace::DEFAULT_BASE_URL` constant.
- Guides under `docs/`.

### Changed

- **Breaking:** the API key is sent as `Authorization: Bearer <key>`. A key
  that already has the `Bearer ` prefix is accepted.
- **Breaking:** the default base URL is `https://api-dev.octa.space`
  (`DEFAULT_BASE_URL`).
- **Breaking:** nodes are identified by their node number, for example
  `7KQ4-M2XD-4`.
- **Breaking:** prices, charges and the balance are integer micro-USD.
- **Breaking:** resource methods return models, session UUIDs or `nil` instead
  of `OctaSpace::Response`.
- **Breaking:** `sessions.list` takes no parameters and returns running
  sessions only.
- **Breaking:** HTTP 400 raises `ValidationError`, and the error message is the
  API's message.
- **Breaking:** only GET requests and `sessions.stop` are retried; starting and
  restarting sessions are never retried. A `Retry-After` longer than 60 seconds
  raises the error at once.
- **Breaking:** a method that needs an API key raises `AuthenticationError`
  before sending a request when none is configured.
- **Breaking:** `on_request` no longer receives the request headers. The log
  never contains headers or bodies.
- **Breaking:** requires Ruby 3.3 or later and Faraday 2.14.3 or later;
  `faraday-retry` is no longer a dependency.

### Removed

- **Breaking:** `client.nodes`, `client.apps`, `client.idle_jobs`,
  `client.services`, `accounts.profile` and `accounts.generate_wallet`, with
  their types. Hosted nodes and their prices are in `client.hosting`, sessions
  in `client.sessions`.
- **Breaking:** `ProvisionRejectedError`, `PayloadHelpers`,
  `Transport::MockTransport`, the `OctaSpace::Engine` playground and the
  `persistent` configuration alias of `keep_alive`.

## [0.2.0] - 2026-04-16

### Added

- `client.services.session(uuid).logs(recent: true)` for the logs of a finished
  session.
- `OctaSpace::ProvisionRejectedError` for machine rental requests that the API
  accepts but rejects in the response body.
- `OctaSpace::PayloadHelpers` for app port lists sent as strings and for
  marketplace bandwidth values.

### Changed

- `services.mr.list`, `services.render.list` and `services.vpn.list` return
  the marketplace catalog, not sessions.
- `services.mr.create` passes the optional `organization_id` and `project_id`.

### Fixed

- `services.mr.create` raises `ProvisionRejectedError` for a rejection returned
  with HTTP 200.

## [0.1.0] - 2026-04-12

First release.

### Added

- `OctaSpace::Client` and `OctaSpace.configure`, with accounts, nodes,
  sessions, apps, network, idle jobs and services resources.
- Persistent HTTP connections with a connection pool (`keep_alive`).
- Failover between several base URLs.
- Retries with exponential backoff and jitter for transient errors.
- Typed errors mapped from HTTP status codes.
- Rails integration: a shared client that is shut down when the process exits.
- A playground Rails engine for trying the API.

[Unreleased]: https://github.com/octaspace/ruby-sdk/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/octaspace/ruby-sdk/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/octaspace/ruby-sdk/releases/tag/v0.1.0
