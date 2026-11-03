# octaspace

[![Gem Version](https://img.shields.io/gem/v/octaspace)](https://rubygems.org/gems/octaspace)
[![CI](https://github.com/octaspace/ruby-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/octaspace/ruby-sdk/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](MIT-LICENSE)

Official Ruby SDK for the next-generation OctaSpace API.

> **The `next` branch targets the new API**, currently served only by the test stand
> `https://api-dev.octa.space` ([Swagger](https://api-dev.octa.space/swagger)). The production hosts
> (`api.octa.computer`, `api.octa.space`) still serve the legacy API, which the 0.2.x gems support.
> Moving from 0.2.x: see [docs/migration-next.md](docs/migration-next.md).

## Features

- **Typed resources** for every endpoint of the API: compute, render, sessions, hosting, account, network, GPU statistics
- **Read-only models** that tolerate new API fields: `machine.node_number`, `machine[:new_field]`, `machine.to_h`
- **Safe retries**: only reads and the idempotent session stop are retried, honouring `Retry-After`; starts that cost money never are
- **Typed errors** for 400/401/403/404/409/429/5xx with `retry_after` and `rate_limit`
- **Rate limit state** from `RateLimit-*` headers: `client.rate_limit`
- **Session helpers**: `wait_ready` with progress, `wait_stopped`
- **Exact money helpers** for integer micro-USD: `OctaSpace::Money`
- **Keep-alive mode** (persistent connections + pool) and **failover** across several base URLs for reads
- **No secrets in logs**: headers are never logged, access URLs are redacted in `inspect`
- Ruby ≥ 3.3; optional Railtie for Rails apps

## Installation

```ruby
# Gemfile
gem "octaspace", github: "octaspace/ruby-sdk", branch: "next"

# Optional — required for keep_alive: true
gem "faraday-net_http_persistent"
gem "connection_pool"
```

## API key

Create a key in Cube under **Profile → Credentials**. Keys look like `octa_ak_…` and are sent as
`Authorization: Bearer <key>`. Legacy account tokens are refused by the new API (the SDK says so in
the error message).

The key is optional: network and GPU statistics never use it, and machine listings work without it
(but the anonymous listing is cached for up to an hour; with a key it is at most 10 seconds old).
Methods that need a key raise `OctaSpace::AuthenticationError` before sending anything when none is
configured.

## Quick start

```ruby
require "octaspace"

client = OctaSpace::Client.new(api_key: ENV["OCTA_API_KEY"])

client.accounts.balance.formatted                     # => "$2.147661"

machine = client.compute.list.min_by(&:base_price)
uuid = client.compute.start(
  node_number: machine.node_number,                   # e.g. "M95S-WZG8-7"
  image: "ubuntu:24.04",
  disk_size: 20,
  http_ports: [8888],
  envs: {"FOO" => "bar"},
  ssh: true
)

session = client.sessions.wait_ready(uuid, timeout: 600) do |s|
  puts "#{s.status} #{s.progress} #{s.pull_percent}"
end
session.urls                                          # => {"8888" => "https://…"}
session.ssh.endpoint                                  # direct access, or the SSH proxy

client.sessions.logs(uuid, tail: 100).container
client.sessions.stop(uuid)
client.sessions.wait_stopped(uuid)
```

## Resources

| Method | Endpoint | Key | Returns |
|---|---|---|---|
| `network.info` | `GET /network` | no | `Types::Network` |
| `stats.gpu_current(verified:)` | `GET /stats/gpu/current` | no | `Types::GpuMarket` |
| `stats.gpu_history(gpu_name:, verified:, from:, to:, step:)` | `GET /stats/gpu/history` | no | `{model => Types::GpuHistory}` |
| `stats.gpu_locations` | `GET /stats/gpu/locations` | no | `[Types::GpuLocation]` |
| `accounts.balance` | `GET /accounts/balance` | yes | `Types::Balance` |
| `compute.list` | `GET /services/compute` | optional | `[Types::ComputeMachine]` |
| `compute.start(node_number:, image:, …)` | `POST /services/compute` (object) | yes | session uuid |
| `compute.start_batch(items)` | `POST /services/compute` (array) | yes | `[Types::BatchResult]` |
| `compute.restart(uuid, **params)` | `POST /services/compute/{uuid}/restart` | yes | session uuid |
| `render.list` | `GET /services/render` | optional | `[Types::RenderMachine]` |
| `render.start(node_number:)` | `POST /services/render` (object) | yes | session uuid |
| `render.start_batch(items)` | `POST /services/render` (array) | yes | `[Types::BatchResult]` |
| `sessions.list` | `GET /sessions` | yes | `[Types::Session]` |
| `sessions.get(uuid)` | `GET /services/{uuid}/info` | yes | `Types::Session` |
| `sessions.logs(uuid, tail:)` | `GET /services/{uuid}/logs` | yes | `Types::SessionLogs` |
| `sessions.stop(uuid)` | `POST /services/{uuid}/stop` | yes | session uuid |
| `sessions.wait_ready(uuid, timeout:, interval:)` | polls `get` | yes | `Types::Session` |
| `sessions.wait_stopped(uuid, timeout:, interval:)` | polls `get` until 404 | yes | `true` |
| `hosting.nodes` | `GET /hosting/nodes` | yes | `[Types::HostingNode]` |
| `hosting.set_prices(number, base:, storage:, traffic:, min_rent_minutes:)` | `PATCH /hosting/nodes/{number}/prices` | yes | `nil` |

### Models

Every response is wrapped in a read-only model with readers for the fields of the API spec. Fields
the SDK does not know yet are kept: read them with `model[:field]`, and get the parsed JSON with
`model.to_h`. Models support pattern matching:

```ruby
case client.sessions.get(uuid)
in OctaSpace::Types::ComputeSession => s if s.ready?
  puts s.public_ip
in {status: "starting", progress:}
  puts progress
end
```

`sessions.list` and `sessions.get` return a `ComputeSession` or a `RenderSession` by the `service`
field, and a plain `Types::Session` for a service the SDK does not know yet.

### Units

| What | Unit | Helper |
|---|---|---|
| Prices, charges, balance | integer micro-USD (1 = $0.000001) | `OctaSpace::Money` |
| `started_at` (sessions), `ts` (logs) | Unix milliseconds | `started_time`, `time` |
| `at` (network, stats), `activity.started_at` | Unix seconds | `time`, `started_time` |
| `online_at` (hosting) | ISO 8601 string | `online_time` |
| `net_down_mbps`, `net_up_mbps` | Mbit/s (0 in listings = not measured) | — |
| `memory`, `disk` in listings | bytes (free) | — |
| `node_hw.disk` in sessions | GB (rented) | — |

```ruby
OctaSpace::Money.format(100)          # => "$0.000100"
OctaSpace::Money.to_usd(1_250_000)    # => (5/4)
OctaSpace::Money.from_usd("0.25")     # => 250000
client.hosting.set_prices("M95S-WZG8-7", base: OctaSpace::Money.from_usd("0.25"), min_rent_minutes: 15)
```

### Batch starts

```ruby
results = client.compute.start_batch([
  {id: "a", node_number: "M95S-WZG8-7", image: "ubuntu:24.04"},
  {id: "b", node_number: "7R2S-S05E-S", image: "ubuntu:24.04"}
])
results.each { |r| puts r.started? ? "#{r.id}: #{r.uuid}" : "#{r.id}: #{r.reason}" }
```

Each item is validated on its own; a failed item is reported in its result, not raised. Items without
an `id` get their position in the array. A single `start` raises instead
(`OctaSpace::ValidationError` with the API's reason).

### Restarting a compute session

```ruby
client.compute.restart(uuid)                          # same parameters as before
client.compute.restart(uuid, disk_size: 20, envs: {"FOO" => "baz"}, http_ports: [8888], ssh: true)
```

⚠️ With parameters, a restart **replaces all of them**. Every omitted parameter gets a fixed default,
not its current value: `disk_size` becomes 1 GB, `entrypoint`/`args` come from the image, and
`envs`, ports and `startup_script` are dropped. The API does not report a session's launch parameters,
so pass the full set you want. A session can be restarted once per 5 minutes and 6 times per hour
(`OctaSpace::RateLimitError` with `retry_after`); while it is still starting or restarting the API
answers `OctaSpace::ConflictError`.

### Sessions and SSH

The API reports running sessions only. Once a session stops, `get`, `logs` and `stop` raise
`OctaSpace::NotFoundError`; there is no session history. `stop` is asynchronous: wait for the 404 with
`wait_stopped`. A session stopped before its `min_rent_minutes` is charged for that long.

`ssh.web` (web terminal) contains credentials, and `fm` (file manager) needs no login: treat both as
secrets. `inspect` redacts them. `ssh.*.user` comes from the image, so pass it to `ssh` as a separate
argument after `--`: `ssh -p PORT -l USER -- HOST`.

## Errors

```
OctaSpace::Error
├── ConfigurationError
├── NetworkError
│   ├── ConnectionError
│   └── TimeoutError
│       └── WaitTimeoutError          wait_ready / wait_stopped ran out of time
└── ApiError                          status, message, body, retry_after, rate_limit, request_id
    ├── ValidationError               400, 422
    ├── AuthenticationError           401, or no key configured
    ├── PermissionError               403
    ├── NotFoundError                 404 (a session that stopped)
    │   └── SessionStoppedError       the session stopped during wait_ready
    ├── ConflictError                 409
    ├── RateLimitError                429
    └── ServerError                   5xx
        ├── BadGatewayError           502
        ├── ServiceUnavailableError   503 (e.g. render temporarily unavailable)
        └── GatewayTimeoutError       504
```

```ruby
begin
  client.compute.restart(uuid)
rescue OctaSpace::RateLimitError => e
  puts "#{e.message} (wait #{e.retry_after} s)"
rescue OctaSpace::ConflictError => e
  puts e.message                       # "Session is still starting or restarting"
end
```

### Retries and rate limits

- GET requests and `sessions.stop` are retried on network errors and on 429/502/503/504, with
  exponential backoff and jitter, honouring `Retry-After` up to `max_retry_after` (60 s). A longer wait
  (such as the restart cooldown) is raised to the caller instead.
- `compute.start`, `compute.restart`, `render.start` and the batches are **never** retried: they cost
  money and have their own limit (10 a minute).
- With several `base_urls`, GET requests fail over to the next URL on network errors. Requests that
  change state go to one URL only.
- Limits: 60 requests a minute per IP without a key, 300 per account with one.
  `client.rate_limit` is the `RateLimit-*` state of the latest response.

## Configuration

```ruby
OctaSpace.configure do |config|
  config.api_key = ENV["OCTA_API_KEY"]
  config.base_url = ENV.fetch("OCTA_API_URL", OctaSpace::DEFAULT_BASE_URL)
end

client = OctaSpace.client                   # shared client built from the global configuration
other = OctaSpace::Client.new(api_key: "octa_ak_…", read_timeout: 60)
```

| Option | Default | Description |
|---|---|---|
| `api_key` | `nil` | `octa_ak_…` key; a pasted `Bearer …` value is accepted |
| `base_url` | `https://api-dev.octa.space` | API endpoint |
| `base_urls` | `nil` | Ordered endpoints; GET requests fail over between them |
| `open_timeout` / `read_timeout` / `write_timeout` | `10` / `30` / `30` | Seconds |
| `max_retries` | `2` | Retries of GET and idempotent requests |
| `retry_interval` / `backoff_factor` / `max_retry_interval` | `0.5` / `2.0` / `10.0` | Backoff, seconds |
| `max_retry_after` | `60` | Longest `Retry-After` waited for automatically |
| `keep_alive` | `false` | Persistent connections + pool (needs the optional gems) |
| `pool_size` / `pool_timeout` / `idle_timeout` | `5` / `5` / `60` | Keep-alive pool |
| `ssl_verify` | `true` | Verify TLS certificates |
| `on_request` | `nil` | `callable(hash)` before each attempt: `:method, :url, :path, :params, :attempt` |
| `on_response` | `nil` | `callable(OctaSpace::Response)` after each response |
| `logger` / `log_level` | `nil` / `:info` | One line per request; headers and bodies are never logged |
| `user_agent` | `octaspace-ruby/<version> Ruby/<version>` | `User-Agent` header |

### Rails

```ruby
# config/initializers/octaspace.rb
OctaSpace.configure do |config|
  config.api_key = Rails.application.credentials.dig(:octaspace, :api_key)
  config.keep_alive = true
  config.pool_size = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
  config.logger = Rails.logger
end
```

`OctaSpace.client` returns a shared client; the Railtie shuts its connection pools down when the
process exits.

## Development

```bash
bundle install
bundle exec rake test          # unit tests (WebMock, no network)
bundle exec standardrb         # lint
bundle exec bundle-audit check --update
bin/console                    # IRB with the gem loaded
bin/smoke                      # live read-only checks against api-dev
OCTA_API_KEY=octa_ak_… bin/smoke --compute M95S-WZG8-7   # plus a paid start/stop round trip
```

Work on the new API happens on the `next` branch: see [docs/GIT_WORKFLOW_NEXT.md](docs/GIT_WORKFLOW_NEXT.md).
Releases: [PUBLISHING.md](PUBLISHING.md).

## License

[MIT](MIT-LICENSE) © OctaSpace Team
