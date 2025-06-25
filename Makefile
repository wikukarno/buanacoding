# Makefile for Hugo Project with Tailwind CSS

# Variables
TAILWIND_INPUT=./assets/css/style.css
TAILWIND_OUTPUT=./static/css/style.css
TAILWIND_CMD=./bin/tailwindcss

# Targets
.PHONY: dev dev-full css build clean

## Run Hugo development server
dev:
	hugo server -D

dev-watch:
	@echo "Running Hugo and Tailwind watcher..."
	@make -j2 dev css

## Run Hugo dev server with --disableFastRender (useful when updating partials/layouts)
dev-full:
	hugo server -D --disableFastRender

## Run Tailwind CSS watcher
css:
	$(TAILWIND_CMD) -i $(TAILWIND_INPUT) -o $(TAILWIND_OUTPUT) --watch

## Build the site with minification
build:
	hugo --minify

## Clean the public directory
clean:
	rm -rf public