# octaspace

[![Gem Version](https://img.shields.io/gem/v/octaspace)](https://rubygems.org/gems/octaspace)
[![CI](https://github.com/octaspace/ruby-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/octaspace/ruby-sdk/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](MIT-LICENSE)

Official Ruby SDK for the [OctaSpace API](https://api-dev.octa.space/swagger). Requires Ruby 3.3 or newer.

## Installation

```ruby
# Gemfile
gem "octaspace"
```

## API key

Create a key in Cube under **Profile → Credentials**. Keys start with `octa_ak_` and are sent as
`Authorization: Bearer <key>`.

The key is optional for public data: network and GPU statistics never use it, and machine listings
work without it (the anonymous listing may be up to an hour old; with a key it is at most 10 seconds
old). Methods that need a key raise `OctaSpace::AuthenticationError` before sending a request when
none is configured.

## Quick start

```ruby
require "octaspace"

client = OctaSpace::Client.new(api_key: ENV["OCTA_API_KEY"])

client.accounts.balance.formatted                     # => "$12.500000"

machine = client.compute.list.min_by(&:base_price)
uuid = client.compute.start(
  node_number: machine.node_number,
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
session.ssh.endpoint                                  # direct SSH, or the SSH proxy

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
| `compute.start(node_number:, image:, …)` | `POST /services/compute` | yes | session uuid |
| `compute.start_batch(items)` | `POST /services/compute` | yes | `[Types::BatchResult]` |
| `compute.restart(uuid, **params)` | `POST /services/compute/{uuid}/restart` | yes | session uuid |
| `render.list` | `GET /services/render` | optional | `[Types::RenderMachine]` |
| `render.start(node_number:)` | `POST /services/render` | yes | session uuid |
| `render.start_batch(items)` | `POST /services/render` | yes | `[Types::BatchResult]` |
| `sessions.list` | `GET /sessions` | yes | `[Types::Session]` |
| `sessions.get(uuid)` | `GET /services/{uuid}/info` | yes | `Types::Session` |
| `sessions.logs(uuid, tail:)` | `GET /services/{uuid}/logs` | yes | `Types::SessionLogs` |
| `sessions.stop(uuid)` | `POST /services/{uuid}/stop` | yes | session uuid |
| `sessions.wait_ready(uuid, timeout:, interval:)` | polls `sessions.get` | yes | `Types::Session` |
| `sessions.wait_stopped(uuid, timeout:, interval:)` | polls `sessions.get` | yes | `true` |
| `hosting.nodes` | `GET /hosting/nodes` | yes | `[Types::HostingNode]` |
| `hosting.set_prices(number, base:, storage:, traffic:, min_rent_minutes:)` | `PATCH /hosting/nodes/{number}/prices` | yes | `nil` |

Responses are read-only models with readers for the documented fields. Fields without a reader are
still available as `model[:field]`, and `model.to_h` returns the parsed JSON. `sessions.list` and
`sessions.get` return a `Types::ComputeSession` or a `Types::RenderSession`, chosen by the `service`
field.

## Units

| What | Unit | Helper |
|---|---|---|
| Prices, charges, balance | integer micro-USD (1 = $0.000001) | `OctaSpace::Money` |
| `started_at` (sessions), `ts` (logs) | Unix milliseconds | `started_time`, `time` |
| `at` (network, stats) | Unix seconds | `time` |
| `online_at` (hosting) | ISO 8601 | `online_time` |
| `net_down_mbps`, `net_up_mbps` | Mbit/s (0 in listings: not measured) | |
| `memory`, `disk` in listings | free bytes | |
| `node_hw.disk` in sessions | rented GB | |

```ruby
OctaSpace::Money.format(100)          # => "$0.000100"
OctaSpace::Money.from_usd("0.25")     # => 250000
client.hosting.set_prices("7KQ4-M2XD-4", base: OctaSpace::Money.from_usd("0.25"), min_rent_minutes: 15)
```

## Starting several sessions

```ruby
results = client.compute.start_batch([
  {id: "a", node_number: "7KQ4-M2XD-4", image: "ubuntu:24.04"},
  {id: "b", node_number: "M2XD-7KQ4-0", image: "ubuntu:24.04"}
])
results.each { |r| puts r.started? ? "#{r.id}: #{r.uuid}" : "#{r.id}: #{r.reason}" }
```

Each item succeeds or fails on its own and the failure is reported in its result. Items without an
`id` get their position in the array. A single `start` raises `OctaSpace::ValidationError` instead.

## Restarting a compute session

```ruby
client.compute.restart(uuid)                          # same parameters as before
client.compute.restart(uuid, disk_size: 20, envs: {"FOO" => "baz"}, http_ports: [8888], ssh: true)
```

With parameters, a restart **replaces all of them**: every omitted parameter gets its default, not its
current value (`disk_size` becomes 1 GB; `envs`, ports and `startup_script` are dropped). Pass the
full set you want. A session can be restarted once per 5 minutes and 6 times per hour
(`OctaSpace::RateLimitError`, see `retry_after`); while it is still starting or restarting, the API
answers `OctaSpace::ConflictError`.

## Sessions and SSH

Only running sessions are reported. Once a session stops, `get`, `logs` and `stop` raise
`OctaSpace::NotFoundError`. `stop` is asynchronous; `wait_stopped` waits until the session is gone. A
session stopped before its `min_rent_minutes` is charged for that long.

`ssh.web` (web terminal) contains credentials and `fm` (file manager) needs no login, so treat both
as secrets; `inspect` hides them. `ssh.*.user` comes from the image: pass it to `ssh` as a separate
argument, after `--`: `ssh -p PORT -l USER -- HOST`.

## Errors

```
OctaSpace::Error
├── ConfigurationError
├── NetworkError
│   ├── ConnectionError
│   └── TimeoutError
│       └── WaitTimeoutError          wait_ready / wait_stopped timed out
└── ApiError                          status, message, body, retry_after, rate_limit, request_id
    ├── ValidationError               400, 422
    ├── AuthenticationError           401, or no API key configured
    ├── PermissionError               403
    ├── NotFoundError                 404
    │   └── SessionStoppedError       the session stopped during wait_ready
    ├── ConflictError                 409
    ├── RateLimitError                429
    └── ServerError                   5xx
        ├── BadGatewayError           502
        ├── ServiceUnavailableError   503
        └── GatewayTimeoutError       504
```

GET requests and `sessions.stop` are retried on network errors and on 429/502/503/504, honouring
`Retry-After` up to 60 seconds; a longer wait is raised to the caller. Starts and restarts are never
retried. `client.rate_limit` returns the `RateLimit-*` values of the latest response.

## Configuration

```ruby
OctaSpace.configure do |config|
  config.api_key = ENV["OCTA_API_KEY"]
end

client = OctaSpace.client                                       # shared client
other = OctaSpace::Client.new(api_key: "octa_ak_…", read_timeout: 60)
```

| Option | Default | Description |
|---|---|---|
| `api_key` | `nil` | API key |
| `base_url` | `https://api-dev.octa.space` | API endpoint |
| `base_urls` | `nil` | Several endpoints; GET requests fail over between them on network errors |
| `open_timeout` / `read_timeout` / `write_timeout` | `10` / `30` / `30` | Seconds |
| `max_retries` | `2` | Retries of GET requests and `sessions.stop` |
| `keep_alive` | `false` | Persistent connections; add `faraday-net_http_persistent` and `connection_pool` to your Gemfile |
| `pool_size` / `pool_timeout` / `idle_timeout` | `5` / `5` / `60` | Connection pool (keep-alive) |
| `on_request` / `on_response` | `nil` | Callables run before each request and after each response |
| `logger` / `log_level` | `nil` / `:info` | One line per request; headers and bodies are never logged |

In a Rails app, put the `configure` block in an initializer. The shared client's connections are
closed when the process exits.

## License

[MIT](MIT-LICENSE)
