# octaspace

[![Gem Version](https://img.shields.io/gem/v/octaspace)](https://rubygems.org/gems/octaspace)
[![CI](https://github.com/octaspace/ruby-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/octaspace/ruby-sdk/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](MIT-LICENSE)

Official Ruby SDK for the [OctaSpace API](https://api.octa.space/api-docs).

## Features

- **Resource-oriented API** — `client.nodes.list`, `client.services.session(uuid).stop`
- **Keep-alive mode** — persistent connections via `faraday-net_http_persistent` + `connection_pool`
- **URL rotation / failover** — round-robin across multiple endpoints with per-URL cooldown
- **Retry with exponential backoff + jitter** — configurable retries on transient failures
- **Typed error hierarchy** — 12 exception classes mapped from HTTP status codes
- **`on_request` / `on_response` hooks** — for logging, tracing, APM
- **Rails integration** — Railtie, shared client, graceful shutdown at_exit
- **Playground app** — `bin/playground` with live diagnostics page
- **Ruby ≥ 3.2**, Rails 7.1 / 7.2 / 8.0

## Installation

```ruby
# Gemfile
gem "octaspace"

# Optional — required for keep_alive: true
gem "faraday-net_http_persistent"
gem "connection_pool"
```

```ruby
bundle install
```

## Quick Start

```ruby
require "octaspace"

# Public endpoints (no API key required)
client = OctaSpace::Client.new
client.network.info                                    # GET /network

# Authenticated endpoints
client = OctaSpace::Client.new(api_key: ENV["OCTA_API_KEY"])

# Accounts
client.accounts.profile   # GET /accounts
client.accounts.balance   # GET /accounts/balance

# Nodes
client.nodes.list                                      # GET /nodes
client.nodes.find(123)                                 # GET /nodes/:id
client.nodes.reboot(123)                               # GET /nodes/:id/reboot
client.nodes.update_prices(123, gpu_hour: 0.5)         # PATCH /nodes/:id/prices

# Sessions (list)
client.sessions.list                                   # GET /sessions

# Session proxy — operations on a specific session
session = client.services.session("uuid-here")
session.info                    # GET /services/:uuid/info
session.logs                    # GET /services/:uuid/logs
session.stop(score: 5)          # POST /services/:uuid/stop

# Services
client.services.mr.list                                # GET /services/mr
client.services.mr.create(
  node_id: 1,
  disk_size: 10,
  image: "ubuntu:24.04",
  app: "249b4cb3-3db1-4c06-98a4-772ba88cd81c"
)                                                     # POST /services/mr
client.services.vpn.list                               # GET /services/vpn
client.services.vpn.create(node_id: 1, subkind: "wg") # POST /services/vpn
client.services.render.list                            # GET /services/render
client.services.render.create(node_id: 1, disk_size: 100) # POST /services/render

# Apps
client.apps.list                                       # GET /apps

# Network
client.network.info                                    # GET /network

# Idle Jobs
client.idle_jobs.find(node_id: 69, job_id: 42)        # GET /idle_jobs/:node_id/:job_id
client.idle_jobs.logs(node_id: 69, job_id: 42)        # GET /idle_jobs/:node_id/:job_id/logs
```

## Rails Integration

### Initializer

```ruby
# config/initializers/octaspace.rb
OctaSpace.configure do |config|
  config.api_key    = ENV["OCTA_API_KEY"]
  config.keep_alive = true
  config.pool_size  = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
  config.logger     = Rails.logger
end
```

### Shared client

`OctaSpace.client` (called without arguments) returns a **lazily-initialized shared client** built from global configuration. It is safe to call it on every request:

```ruby
# app/controllers/application_controller.rb
def octa_client
  OctaSpace.client   # returns the same instance each time — no new connections
end
```

Pass arguments to create a **one-off client** instead (e.g., for per-user API keys):

```ruby
OctaSpace.client(api_key: current_user.octa_api_key)   # new client, not cached
```

### Graceful shutdown

The Railtie registers an `at_exit` hook that automatically shuts down the shared client's connection pool when the Rails process stops. No manual cleanup needed.

## Configuration Reference

| Option | Default | Description |
|---|---|---|
| `api_key` | `nil` | API key sent as `Authorization` header (optional for public endpoints) |
| `base_url` | `https://api.octa.space` | Single API endpoint |
| `base_urls` | `nil` | Multiple endpoints — enables URL rotation |
| `keep_alive` | `false` | Persistent HTTP connections + pool |
| `pool_size` | `5` | Connection pool size (keep-alive mode) |
| `pool_timeout` | `5` | Seconds to wait for a pool slot |
| `idle_timeout` | `60` | Seconds before an idle connection closes |
| `open_timeout` | `10` | Seconds to open TCP connection |
| `read_timeout` | `30` | Seconds to read response |
| `write_timeout` | `30` | Seconds to write request body |
| `max_retries` | `2` | Retry attempts on transient failures |
| `retry_interval` | `0.5` | Base retry interval in seconds |
| `backoff_factor` | `2.0` | Exponential backoff multiplier |
| `ssl_verify` | `true` | Verify SSL certificates |
| `on_request` | `nil` | `callable(req_hash)` — before each request |
| `on_response` | `nil` | `callable(response)` — after each response |
| `logger` | `nil` | Ruby `Logger` instance |
| `log_level` | `:info` | Log level |
| `user_agent` | auto | `User-Agent` header value |

`persistent` is an alias for `keep_alive` for compatibility with Cube internals.

## Keep-Alive Mode

Requires `faraday-net_http_persistent` and `connection_pool` in your Gemfile.

```ruby
client = OctaSpace::Client.new(
  api_key:      ENV["OCTA_API_KEY"],
  keep_alive:   true,
  pool_size:    ENV.fetch("RAILS_MAX_THREADS", 5).to_i,
  idle_timeout: 120
)

# Diagnostics
client.transport_stats
# => { mode: :persistent, pools: { "https://api.octa.space" => { size: 5, available: 4 } } }

# Explicit shutdown (optional — Railtie does this automatically in Rails)
client.shutdown
```

## URL Rotation / Failover

```ruby
client = OctaSpace::Client.new(
  api_key:   ENV["OCTA_API_KEY"],
  base_urls: ["https://api.octa.space", "https://api2.octa.space"]
)
```

- Requests are distributed round-robin across healthy endpoints.
- If an endpoint raises a connection or timeout error, it enters a **30-second cooldown** and traffic shifts to the remaining endpoints.
- After cooldown, the endpoint is re-admitted automatically.

## Hooks

```ruby
OctaSpace.configure do |config|
  config.on_request  = ->(req)  { Rails.logger.debug "→ #{req[:method].upcase} #{req[:path]}" }
  config.on_response = ->(resp) { Rails.logger.debug "← #{resp.status} (#{resp.request_id})" }
end
```

`on_request` receives `{ method:, path:, params: }`.
`on_response` receives an `OctaSpace::Response` instance.

## Error Handling

```ruby
begin
  client.nodes.find(999_999)
rescue OctaSpace::NotFoundError => e
  puts "Not found — request_id: #{e.request_id}"
rescue OctaSpace::AuthenticationError
  puts "Invalid API key"
rescue OctaSpace::RateLimitError => e
  sleep e.retry_after
  retry
rescue OctaSpace::ConnectionError, OctaSpace::TimeoutError => e
  puts "Network error: #{e.message}"
rescue OctaSpace::Error => e
  puts "API error #{e.status}: #{e.message}"
end
```

### Error hierarchy

```
OctaSpace::Error
├── ConfigurationError          — missing gems, invalid config
├── NetworkError                — no HTTP response received
│   ├── ConnectionError         — TCP connection refused / failed
│   └── TimeoutError            — open/read timeout
└── ApiError                    — HTTP response received with error status
    ├── AuthenticationError     401
    ├── PermissionError         403
    ├── NotFoundError           404
    ├── ValidationError         422
    ├── RateLimitError          429  → #retry_after (seconds)
    └── ServerError             5xx
        ├── BadGatewayError     502
        ├── ServiceUnavailableError  503
        └── GatewayTimeoutError 504
```

All `ApiError` subclasses expose:

- `#status` — HTTP status code
- `#request_id` — value of `X-Request-Id` response header
- `#response` — the raw `OctaSpace::Response` object

## Types (Value Objects)

The `OctaSpace::Types` namespace provides immutable `Data.define` value objects for domain entities. They are **not** returned by default — resources return raw `response.data` (Hash/Array). Use them explicitly when you want structured objects:

```ruby
response = client.nodes.find(123)
node = OctaSpace::Types::Node.new(**response.data.transform_keys(&:to_sym))

node.online?   # => true / false
node.state     # => "online"
node.id        # => 123
```

Available types: `Node`, `Account`, `Balance`, `Session`.

## Playground App

Interactive demo for manual testing against a real API key:

```bash
OCTA_API_KEY=your_key bin/playground
# → http://localhost:3000
```

Pages:

| Route | Content |
|---|---|
| `/playground/account` | Profile + balance |
| `/playground/nodes` | Node list with state badges |
| `/playground/sessions` | Active sessions |
| `/playground/services` | Machine Rentals + VPN sessions |
| `/playground/diagnostics` | Transport mode, pool stats, URL rotator state (auto-refresh every 5s) |

## Development

### Gem Development

```bash
bin/console            # IRB with gem loaded
bundle exec standardrb  # lint (StandardRB)
bundle exec rake test   # tests only
```

### Local Standalone Testing

You can verify the gem in a clean Ruby environment without Rails:

1. Build the gem: `gem build octaspace.gemspec`
2. Install it locally: `gem install ./octaspace-0.1.0.gem`
3. Test in IRB:

```ruby
irb
> require 'octaspace'
> client = OctaSpace::Client.new # Test public endpoints
> client.network.info
> client_auth = OctaSpace::Client.new(api_key: "token")  # Test authenticated client
> client_auth.accounts.profile.data # Retrieving profile data (email, ID, etc.)
```

### Running tests against multiple Rails versions

```bash
bundle exec appraisal rails-7-1 rake test
bundle exec appraisal rails-7-2 rake test
bundle exec appraisal rails-8-0 rake test
```

### Dummy Application (Playground)

The repository includes a Rails "Dummy" application for manual testing and UI prototyping. It is located in `test/dummy`.`.

To run the dummy app:

1. Ensure you have an API key: `export OCTA_API_KEY=your_key`
2. Run the playground script: `bin/playground` (starts Puma on port 3000)
3. Visit `http://localhost:3000/playground/diagnostics`

You can also run it manually from the directory:

```bash
cd test/dummy
bin/rails server
```

The dummy app is configured to use the local version of the gem. It is **not** included in the published gem package.

## Packaging and Publishing

See [PUBLISHING.md](PUBLISHING.md) for instructions on how to package and release new versions of the gem.

## License

[MIT](MIT-LICENSE) © OctaSpace Team
