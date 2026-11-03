# Migrating from 0.2.x (legacy API) to 0.3 (next API)

0.3 targets the next-generation OctaSpace API and does not work with the legacy one: the two APIs
differ in authentication, identifiers, money units and most payloads. Keep 0.2.x for code that still
talks to the legacy production hosts.

## Client and authentication

| 0.2.x | 0.3 |
|---|---|
| Default `base_url` `https://api.octa.space` | `https://api-dev.octa.space` (`OctaSpace::BASE_URL_DEV`), the test stand of the new API |
| `Authorization: <api_key>` | `Authorization: Bearer <api_key>` |
| Account token (64 hex characters) | API key `octa_ak_…` from Cube → Profile → Credentials; legacy tokens are refused |
| Resource methods return `OctaSpace::Response` | They return typed models (`Types::*`), a uuid, or `nil` |
| `response.data` | `model.to_h` (raw JSON) or `model[:field]` |

## Resources

| 0.2.x | 0.3 |
|---|---|
| `accounts.profile`, `accounts.generate_wallet` | removed (no public endpoint; `accounts.balance` is the way to check a key) |
| `accounts.balance` → `{balance}` in Wei | `accounts.balance` → `Types::Balance` (`balance` integer micro-USD, `currency`, `decimals`) |
| `nodes.list`, `nodes.find(id)` | `hosting.nodes` (online nodes of the account only, no per-node endpoint) |
| `nodes.update_prices(id, …)` | `hosting.set_prices(number, base:, storage:, traffic:, min_rent_minutes:)` (integer micro-USD) |
| `nodes.download_ident`, `download_logs`, `reboot` | removed |
| `services.mr.list` | `compute.list` |
| `services.mr.create(node_id:, …)` | `compute.start(node_number:, image:, …)` → uuid; `compute.start_batch(items)` |
| `start_command` | `entrypoint` + `args` |
| — | `compute.restart(uuid, **params)`; `ssh:`, `fm:`, `startup_script:` on start |
| `services.render.list` / `create(node_id:, disk_size:)` | `render.list` / `render.start(node_number:)`, `render.start_batch` |
| `services.vpn.*` | removed (no VPN in the public API yet) |
| `services.session(uuid).info` | `sessions.get(uuid)` |
| `services.session(uuid).logs(recent:)` | `sessions.logs(uuid, tail:)` (running sessions only) |
| `services.session(uuid).stop(score:)` | `sessions.stop(uuid)` → 202; `sessions.wait_stopped(uuid)` |
| `sessions.list(recent: true)` | `sessions.list` (running sessions only; no history) |
| `apps.list` | removed |
| `idle_jobs.*` | removed |
| `network.info` (legacy shape) | `network.info` → `Types::Network` (new shape) |
| — | `stats.gpu_current`, `stats.gpu_history`, `stats.gpu_locations` |

## Data

- **Node identifier.** The integer `node_id` is gone everywhere. Nodes are identified by
  `node_number`, a string like `M95S-WZG8-7` (the API ignores case, dashes and spaces). The API has
  no mapping from old ids.
- **Money.** Wei, ETH and USD floats are replaced by integer micro-USD (1 = $0.000001) in every price,
  charge and balance. Use `OctaSpace::Money` to convert and format. `*_usd`, `*_ether`, `total_price_*`
  and `market_price` are gone.
- **Session state.** `is_ready` is replaced by `status` (`"starting"` / `"ready"`, `ready?`), with
  `progress` and `pull_percent` while starting. `ssh_direct`/`ssh_proxy`/`ssh_web` are grouped in
  `ssh` (`direct`, `proxy`, `web`); `user_envs` is `envs`; `ports_matrix` is `ports`.
- **Bandwidth.** `net_down_mbps` / `net_up_mbps` are integer Mbit/s; the old `net_*_mbits`
  (bytes per second) and `PayloadHelpers.normalize_marketplace_bandwidth` are gone.
- **Time.** `started_at` and log `ts` are Unix milliseconds, `at` is Unix seconds, `online_at` is
  ISO 8601; the models offer `started_time`, `time` and `online_time`.

## Errors

- 400 is now `OctaSpace::ValidationError` (previously a plain `ApiError`), 409 is the new
  `OctaSpace::ConflictError`.
- `OctaSpace::ProvisionRejectedError` is gone: a single `compute.start` raises
  `ValidationError` with the API's reason, and `start_batch` reports failures per item.
- `ApiError#retry_after` and `#rate_limit` are available on every API error; `client.rate_limit`
  gives the latest `RateLimit-*` state.

## Behaviour

- Only GET requests and `sessions.stop` are retried. Starting or restarting a service is never
  retried, and a request that changes state is never sent to a second base URL.
- Methods that need a key raise `AuthenticationError` before the request when none is configured.
- `on_request` no longer receives request headers, and the logger no longer prints them.
- Ruby 3.3 or newer is required; the playground app, `MockTransport` and the Rails Engine are gone.

Background, field by field: the shared API difference document used for all OctaSpace SDKs
(go-sdk `.tmp/Next/API-NEXT-DIFF.md`).
