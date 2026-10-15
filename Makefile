.PHONY: tidy build run

tidy:            ## download dependencies and write go.sum
	go mod tidy

build:           ## compile the binary into ./bin
	go build -o bin/stockpulse ./cmd/stockpulse

run:             ## run locally (needs Postgres and the env vars in .env.example)
	go run ./cmd/stockpulse
