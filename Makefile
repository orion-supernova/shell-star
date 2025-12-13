.PHONY: build run test clean client test-linux help

help:
	@echo "Available commands:"
	@echo "  make build       - Build the project"
	@echo "  make run         - Run the server"
	@echo "  make test        - Run tests"
	@echo "  make test-linux  - Test Linux build with Docker"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make client      - Run example terminal client"
	@echo "  make help        - Show this help message"

build:
	swift build

run:
	swift run

test:
	swift test

clean:
	swift package clean

test-linux:
	@./test-linux-build.sh

client:
	@chmod +x client-example.sh
	@./client-example.sh