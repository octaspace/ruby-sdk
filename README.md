# OctaSpace Ruby SDK

Official Ruby client for the [OctaSpace API](https://api.octa.space/api-docs).

## Features

- Resource-oriented API — `client.nodes.list`, `client.services.session(uuid).stop`
- **Keep-alive mode** — persistent connections with configurable connection pool
- **URL rotation / failover** — automatic failover across multiple API endpoints
- Retry with exponential backoff + jitter (configurable)
- `on_request` / `on_response` hooks for logging and APM
- Optional Rails integration (Railtie)
- Playground app in `test/dummy`

## Installation

```ruby
# Gemfile
gem "octaspace"

# Optional: keep-alive mode requires these additional gems
gem "faraday-net_http_persistent"
gem "connection_pool"
```

## Quick Start

```ruby
require "octaspace"

client = OctaSpace::Client.new(api_key: ENV["OCTA_API_KEY"])

# Accounts
client.accounts.profile
client.accounts.balance

# Nodes
client.nodes.list
client.nodes.find(123)
client.nodes.reboot(123)
client.nodes.update_prices(123, gpu_hour: 0.5, cpu_hour: 0.1)

# Sessions
client.sessions.list

# Session proxy pattern
session = client.services.session("uuid-here")
session.info
session.logs
session.stop(score: 5)

# Services
client.services.mr.list
client.services.vpn.create(node_id: 123)

# Idle Jobs
client.idle_jobs.list
client.idle_jobs.create(node_id: 1, command: "sleep 60")
```

## Configuration

### Global (Rails initializer)

```ruby
# config/initializers/octaspace.rb
OctaSpace.configure do |config|
  config.api_key    = ENV["OCTA_API_KEY"]
  config.keep_alive = true
  config.pool_size  = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
  config.logger     = Rails.logger
end
```

### Per-client overrides

```ruby
client = OctaSpace::Client.new(
  api_key:      ENV["OCTA_API_KEY"],
  keep_alive:   true,
  pool_size:    10,
  read_timeout: 60
)
```

### All configuration options

| Option | Default | Description |
|---|---|---|
| `api_key` | `nil` | API key for Authorization header |
| `base_url` | `https://api.octa.space` | API base URL |
| `base_urls` | `nil` | Multiple URLs — enables failover |
| `keep_alive` | `false` | Persistent connections + pool |
| `pool_size` | `5` | Connection pool size |
| `pool_timeout` | `5` | Seconds to wait for pool connection |
| `idle_timeout` | `60` | Seconds before idle connection closes |
| `open_timeout` | `10` | Seconds to open connection |
| `read_timeout` | `30` | Seconds to read response |
| `max_retries` | `2` | Retry attempts on transient failures |
| `ssl_verify` | `true` | Verify SSL certificates |
| `on_request` | `nil` | Callable invoked before each request |
| `on_response` | `nil` | Callable invoked after each response |
| `logger` | `nil` | Ruby Logger instance |

## Keep-Alive Mode

```ruby
# Requires: faraday-net_http_persistent + connection_pool in Gemfile
client = OctaSpace::Client.new(
  api_key:    ENV["OCTA_API_KEY"],
  keep_alive: true,
  pool_size:  ENV.fetch("RAILS_MAX_THREADS", 5).to_i,
  idle_timeout: 120
)
```

## URL Rotation / Failover

```ruby
client = OctaSpace::Client.new(
  api_key:   ENV["OCTA_API_KEY"],
  base_urls: ["https://api.octa.space", "https://api2.octa.space"]
)
```

Failed endpoints enter a 30-second cooldown before being re-admitted to rotation.

## Hooks

```ruby
OctaSpace.configure do |config|
  config.on_request  = ->(req)  { Rails.logger.debug "→ #{req[:method].upcase} #{req[:path]}" }
  config.on_response = ->(resp) { Rails.logger.debug "← #{resp.status}" }
end
```

## Error Handling

```ruby
begin
  client.nodes.find(999999)
rescue OctaSpace::NotFoundError => e
  puts "Not found (request_id: #{e.request_id})"
rescue OctaSpace::AuthenticationError
  puts "Invalid API key"
rescue OctaSpace::RateLimitError => e
  sleep e.retry_after
  retry
rescue OctaSpace::Error => e
  puts "Error: #{e.message} (HTTP #{e.status})"
end
```

### Error hierarchy

```
OctaSpace::Error
├── ConfigurationError
├── NetworkError
│   ├── ConnectionError
│   └── TimeoutError
└── ApiError
    ├── AuthenticationError  (401)
    ├── PermissionError      (403)
    ├── NotFoundError        (404)
    ├── ValidationError      (422)
    ├── RateLimitError       (429) — #retry_after
    └── ServerError          (5xx)
        ├── BadGatewayError         (502)
        ├── ServiceUnavailableError (503)
        └── GatewayTimeoutError     (504)
```

## Playground

Interactive demo app for manual testing:

```bash
OCTA_API_KEY=your_key bin/playground
# → http://localhost:3000
```

Pages: Account, Nodes, Sessions, Diagnostics (transport stats, URL rotator state).

## Development

```bash
bin/console        # IRB with gem loaded
bundle exec rake   # lint + tests
```

## License

MIT — see [MIT-LICENSE](MIT-LICENSE).
