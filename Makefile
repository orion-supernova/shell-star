.PHONY: build run test clean client help

help:
	@echo "Available commands:"
	@echo "  make build    - Build the project"
	@echo "  make run      - Run the server"
	@echo "  make test     - Run tests"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make client   - Run example terminal client"
	@echo "  make help     - Show this help message"

build:
	swift build

run:
	swift run

test:
	swift test

clean:
	swift package clean

client:
	@chmod +x client-example.sh
	@./client-example.sh