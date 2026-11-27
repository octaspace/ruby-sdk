# Resources

[← Back to README](../README.md)

**On this page:** [Conventions](#conventions) · [Compute](#compute) ·
[VPN](#vpn) · [Render](#render) · [Hosting](#hosting) · [Accounts](#accounts) ·
[Network](#network) · [Stats](#stats)

Sessions have [their own guide](sessions.md).

## Conventions

| Concept | In the SDK |
| --- | --- |
| Money | An integer number of micro-USD, millionths of a US dollar. `OctaSpace::Money.format(250_000)` returns `"$0.250000"`, `Money.to_usd` an exact `Rational`, `Money.from_usd("0.25")` the integer `250000`. |
| Node | Identified by its node number, for example `7KQ4-M2XD-4`. Case, dashes and spaces are ignored. |
| Network speed | Whole Mbit/s in `net_down_mbps` / `net_up_mbps`; `0` if not measured. |
| Time | `started_at` of sessions and `ts` of log entries are Unix milliseconds; `at` of statistics is Unix seconds. Each model has a method that returns a `Time` (`started_time`, `time`). |
| Parameters | Keyword arguments. An unknown one raises `ArgumentError` before anything is sent. |
| Results | Read-only models with a reader per field. `model[:field]` reads any field, including one without a reader; `model.to_h` returns the object as the API sent it. Models support pattern matching: `in {node_number:, base_price:}`. |

## Compute

Rent a machine and run your own container on it.

### List machines

```ruby
client.compute.list.each do |m|
  puts "#{m.node_number} #{m.city} #{m.cpu_cores} #{OctaSpace::Money.format(m.base_price)}"
end
```

A `Types::ComputeMachine` has its location, CPU, memory and disk (free bytes),
GPUs, network speed, reliability and prices:

| Field | Meaning |
| --- | --- |
| `base_price` | Per hour of rent |
| `storage_price` | Per GB of disk per hour |
| `traffic_price` | Per GB of traffic |
| `min_rent_minutes` | Minimum rent, see below; `0` if none |
| `os_version`, `virt` | Operating system of the node (`"Ubuntu 24.04"`) and its virtualization (`"none"` on bare metal); `wsl?`, `hive_os?` and `gpu_passthrough?` tell more |

> [!NOTE]
> **Minimum rent.** If the node owner set a minimum rent, a session stopped
> sooner is charged as if it ran that long. It is not charged if the node
> fails.

The listing also works without an API key, but is then refreshed about once an
hour; with a key it is at most 10 seconds old.

### List apps

```ruby
client.compute.apps.each do |app|
  puts "#{app.name} #{app.image} #{app.min_disk_size} GB"
end
```

A `Types::ComputeApp` is an application to start a session from: its `uuid`,
`image`, `category`, ports and `min_disk_size` (GB). With an API key the list
also has your own apps (`personal?`), which carry their `startup_script` and
`envs`; without a key, only the official ones.

### Start a session

```ruby
uuid = client.compute.start(
  node_number: "7KQ4-M2XD-4",
  image: "ubuntu:24.04",
  disk_size: 20, # GB
  http_ports: [8888],
  envs: {"APP_ENV" => "production"},
  ssh: true
)
```

`node_number` and `image` are required. Parameters you leave out are not sent
and take their defaults; all parameters are listed in the
[`Compute#start` reference](https://rubydoc.info/gems/octaspace/OctaSpace/Resources/Compute#start-instance_method).
Pass `ssh: false` or `fm: false` to turn off SSH or the file manager that an
application enables.

To start from an app, pass its `uuid` as `app:` together with its `image`:

```ruby
app = client.compute.apps.find { |a| a.name == "Ubuntu 24.04 LTS" }
uuid = client.compute.start(node_number: "7KQ4-M2XD-4", image: app.image, app: app.uuid,
  disk_size: [app.min_disk_size || 1, 20].max)
```

`min_disk_size` is a recommendation: a smaller `disk_size` is accepted, but
the app may run out of space.

`start` returns the session UUID as soon as the session is created, while its
container is still being set up. Wait for it with
[`sessions.wait_ready`](sessions.md#wait-until-ready). A rejected request, for
example for an insufficient balance or a node that is not available, raises
`OctaSpace::ValidationError` with the reason.

### Start several sessions

```ruby
results = client.compute.start_batch([
  {id: "a", node_number: "7KQ4-M2XD-4", image: "ubuntu:24.04"},
  {id: "b", node_number: "3HW9-P6TR-8", image: "ubuntu:24.04"}
])
results.each do |r|
  puts r.started? ? "#{r.id} started #{r.uuid}" : "#{r.id} failed: #{r.reason}"
end
```

Each item is checked on its own: one that fails does not stop the others.
Items without an `:id` get their position in the array.

### Restart a session

```ruby
client.compute.restart(uuid) # keep the parameters
client.compute.restart(uuid, disk_size: 20, http_ports: [8888], ssh: true)
```

`restart` recreates the container on the same node; the session keeps running,
with its UUID and prices. Without parameters the session restarts with the
parameters it was started with.

> [!WARNING]
> Parameters you pass **replace** the session's parameters as a whole; they
> are not merged. Every parameter you leave out takes its default (`disk_size`
> becomes 1 GB, `envs`, ports and `startup_script` are dropped), so include
> everything the session needs. If the new parameters cannot be set up, the
> session stops.

| Error | When |
| --- | --- |
| `OctaSpace::ConflictError` | The session is already starting or restarting |
| `OctaSpace::RateLimitError` | The session was restarted too recently; wait `retry_after` seconds. A session can be restarted once in 5 minutes and 6 times an hour |

## VPN

Rent a node as a VPN exit, billed by traffic until you stop the session.

### List VPN nodes

```ruby
client.vpn.list.each do |n|
  puts "#{n.node_number} #{n.city} #{n.protocols.join(",")} #{OctaSpace::Money.format(n.traffic_price)} per GB"
end
```

A `Types::VpnMachine` has its location, network speed, `traffic_price` per GB
and `protocols`: the protocols that passed the connection check on this node.
`supports?(:wg)` checks one. `residential?` is true when the node's address is
believed to belong to a residence.

| Protocol (`subkind`) | Client connects with |
| --- | --- |
| `wg` | WireGuard config file |
| `awg` | AmneziaWG config file |
| `reality` | VLESS Reality link |
| `http_proxy` | HTTP proxy address and login |

### Start a VPN session

```ruby
uuid = client.vpn.start(node_number: "7KQ4-M2XD-4", subkind: "wg")
session = client.sessions.wait_ready(uuid)
File.write("octaspace.conf", session.config, perm: 0o600)
```

Pick `subkind` from the node's `protocols`. When the session is ready, its
`config` is what the client connects with; for `http_proxy` it is a
`Types::HttpProxyConfig` with `ip`, `port`, `username` and `password` (HTTP
Basic, valid for this session).

> [!WARNING]
> `config` is a credential: a WireGuard or AmneziaWG config contains the
> private key. Keep it out of logs; `inspect` shows it as `[REDACTED]`.

- An `http_proxy` session accepts connections only from the IP address that
  started it. A server that starts it for someone else gets a proxy that
  person cannot use.
- You can have one VPN session per node.
- A protocol the node did not pass is refused with `OctaSpace::ValidationError`
  ("Node's VPN did not pass the connection check"), as are a second session on
  the same node and a node without VPN.
- VPN sessions have no logs. The node stays `"idle"` in its owner's listing.

## Render

Rent a render node.

```ruby
nodes = client.render.list

uuid = client.render.start(node_number: "7KQ4-M2XD-4")

results = client.render.start_batch([
  {id: "a", node_number: "7KQ4-M2XD-4"},
  {id: "b", node_number: "3HW9-P6TR-8"}
])
```

A `Types::RenderMachine` is a node with an NVIDIA GPU, its `blender_score` and
`base_price` per hour. The node renders for your account until you stop the
session.

## Hosting

The nodes you host: their state, prices and maintenance.

```ruby
client.hosting.nodes.each do |n|
  puts "#{n.number} #{n.status} #{OctaSpace::Money.format(n.prices.base)} #{n.uptime_percent}"
end
```

`nodes` lists your nodes that are online, with their status (`"idle"`,
`"rented"`, …), the services they are offered for (`offered?("compute")`),
prices, hardware, location and uptime. A node that runs only VPN sessions stays
`"idle"`.

`services["vpn"].protocols` tells which VPN protocols the node is offered for,
and `reason` why not (for example `"vpn_probe_failed"`).

### Get one node

```ruby
node = client.hosting.get("7KQ4-M2XD-4")
```

A node that is offline, does not exist or is not yours raises
`OctaSpace::NotFoundError`.

### Set prices

```ruby
client.hosting.set_prices("7KQ4-M2XD-4",
  base: OctaSpace::Money.from_usd("0.25"), # $0.25 per hour
  min_rent_minutes: 15)
```

Only the prices you pass change. Amounts are integer micro-USD.

| Field | Meaning | Range |
| --- | --- | --- |
| `base` | Charged for every hour the node is rented | $0.0001 – $1000 |
| `storage` | Charged per hour for each GB of disk the renter allocates | $0 – $1000 |
| `traffic` | Per GB of traffic | $0.0001 – $1000 |
| `min_rent_minutes` | Minimum rent of a compute session | 0 – 60 minutes; `0` turns it off |

A value out of range raises `OctaSpace::ValidationError`, an unknown node
`OctaSpace::NotFoundError`. New prices appear in the listings within seconds.

### Maintenance

```ruby
client.hosting.start_maintenance("7KQ4-M2XD-4")
client.hosting.get("7KQ4-M2XD-4").maintenance? # => true
client.hosting.end_maintenance("7KQ4-M2XD-4")
```

A node in maintenance is no longer offered for new rentals. Running sessions go
on, and their renters are notified. It works for an offline node too, and
repeating a call changes nothing.

## Accounts

```ruby
balance = client.accounts.balance
balance.formatted # => "$12.500000"
balance.balance   # => 12500000 (micro-USD)
```

The balance already includes what running sessions have used and becomes
negative when they use more than the account has (`negative?`). A recent charge
or deposit can take a moment to appear.

## Network

Platform statistics, updated every few minutes. No API key is needed.

```ruby
info = client.network.info
puts info.nodes.online, info.power.gpus_rented, info.sessions.running, info.time
```

`Types::Network` counts nodes, capacity, sessions, users, rendered frames and
VPN nodes.

### History

```ruby
history = client.network.history(from: Time.now - 7 * 86_400, step: 6 * 3600)
history.points.each do |p|
  puts "#{p.time} #{p.nodes_online} #{p.gpus_rented} #{p.sessions_running}"
end
```

`history` returns parallel arrays, one value per entry of `timestamps`;
`points` turns them into one point per timestamp. Each value is the average
over its step, so it can be fractional, and `nil` where there is no data.
`from` and `to` take a `Time` or Unix seconds and default to the last day;
`step` is in seconds, at least 300 (default 3600); a range has at most 2000
steps.

## Stats

GPU market and mining statistics. No API key is needed.

```ruby
market = client.stats.gpu_current(verified: "yes")
market.gpus.each do |g|
  puts "#{g.model} #{g.available} #{g.rented} #{g.available_price.p50}"
end

history = client.stats.gpu_history(
  gpu_name: "NVIDIA GeForce RTX 4090",
  from: Time.now - 7 * 86_400,
  step: 6 * 3600
)
history.fetch("NVIDIA GeForce RTX 4090").points.each do |p|
  puts "#{p.time} #{p.rented} #{p.rented_price.p50}"
end

locations = client.stats.gpu_locations

mining = client.stats.mining(role: "gpu", days: 7)
mining.miners.each { |m| puts "#{m.name} #{m.started} #{m.gpu_hours}" }
```

| Method | Returns |
| --- | --- |
| `gpu_current` | Per GPU model: the number of GPUs (not nodes), how many are rented, the memory of one GPU (`memory_mb`), performance, and price percentiles in micro-USD per GPU-hour. A percentile is `nil` when there is no price. |
| `gpu_history` | The same over time, by model name. `gpu_name` takes one name or an array; `from` and `to` take a `Time` or Unix seconds and default to the last day. `step` is in seconds, at least 300 (default 3600); a range has at most 2000 steps. |
| `gpu_locations` | The number of GPUs by city and model |
| `mining` | What the platform's mining sessions run: `miners`, `algorithms` and `pools` (with their `coins`), most used first, `total` and the miners per day (`daily`). `role:` is `"gpu"` (default) or `"cpu"`; `days:` 1 – 365 (default 30). |

`verified:` takes `"yes"` (verified nodes only), `"no"` or `"all"` (default).
