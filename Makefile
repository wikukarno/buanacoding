# Makefile for Hugo Project with Tailwind CSS

# Variables
TAILWIND_INPUT=./assets/css/style.css
TAILWIND_OUTPUT=./static/css/style.css
TAILWIND_CMD=./bin/tailwindcss
HUGO_VERSION=$(shell hugo version)

# Colors for output
CYAN=\033[0;36m
GREEN=\033[0;32m
YELLOW=\033[0;33m
RED=\033[0;31m
NC=\033[0m # No Color

# Targets
.PHONY: help dev dev-full dev-watch css build build-clean build-production clean clean-all clear-cache status check install

## Default target - show help
.DEFAULT_GOAL := help

## Show this help message
help:
	@echo "$(CYAN)Hugo + Tailwind Development Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Development:$(NC)"
	@echo "  make dev          - Run Hugo development server"
	@echo "  make dev-full     - Run Hugo dev server with --disableFastRender"
	@echo "  make dev-watch    - Run Hugo + Tailwind watcher together"
	@echo "  make css          - Run Tailwind CSS watcher"
	@echo ""
	@echo "$(GREEN)Build:$(NC)"
	@echo "  make build        - Build site with minification"
	@echo "  make build-clean  - Build with clean destination directory"
	@echo "  make build-prod   - Production build (clean + gc + minify)"
	@echo ""
	@echo "$(GREEN)Cleanup:$(NC)"
	@echo "  make clean        - Remove public directory"
	@echo "  make clean-all    - Remove public + resources + node_modules"
	@echo "  make clear-cache  - Clear Hugo cache (public + resources)"
	@echo ""
	@echo "$(GREEN)Utilities:$(NC)"
	@echo "  make status       - Show Hugo and build status"
	@echo "  make check        - Check for required dependencies"
	@echo "  make install      - Install Tailwind CSS binary"

## Run Hugo development server
dev:
	@echo "$(CYAN)Starting Hugo development server...$(NC)"
	hugo server -D

## Run Hugo dev server with --disableFastRender (useful when updating partials/layouts)
dev-full:
	@echo "$(CYAN)Starting Hugo development server (full reload mode)...$(NC)"
	hugo server -D --disableFastRender

## Run Hugo and Tailwind watcher together
dev-watch:
	@echo "$(CYAN)Running Hugo and Tailwind watcher...$(NC)"
	@make -j2 dev css

## Run Tailwind CSS watcher
css:
	@echo "$(CYAN)Starting Tailwind CSS watcher...$(NC)"
	$(TAILWIND_CMD) -i $(TAILWIND_INPUT) -o $(TAILWIND_OUTPUT) --watch

## Build the site with minification
build:
	@echo "$(CYAN)Building site with minification...$(NC)"
	hugo --minify
	@echo "$(GREEN)Build complete!$(NC)"

## Build the site with clean destination directory (fixes cache/duplicate issues)
build-clean:
	@echo "$(CYAN)Building site with clean destination...$(NC)"
	hugo --cleanDestinationDir --minify
	@echo "$(GREEN)Clean build complete!$(NC)"

## Production build with full optimization
build-production:
	@echo "$(CYAN)Running production build...$(NC)"
	@echo "$(YELLOW)1. Clearing cache...$(NC)"
	@rm -rf public resources
	@echo "$(YELLOW)2. Building with optimization...$(NC)"
	hugo --gc --minify
	@echo "$(GREEN)Production build complete!$(NC)"
	@echo "$(CYAN)Total pages: $$(find public -name '*.html' | wc -l | tr -d ' ')$(NC)"

## Alias for production build
build-prod: build-production

## Clean the public directory
clean:
	@echo "$(YELLOW)Removing public directory...$(NC)"
	rm -rf public
	@echo "$(GREEN)Clean complete!$(NC)"

## Clean everything (public, resources, node_modules)
clean-all:
	@echo "$(YELLOW)Removing all generated files...$(NC)"
	rm -rf public resources node_modules
	@echo "$(GREEN)Deep clean complete!$(NC)"

## Clear Hugo cache only (public + resources)
clear-cache:
	@echo "$(YELLOW)Clearing Hugo cache...$(NC)"
	rm -rf public resources
	@echo "$(GREEN)Cache cleared!$(NC)"

## Show Hugo version and build status
status:
	@echo "$(CYAN)=== Hugo Project Status ===$(NC)"
	@echo ""
	@echo "$(GREEN)Hugo Version:$(NC)"
	@hugo version
	@echo ""
	@echo "$(GREEN)Build Status:$(NC)"
	@if [ -d "public" ]; then \
		echo "  Public directory: $(GREEN)EXISTS$(NC)"; \
		echo "  HTML files: $$(find public -name '*.html' | wc -l | tr -d ' ')"; \
		echo "  Total size: $$(du -sh public | cut -f1)"; \
	else \
		echo "  Public directory: $(RED)NOT BUILT$(NC)"; \
	fi
	@echo ""
	@echo "$(GREEN)Resources Status:$(NC)"
	@if [ -d "resources" ]; then \
		echo "  Resources cache: $(GREEN)EXISTS$(NC)"; \
		echo "  Cache size: $$(du -sh resources | cut -f1)"; \
	else \
		echo "  Resources cache: $(YELLOW)EMPTY$(NC)"; \
	fi

## Check for required dependencies
check:
	@echo "$(CYAN)Checking dependencies...$(NC)"
	@echo ""
	@command -v hugo >/dev/null 2>&1 && echo "$(GREEN)✓$(NC) Hugo installed: $$(hugo version | head -1)" || echo "$(RED)✗$(NC) Hugo not found"
	@[ -f "$(TAILWIND_CMD)" ] && echo "$(GREEN)✓$(NC) Tailwind CSS binary exists" || echo "$(YELLOW)⚠$(NC) Tailwind CSS binary not found (run: make install)"
	@command -v git >/dev/null 2>&1 && echo "$(GREEN)✓$(NC) Git installed" || echo "$(RED)✗$(NC) Git not found"
	@echo ""

## Install Tailwind CSS standalone binary
install:
	@echo "$(CYAN)Installing Tailwind CSS standalone binary...$(NC)"
	@mkdir -p bin
	@echo "$(YELLOW)Downloading Tailwind CSS...$(NC)"
	@curl -sLO https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-macos-arm64
	@mv tailwindcss-macos-arm64 bin/tailwindcss
	@chmod +x bin/tailwindcss
	@echo "$(GREEN)Tailwind CSS installed successfully!$(NC)"
	@./bin/tailwindcss --help | head -1