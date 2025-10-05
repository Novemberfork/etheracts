# Etheracts Contract Makefile
# ==========================

.PHONY: help build clean deps deploy-local deploy-testnet deploy-mainnet setup test fmt lint config

# Default target
help:
	@echo "Etheracts Contract"
	@echo "=================="
	@echo ""
	@echo "Available targets:"
	@echo "  help              Show this help message"
	@echo "  build             Build the deployment tool"
	@echo "  clean             Clean build artifacts"
	@echo "  deps              Install dependencies"
	@echo "  setup             Setup development environment"
	@echo "  deploy-local      Deploy to local network"
	@echo "  deploy-testnet    Deploy to testnet"
	@echo "  deploy-mainnet    Deploy to mainnet"
	@echo "  test              Run contract tests"
	@echo "  fmt               Format code"
	@echo "  lint              Lint code"
	@echo "  config            Show current configuration"
	@echo ""
	@echo "Environment:"
	@echo "  Copy example.env to .env and configure your settings"
	@echo ""

# Build the deployment tool, contracts, and generate ABIs
build:
	@echo "🔨 Building deployment tool..."
	cd integration && go build -o bin/deploy ./cmd/deploy
	@echo "🔨 Building contracts and generating ABIs..."
	cd integration/cmd && chmod +x generate_abi.sh && ./generate_abi.sh
	@echo "✅ Build completed!"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf integration/bin/
	rm -rf target/
	@echo "✅ Clean completed!"

# Install dependencies
deps:
	@echo "📦 Installing dependencies..."
	cd integration && go mod tidy && go mod download
	scarb build
	@echo "✅ Dependencies installed!"

# Deploy to local network
deploy-local: build
	@echo "🚀 Deploying to local network..."
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found. Please copy example.env to .env and configure it."; \
		exit 1; \
	fi
	@echo "📋 Setting NETWORK=local"
	cd integration && NETWORK=local ./bin/deploy ethrx

# Deploy to testnet
deploy-testnet: build
	@echo "🚀 Deploying to testnet..."
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found. Please copy example.env to .env and configure it."; \
		exit 1; \
	fi
	@echo "📋 Setting NETWORK=testnet"
	cd integration && NETWORK=testnet ./bin/deploy ethrx

# Deploy to mainnet
deploy-mainnet: build
	@echo "🚀 Deploying to mainnet..."
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found. Please copy example.env to .env and configure it."; \
		exit 1; \
	fi
	@echo "📋 Setting NETWORK=mainnet"
	@echo "⚠️  This will deploy to MAINNET. Are you sure? (Press Ctrl+C to cancel)"
	@sleep 5
	cd integration && NETWORK=mainnet ./bin/deploy ethrx

# Setup development environment
setup: deps
	@echo "🛠️  Setting up development environment..."
	@if [ ! -f .env ]; then \
		echo "📄 No .env file found. Create one from example.env? (y/N)"; \
		read -r response; \
		if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
			cp example.env .env; \
			echo "✅ Created .env file from example.env"; \
			echo "⚠️  Please edit .env file with your configuration"; \
		else \
			echo "❌ Setup cancelled - no .env file created"; \
			exit 1; \
		fi; \
	else \
		echo "⚠️  .env file already exists!"; \
		echo "Do you want to overwrite it with example.env? (y/N)"; \
		read -r response; \
		if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
			cp example.env .env; \
			echo "✅ Overwrote .env file with example.env"; \
			echo "⚠️  Please edit .env file with your configuration"; \
		else \
			echo "✅ Keeping existing .env file"; \
		fi; \
	fi
	@echo "✅ Setup completed!"

# Run tests
test:
	@echo "🧪 Running contract tests..."
	scarb test
	@echo "✅ Tests completed!"

# Format code
fmt:
	@echo "🎨 Formatting code..."
	scarb fmt
	@echo "✅ Code formatted!"

# Lint code
lint:
	@echo "🔍 Linting code..."
	scarb fmt --check
	@echo "✅ Linting completed!"

# Show current configuration
config:
	@echo "📋 Current configuration:"
	@if [ -f .env ]; then \
		echo "✅ .env file found"; \
		echo "Network: $$(grep '^NETWORK=' .env | cut -d'=' -f2)"; \
		echo "RPC URL: $$(grep '^.*_RPC_URL=' .env | grep -v 'YOUR_API_KEY' | head -1 | cut -d'=' -f2)"; \
		echo "Deployer: $$(grep '^STARKNET_DEPLOYER_ADDRESS=' .env | cut -d'=' -f2 | cut -c1-10)..."; \
	else \
		echo "❌ .env file not found"; \
	fi
