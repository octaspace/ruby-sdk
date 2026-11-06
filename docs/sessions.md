# Sessions

[← Back to README](../README.md)

**On this page:** [Lifecycle](#lifecycle) · [List and get](#list-and-get) ·
[Wait until ready](#wait-until-ready) · [Connect](#connect) · [Logs](#logs) ·
[Stop](#stop) · [Session fields](#session-fields)

`client.sessions` works with your running sessions, both compute and render.
`list` and `get` return a `Types::ComputeSession` or a `Types::RenderSession`;
`compute?` and `render?` tell them apart.

## Lifecycle

```text
compute.start / render.start ──► starting ──► ready ──► sessions.stop
                                    ▲           │
                                    └─ restart ─┘
```

| `status` | Meaning |
| --- | --- |
| `"starting"` (`starting?`) | The container is being set up; see `progress` and `pull_percent` |
| `"ready"` (`ready?`) | The session is running and can be used |

A stopped session is no longer returned by the API.

## List and get

```ruby
sessions = client.sessions.list # running sessions, oldest first

begin
  session = client.sessions.get(uuid)
rescue OctaSpace::NotFoundError
  # the session has stopped, or the UUID is unknown
end
```

## Wait until ready

`wait_ready` polls a session until it is ready and returns it. The block, if
given, receives every state it polls:

```ruby
begin
  session = client.sessions.wait_ready(uuid, timeout: 600) do |s|
    puts "#{s.status} #{s.progress} #{s.pull_percent}"
  end
rescue OctaSpace::SessionStoppedError
  # the session stopped while starting, for example because SSH could not be set up
rescue OctaSpace::WaitTimeoutError
  # still not ready after 10 minutes
end
```

It checks every 3 seconds; change this with `interval:`. Without `timeout:` it
waits until the session is ready or stops.

## Connect

When a compute session is ready, these fields tell you how to reach it:

| Field | Contains |
| --- | --- |
| `ssh.direct`, `ssh.proxy` | SSH endpoints: `host`, `port` and the `user` to log in as. `ssh.endpoint` returns the direct one if there is one, otherwise the proxy |
| `ssh.web` | URL of the web terminal |
| `fm` | URL of the web file browser |
| `ports` | Each exposed container port mapped to its public port on the node |
| `urls` | Each HTTP port mapped to its public URL |

The SSH fields are empty unless SSH was turned on when the session started,
and `fm` is empty unless the file browser was.

```ruby
ep = session.ssh.endpoint
system("ssh", "-p", ep.port.to_s, "-l", ep.user, "--", ep.host)
```

> [!WARNING]
> Anyone with the `ssh.web` or `fm` URL can use the session without logging
> in: keep them out of logs. `inspect` shows them as `[REDACTED]`. The SSH
> `user` comes from the container image; pass it as a separate argument, as
> above, never as part of a shell string.

## Logs

```ruby
logs = client.sessions.logs(uuid, tail: 100)
print logs.container if logs.container
logs.system.each { |e| puts "#{e.time} #{e.msg}" }
```

| Field | Contains |
| --- | --- |
| `container` | The latest container output; `tail:` sets the number of lines, 1 – 1000 (200 by default). `nil` when the node cannot be reached, which differs from an empty log. |
| `container_truncated?` | `true` if the output was cut to its last 1 MiB |
| `system` | Platform events of the session, oldest first |

Logs are available for running compute sessions.

## Stop

```ruby
client.sessions.stop(uuid)
client.sessions.wait_stopped(uuid, timeout: 60)
```

Stopping takes a few seconds, during which `get` can still return the session;
after that it raises `OctaSpace::NotFoundError`. `wait_stopped` waits for that
and returns `true`. Stopping a session twice is safe.

> [!NOTE]
> A session stopped before its minimum rent (`min_rent_minutes`) is charged as
> if it ran that long.

## Session fields

| Field | Meaning |
| --- | --- |
| `base_price`, `storage_price`, `traffic_price` | Prices in micro-USD, fixed when the session starts |
| `charge_amount` | What the session has cost so far, micro-USD |
| `duration` | Seconds since the start |
| `started_at` | Unix milliseconds; `started_time` returns a `Time` |
| `rx`, `tx` | Bytes received and sent |
| `node_hw` | The node: CPU, memory, GPUs, the rented disk in GB, network speed |

While a session is starting, its prices are `nil` and `node_hw` is `nil`.
