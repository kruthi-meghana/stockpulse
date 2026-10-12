.PHONY: tidy build run test vet up down logs webhook

tidy:            ## download dependencies and write go.sum
	go mod tidy

build:           ## compile the binary into ./bin
	go build -o bin/stockpulse ./cmd/stockpulse

run:             ## run locally (needs Postgres and the env vars in .env.example)
	go run ./cmd/stockpulse

test:            ## run unit tests with the race detector
	go test -race ./...

vet:             ## static checks
	go vet ./...
	gofmt -l .

up:              ## start Postgres and the app in Docker
	docker compose up --build -d

down:            ## stop containers
	docker compose down

logs:            ## follow the app logs
	docker compose logs -f app

webhook:         ## send a signed test webhook (SHOPIFY_WEBHOOK_SECRET defaults to dev-secret)
	SHOPIFY_WEBHOOK_SECRET=$${SHOPIFY_WEBHOOK_SECRET:-dev-secret} ./scripts/send_test_webhook.sh
