# Stockpulse

A Go service that receives Shopify order webhooks, queues them in RabbitMQ, updates inventory in PostgreSQL through a pool of workers, and sends low-stock alerts.

It is small on purpose, but it handles the problems real webhook systems face: forged requests, duplicate deliveries, crashes mid-processing, concurrent stock updates and clean shutdowns.

## Architecture

```
Shopify ──POST──▶ API server ──save──▶ PostgreSQL
                      │                    ▲
                   publish                 │ transaction
                      ▼                    │
                  RabbitMQ ──▶ Worker pool ──▶ Alert notifier
```

1. **API** (`internal/api`) verifies the HMAC signature, saves the raw event, publishes its ID to RabbitMQ and returns `200` straight away.
2. **Queue** (`internal/queue`) publishes and consumes messages through RabbitMQ. Only event IDs travel through it; the database stays the source of truth.
3. **Workers** (`internal/worker`) consume event IDs, decrement stock and mark the event done in one transaction, then acknowledge the message. Unacknowledged messages are redelivered by RabbitMQ.
4. **Startup recovery:** events left `pending` (because publishing failed) are re-published when the service starts.

## Project layout

```
cmd/stockpulse/main.go     composition root: builds everything, handles startup and shutdown
internal/config            environment variables
internal/domain            shared types: Order, LineItem, Event, Product
internal/api               router, middleware, webhook handler, HMAC check
internal/queue             RabbitMQ publisher and consumer
internal/worker            worker pool and order processor
internal/store             PostgreSQL access (pgx)
internal/alert             Notifier interface with log and SMTP implementations
migrations/                schema and sample data
scripts/                   signed test-webhook sender
```

## Design decisions

| Problem | Solution |
| --- | --- |
| Forged webhooks | HMAC-SHA256 check with constant-time comparison (`hmac.Equal`) |
| Shopify retries the same webhook | Unique `webhook_id` with `ON CONFLICT DO NOTHING` |
| Worker crashes after updating stock | Stock update and "done" status commit in one transaction; the event row is locked with `FOR UPDATE` |
| Two orders updating the same products | Line items are updated in SKU order to prevent deadlocks |
| Slow processing makes Shopify time out | Respond immediately and process asynchronously |
| Deploys and restarts | `signal.NotifyContext`, `http.Server.Shutdown` and draining in-flight jobs |
| Testability | Small consumer-side interfaces (`EventStore`, `Store`, `Notifier`) with fakes in tests |
| Worker crashes before finishing        | Manual acks: a message is acknowledged only after its transaction commits, so RabbitMQ redelivers it otherwise |
| RabbitMQ restarts                      | Durable queue and persistent messages                                                              |

Coming from .NET: `main.go` plays the role of `Program.cs` with DI registration, interfaces work like `IRepository` abstractions but are satisfied implicitly, and goroutines consuming from RabbitMQ replace `BackgroundService` with a message-broker client.

## Run it

**Prerequisites:** Go 1.24+, Docker.

```bash
go mod tidy          # first time only: writes go.sum (commit it)
make test            # unit tests with the race detector
make up              # Postgres plus the app on :8080
make webhook         # send a signed test order
make logs            # watch it get processed
RabbitMQ dashboard: http://localhost:15672 (guest / guest)
```

To check the database:

```bash
docker compose exec db psql -U stockpulse -c "select * from products"
```

**Without Docker for the app:** start only Postgres (`docker compose up -d db`), copy `.env.example` to `.env`, export it, and run `make run`.

**Real Shopify webhooks:** expose the app with `ngrok http 8080`, then add an `Order creation` webhook in Shopify admin pointing to `https://<your-ngrok-url>/webhooks/orders`. Use the signing secret Shopify shows as `SHOPIFY_WEBHOOK_SECRET`.

## API

| Method | Path | Description |
| --- | --- | --- |
| `GET` | `/healthz` | Liveness check |
| `POST` | `/webhooks/orders` | Shopify order webhook. Needs `X-Shopify-Hmac-Sha256` and `X-Shopify-Webhook-Id` headers |

## Roadmap

- Retry `failed` events with a dead-letter queue and exponential backoff
- Periodic sweeper for `pending` events, not just at startup
- Prometheus metrics: queue depth, processing latency, failures
- Integration tests against real Postgres with testcontainers-go
- Only alert when stock first crosses the threshold
