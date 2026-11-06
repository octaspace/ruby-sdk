# OctaSpace Ruby SDK

[![Gem Version](https://img.shields.io/gem/v/octaspace)](https://rubygems.org/gems/octaspace)
[![CI](https://github.com/octaspace/ruby-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/octaspace/ruby-sdk/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

The official Ruby library for the [OctaSpace](https://octa.space) API. Rent
compute machines and render nodes, manage sessions and the nodes you host, and
read GPU market statistics from Ruby code.

**Contents:** [Installation](#installation) ·
[Quick start](#quick-start) · [Authentication](#authentication) ·
[Handling errors](#handling-errors) · [API overview](#api-overview) ·
[Documentation](#documentation) · [Versioning](#versioning)

## Installation

```bash
bundle add octaspace
```

Requires Ruby 3.3 or later. The only runtime dependency is
[Faraday](https://github.com/lostisland/faraday).

## Quick start

1. [Create an API key](#authentication) and export it:

   ```bash
   export OCTA_API_KEY="octa_ak_..."
   ```

2. Run this program:

   ```ruby
   require "octaspace"

   client = OctaSpace::Client.new(api_key: ENV["OCTA_API_KEY"])

   begin
     balance = client.accounts.balance
     puts "Balance: #{balance.formatted}" # Balance: $12.500000

     client.compute.list.each do |m|
       puts "#{m.node_number} #{m.city} #{OctaSpace::Money.format(m.base_price)} per hour"
     end
   rescue OctaSpace::Error => e
     abort e.message
   end
   ```

Create one client and reuse it: it is safe to share between threads.

## Authentication

The SDK authenticates with an **API key** of your OctaSpace account. You create
and delete API keys in the OctaSpace dashboard:

1. Sign in to the [OctaSpace dashboard](https://cube-dev.octa.space).
2. In the sidebar, open **Account → Credentials**.
3. In the **API Keys** section, click **New key**.
4. Enter a **Label** that tells you where the key is used, for example
   `billing-service`, and click **Create key**.
5. Copy the key. It starts with `octa_ak_`.

> [!IMPORTANT]
> The key is shown in full only once, right after you create it. Copy it
> before you close the dialog. If you lose it, delete it and create a new one.

Pass the key to `OctaSpace::Client.new`. The SDK sends it in the
`Authorization: Bearer <key>` header.

```ruby
client = OctaSpace::Client.new(api_key: ENV["OCTA_API_KEY"])
```

> [!WARNING]
> An API key acts on behalf of your account: it can start sessions that are
> charged to your balance. Keep it out of source code and version control. If
> a key leaks, delete it under **Account → Credentials → API Keys**; every
> program that uses it stops working at once.

The **API Keys** list shows each key's label, its first characters and when it
was last used. Use a separate key for each program or machine, so that you can
delete one without affecting the others. The number of keys per account is
limited; the counter next to **API Keys** shows how many you have.

### Calls without an API key

These methods also work without an API key. Create the client without
`api_key:` to use them anonymously:

| Method | Without a key |
| --- | --- |
| `network.info` | Same result |
| `stats.gpu_current`, `stats.gpu_history`, `stats.gpu_locations` | Same result |
| `compute.list`, `render.list` | Refreshed about once an hour instead of every 10 seconds |

Every other method requires an API key and raises
`OctaSpace::AuthenticationError` without one, before any request is sent.

## Handling errors

Every error the SDK raises is an `OctaSpace::Error`. Rescue the specific class
you can handle:

```ruby
begin
  uuid = client.compute.start(node_number: "7KQ4-M2XD-4", image: "ubuntu:24.04")
rescue OctaSpace::AuthenticationError
  # the API key is missing, wrong or deleted
rescue OctaSpace::ValidationError => e
  # the request was rejected; e.message says why
rescue OctaSpace::RateLimitError => e
  # too many requests; wait e.retry_after seconds
end
```

See [Errors, rate limits and retries](docs/errors-and-reliability.md).

## API overview

| Resource | Dashboard section | Operations | Guide |
| --- | --- | --- | --- |
| `client.compute` | Marketplace → Compute | List machines, start, batch start, restart | [Compute](docs/resources.md#compute) |
| `client.render` | Render → Launch Nodes | List render nodes, start, batch start | [Render](docs/resources.md#render) |
| `client.sessions` | Marketplace → Sessions, Render → Render Nodes | List, get, logs, stop, wait until ready or stopped | [Sessions](docs/sessions.md) |
| `client.hosting` | Hosting → Nodes | Your nodes, set prices | [Hosting](docs/resources.md#hosting) |
| `client.accounts` | Account → Billing | Balance | [Accounts](docs/resources.md#accounts) |
| `client.network` | — | Platform statistics | [Network](docs/resources.md#network) |
| `client.stats` | — | GPU market: current, history, locations | [Stats](docs/resources.md#stats) |

Every class and method is documented on
[RubyDoc.info](https://rubydoc.info/gems/octaspace).

## Documentation

| Guide | Covers |
| --- | --- |
| [Client configuration](docs/getting-started.md) | Options and defaults, timeouts, logging, Rails, keep-alive connections |
| [Resources](docs/resources.md) | Compute, render, hosting, balance, network and GPU statistics |
| [Sessions](docs/sessions.md) | Waiting until ready, connecting, logs, stopping |
| [Errors, rate limits and retries](docs/errors-and-reliability.md) | Error classes, limits, automatic retries |
| [Changelog](CHANGELOG.md) | Changes in each release |

## Versioning

The library follows [Semantic Versioning](https://semver.org). Until version
1.0, a minor release can contain breaking changes; the
[changelog](CHANGELOG.md) marks them as **Breaking**.

## License

[MIT](LICENSE)
