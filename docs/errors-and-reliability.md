# Errors, rate limits and retries

[← Back to README](../README.md)

**On this page:** [Error classes](#error-classes) ·
[Rate limits](#rate-limits) · [Retries](#retries)

## Error classes

An error response from the API is raised as a subclass of
`OctaSpace::ApiError`, which holds the HTTP `status`, the API's message, the
`request_id`, the parsed `body`, `retry_after` and the `rate_limit` state.

| Class | Status | Typical cause |
| --- | --- | --- |
| `ValidationError` | 400, 422 | A parameter is missing or invalid, or the request cannot be met (for example an insufficient balance) |
| `AuthenticationError` | 401 | The API key is missing, wrong or deleted |
| `PermissionError` | 403 | Access denied |
| `NotFoundError` | 404 | Unknown or stopped session, unknown node |
| `ConflictError` | 409 | The session is already starting or restarting |
| `RateLimitError` | 429 | Too many requests, or the session was restarted too recently |
| `ServerError` | 5xx | A temporary problem on the API side |
| `ServiceUnavailableError` | 503 | The service is temporarily unavailable; a subclass of `ServerError` |

All classes are in the `OctaSpace` namespace. When the API cannot be reached at
all, the error is an `OctaSpace::NetworkError`: `ConnectionError` (DNS,
connection or TLS failure) or `TimeoutError`. Every error the SDK raises is an
`OctaSpace::Error`.

```ruby
begin
  client.compute.start(node_number: "7KQ4-M2XD-4", image: "ubuntu:24.04")
rescue OctaSpace::ApiError => e
  warn "status #{e.status}: #{e.message} (request #{e.request_id})"
end
```

> [!TIP]
> Include the request ID when you contact support about a failed call.

## Rate limits

| Requests | Limit per minute |
| --- | --- |
| Without an API key | 60 per IP address |
| With an API key | 300 per account |
| Starting and restarting sessions | 10 per account |

`client.rate_limit` returns the `limit`, the `remaining` requests and the
seconds until the window resets (`reset`), as of the latest response. A failed
call carries the same in `ApiError#rate_limit`.

On a `RateLimitError`, wait `retry_after` seconds before you try again:

```ruby
attempts = 0
begin
  client.compute.restart(uuid)
rescue OctaSpace::RateLimitError => e
  raise if (attempts += 1) > 2
  sleep(e.retry_after || 60)
  retry
end
```

## Retries

GET requests and `sessions.stop` are retried automatically on connection
errors, timeouts and the statuses 429, 502, 503 and 504, with exponential
backoff and jitter. They honour `Retry-After` up to 60 seconds; when the API
asks to wait longer, the `RateLimitError` is raised at once.

> [!IMPORTANT]
> Starting and restarting sessions and setting prices are never retried, so
> that they cannot run twice. Decide yourself whether to repeat them after an
> error.

Set the number of retries with `max_retries` and the longest wait with
`max_retry_after`; see [Client configuration](getting-started.md#options).
