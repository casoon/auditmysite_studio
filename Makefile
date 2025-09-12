# auditmysite_studio Makefile

.PHONY: setup install axe engine cli studio clean help

help: ## Show this help message
	@echo "auditmysite_studio - Available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Setup all packages and dependencies
	./setup.sh

install: setup ## Alias for setup
	@echo "✅ Installation complete"

axe: ## Download axe-core library
	@echo "📥 Downloading axe-core..."
	curl -o auditmysite_engine/third_party/axe/axe.min.js https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.8.4/axe.min.js
	@echo "✅ axe-core downloaded"

engine: ## Test the engine with example sitemap
	@echo "🔧 Testing engine..."
	cd auditmysite_engine && dart run bin/run.dart --sitemap=https://httpbin.org/robots.txt --concurrency=2

engine-serve: ## Start engine with WebSocket server
	@echo "🔧 Starting engine with WebSocket server..."
	cd auditmysite_engine && dart run bin/serve.dart --port=8080

engine-live: ## Start engine with live WebSocket demo
	@echo "🔧 Running engine with live WebSocket..."
	cd auditmysite_engine && dart run bin/run.dart --serve --sitemap=https://httpbin.org/robots.txt --concurrency=2

cli: ## Generate a test HTML report (requires engine artifacts)
	@echo "📝 Generating HTML report..."  
	cd auditmysite_cli && dart run bin/build.dart --in=../auditmysite_engine/artifacts --out=./test-reports --title="Test Report"

studio: ## Start Flutter Studio app
	@echo "🎨 Starting Studio..."
	cd auditmysite_studio && flutter run -d macos

clean: ## Clean all build artifacts
	@echo "🧹 Cleaning..."
	cd shared && dart pub deps -s none || true
	cd shared && rm -rf .dart_tool build || true
	cd auditmysite_engine && dart pub deps -s none || true  
	cd auditmysite_engine && rm -rf .dart_tool build artifacts || true
	cd auditmysite_cli && dart pub deps -s none || true
	cd auditmysite_cli && rm -rf .dart_tool build reports test-reports || true
	cd auditmysite_studio && flutter clean || true
	@echo "✅ Clean complete"

all: setup axe ## Setup everything including axe-core
	@echo "🎉 Full setup complete! Try 'make engine' to test."
