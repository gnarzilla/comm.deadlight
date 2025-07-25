# Deadlight Comm — Project Bootstrap Makefile

# Setup environment
setup:
	@echo "Setting up Deadlight Comm project..."
	# Example: install dependencies, generate secrets, initialize submodules
	# [Add actual setup steps here]

# Run development environment
dev:
	@echo "Starting dev server..."
	# Example: wrangler dev for Cloudflare Worker, local C proxy runner
	# [Add actual dev steps per module]

# Run parser tests (Wasm module)
test-parser:
	@echo "Running parser module tests..."
	cd parser && cargo test

# Lint all components
lint:
	@echo "Linting project files..."
	# Add linters for C, TypeScript, Rust, etc.

# Build worker logic
build-worker:
	@echo "Building Cloudflare Worker bundle..."
	cd worker && npm run build

# Build parser module
build-parser:
	@echo "Compiling Wasm parser..."
	cd parser && cargo build --target wasm32-unknown-unknown

# Build proxy server
build-proxy:
	@echo "Compiling proxy server..."
	cd proxy && make

# Deploy to edge
deploy:
	@echo "Deploying Deadlight Comm..."
	# Add deployment logic for Worker / frontend / proxy

# Clean builds
clean:
	@echo "Cleaning build artifacts..."
	rm -rf ./build ./dist parser/target proxy/bin

# Run full test suite
test:
	make test-parser
	# Add additional test targets as modules grow

# Help menu
help:
	@echo "Deadlight Comm — Makefile Commands"
	@echo "  setup         Initialize environment"
	@echo "  dev           Run development environment"
	@echo "  lint          Lint source files"
	@echo "  build-worker  Compile Worker logic"
	@echo "  build-parser  Compile Wasm parser"
	@echo "  build-proxy   Compile proxy server"
	@echo "  deploy        Deploy system"
	@echo "  test          Run all tests"
	@echo "  clean         Remove build artifacts"
