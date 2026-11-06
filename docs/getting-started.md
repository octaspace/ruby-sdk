# Client configuration

[← Back to README](../README.md)

**On this page:** [Creating a client](#creating-a-client) ·
[Options](#options) · [Timeouts](#timeouts) · [Logging and hooks](#logging-and-hooks) ·
[Rails](#rails) · [Keep-alive connections](#keep-alive-connections) ·
[Several hosts](#several-hosts)

## Creating a client

`OctaSpace::Client.new` takes your [API key](../README.md#authentication) and
optional settings. Create one client and reuse it: it is safe to share between
threads.

```ruby
client = OctaSpace::Client.new(
  api_key: ENV["OCTA_API_KEY"],
  read_timeout: 15,
  max_retries: 3,
  user_agent: "my-service/1.0",
  logger: Logger.new($stdout)
)
```

To set options once for the whole process, use `OctaSpace.configure`.
`OctaSpace.client` returns a client built from that configuration and reuses
it on every call:

```ruby
OctaSpace.configure do |config|
  config.api_key = ENV["OCTA_API_KEY"]
  config.read_timeout = 15
end

OctaSpace.client.accounts.balance
```

Options passed to `Client.new` override the global configuration for that
client only.

## Options

| Option | Default | Effect |
| --- | --- | --- |
| `api_key` | `nil` | Your API key; without it only the [calls without a key](../README.md#calls-without-an-api-key) work |
| `open_timeout` | `10` | Seconds to wait for a connection |
| `read_timeout` | `30` | Seconds to wait for a response |
| `write_timeout` | `30` | Seconds to wait while sending a request |
| `max_retries` | `2` | Retries of failed requests that are safe to repeat; `0` turns them off. See [Retries](errors-and-reliability.md#retries) |
| `retry_interval` / `backoff_factor` / `max_retry_interval` | `0.5` / `2.0` / `10.0` | Backoff between retries, in seconds |
| `max_retry_after` | `60` | Longest `Retry-After` in seconds the SDK waits for; a longer wait raises the error at once |
| `user_agent` | `octaspace-ruby/<version> Ruby/<version>` | Value of the `User-Agent` header |
| `logger` / `log_level` | `nil` / `:info` | Logs one line per request, see [below](#logging-and-hooks) |
| `on_request` / `on_response` | `nil` | Callables run before each request and after each response |
| `keep_alive` | `false` | Persistent connections, see [below](#keep-alive-connections) |
| `pool_size` / `pool_timeout` / `idle_timeout` | `5` / `5` / `60` | Connection pool of `keep_alive` |
| `ssl_verify` | `true` | Verify the server's TLS certificate |
| `base_url` | `OctaSpace::DEFAULT_BASE_URL` | Another API host |
| `base_urls` | `nil` | Several API hosts, see [below](#several-hosts) |

## Timeouts

The timeouts apply to each attempt of a request. A request that is retried can
take longer in total; set `max_retries: 0` if you need a hard limit.

A request that takes too long raises `OctaSpace::TimeoutError`.

## Logging and hooks

Pass any `Logger`. The SDK logs the method, URL, status and duration of each
request at `log_level`:

```text
[OctaSpace] GET https://…/accounts/balance -> 200 (84 ms)
```

> [!NOTE]
> The API key, other headers and request and response bodies are never logged.

`on_request` receives a Hash with `:method`, `:url`, `:path`, `:params` and
`:attempt`; `on_response` receives the `OctaSpace::Response`. Use them for
metrics or tracing:

```ruby
client = OctaSpace::Client.new(
  api_key: ENV["OCTA_API_KEY"],
  on_request: ->(req) { puts "-> #{req[:method].upcase} #{req[:path]} (attempt #{req[:attempt]})" },
  on_response: ->(resp) { puts "<- #{resp.status} #{resp.request_id}" }
)
```

## Rails

Put the configuration in an initializer and call `OctaSpace.client` where you
need it:

```ruby
# config/initializers/octaspace.rb
OctaSpace.configure do |config|
  config.api_key = Rails.application.credentials.dig(:octaspace, :api_key)
  config.logger = Rails.logger
end
```

The SDK closes the shared client's connections when the Rails process exits.

## Keep-alive connections

With `keep_alive: true` the client keeps connections open and reuses them from
a pool, which saves a TLS handshake per request. Add these gems to your
Gemfile:

```ruby
gem "faraday-net_http_persistent"
gem "connection_pool"
```

```ruby
client = OctaSpace::Client.new(
  api_key: ENV["OCTA_API_KEY"],
  keep_alive: true,
  pool_size: ENV.fetch("RAILS_MAX_THREADS", 5).to_i
)
```

Without those gems, `keep_alive: true` raises `OctaSpace::ConfigurationError`.
Call `client.shutdown` to close the connections of a client you no longer use.

## Several hosts

`base_urls` takes a list of API hosts, for example the default one and a proxy
of your own. Requests are spread over the hosts in turn. A GET request moves to
the next host only when the current one cannot be reached (DNS, connection or
TLS failure, timeout); an HTTP error response, including 5xx, is raised as it
is. A request that changes something (starting, restarting or stopping a
session, setting prices) is sent to one host only, so that it cannot run
twice.
