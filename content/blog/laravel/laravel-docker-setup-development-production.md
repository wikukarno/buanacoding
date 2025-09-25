---
title: 'Development and Production Environment Setup'
date: 2025-09-16T07:00:00+07:00
draft: false
url: /2025/09/laravel-docker-setup-development-production.html
tags: 
- Laravel
- Docker
- Development
- Production
description: 'A practical Docker setup for Laravel in development and production: PHP‑FPM + Nginx, MySQL/Postgres, Redis, multi‑stage builds, Xdebug toggle, permissions, environment variables, healthchecks, and deployment tips.'
keywords: ['laravel docker','laravel docker compose','laravel php-fpm nginx','laravel docker production','laravel xdebug docker','laravel redis docker','laravel mysql docker','docker multi-stage build laravel','laravel queue worker docker']
featured: false
---

Docker makes Laravel environments consistent across machines and stages. The steps below outline a clean setup for local development and a hardened build for production. Run PHP‑FPM behind Nginx, connect to MySQL/Postgres and Redis, toggle Xdebug when needed, and ship a small, cache‑friendly image.

<!--readmore-->

Components
----------
- PHP‑FPM container for the application
- Nginx container as the HTTP entry point
- MySQL or Postgres, plus Redis
- A `docker-compose.yml` for development with bind mounts
- A multi‑stage Dockerfile for a compact production image

Project layout
--------------
```text
app/            # your Laravel app code
docker/
  nginx/
    default.conf
Dockerfile
docker-compose.yml
```

Dockerfile (multi‑stage)
------------------------
Build dependencies once, then copy only what you need into the runtime image. Enable OPcache for production; allow an Xdebug toggle for local work.

```Dockerfile
# syntax=docker/dockerfile:1

ARG PHP_VERSION=8.2

FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock .
RUN composer install --no-dev --prefer-dist --no-scripts --no-progress --no-interaction

FROM php:${PHP_VERSION}-fpm AS base
WORKDIR /var/www/html

# System deps
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    git unzip libzip-dev libpng-dev libonig-dev libicu-dev libpq-dev \
 && docker-php-ext-install pdo pdo_mysql mysqli intl zip \
 && rm -rf /var/lib/apt/lists/*

# OPcache for prod
RUN docker-php-ext-install opcache \
 && { echo "opcache.enable=1"; echo "opcache.enable_cli=0"; echo "opcache.jit_buffer_size=0"; } > /usr/local/etc/php/conf.d/opcache.ini

# Xdebug (optional; enabled in dev via env)
RUN pecl install xdebug \
 && docker-php-ext-enable xdebug \
 && { echo "xdebug.mode=off"; echo "xdebug.client_host=host.docker.internal"; } > /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

COPY --from=vendor /app/vendor /var/www/html/vendor
COPY . /var/www/html

# Permissions for storage/bootstrap/cache in container
RUN chown -R www-data:www-data storage bootstrap/cache \
 && find storage bootstrap/cache -type d -exec chmod 775 {} \; \
 && find storage bootstrap/cache -type f -exec chmod 664 {} \;

# Default to production settings; override in dev with env
ENV APP_ENV=production \
    APP_DEBUG=false \
    PHP_IDE_CONFIG="serverName=laravel-docker"

CMD ["php-fpm"]
```

Nginx config (docker/nginx/default.conf)
----------------------------------------
```nginx
server {
  listen 80;
  server_name _;
  root /var/www/html/public;

  index index.php index.html;

  location / {
    try_files $uri $uri/ /index.php?$query_string;
  }

  location ~ \.php$ {
    include fastcgi_params;
    fastcgi_intercept_errors on;
    fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
    fastcgi_pass app:9000; # php-fpm service name
  }

  location ~* \.(?:css|js|jpg|jpeg|gif|png|svg|ico|webp)$ {
    expires 7d;
    access_log off;
  }
}
```

Development docker‑compose.yml
------------------------------
Bind mount the source tree for instant reloads, enable Xdebug, and expose DB/Redis. Below uses MySQL; switch to Postgres if preferred.

```yaml
version: "3.9"
services:
  app:
    build:
      context: .
      args:
        PHP_VERSION: "8.2"
    image: laravel-app:dev
    container_name: laravel-app
    environment:
      APP_ENV: local
      APP_DEBUG: "true"
      XDEBUG_MODE: debug,develop
    volumes:
      - ./:/var/www/html
    depends_on:
      - db
      - redis

  web:
    image: nginx:1.25-alpine
    container_name: laravel-web
    ports:
      - "8080:80"
    volumes:
      - ./:/var/www/html:ro
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - app

  db:
    image: mysql:8.0
    container_name: laravel-mysql
    environment:
      MYSQL_DATABASE: app
      MYSQL_USER: app
      MYSQL_PASSWORD: secret
      MYSQL_ROOT_PASSWORD: root
    ports:
      - "3306:3306"
    volumes:
      - dbdata:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 10

  redis:
    image: redis:7-alpine
    container_name: laravel-redis
    ports:
      - "6379:6379"
    volumes:
      - redisdata:/data

volumes:
  dbdata:
  redisdata:
```

Environment configuration
-------------------------
Point your `.env` to container hosts and keep credentials in env variables.

```env
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost:8080

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=app
DB_USERNAME=app
DB_PASSWORD=secret

CACHE_DRIVER=redis
REDIS_HOST=redis
REDIS_PORT=6379
SESSION_DRIVER=file
```

Common commands in Docker
-------------------------
```bash
# First-time setup
docker compose up -d --build
docker compose exec app php artisan key:generate

# Run migrations and seeders
docker compose exec app php artisan migrate --seed

# Clear and rebuild caches
docker compose exec app php artisan cache:clear && \
  php artisan config:clear && php artisan route:clear && php artisan view:clear && \
  php artisan config:cache && php artisan route:cache && php artisan view:cache

# Run queue worker (dev)
docker compose exec -d app php artisan queue:work --tries=3
```

Permissions and file ownership
------------------------------
On Linux hosts, UID/GID mismatches can create root‑owned files on bind mounts. One solution is to build the image with a matching UID, another is to keep writes inside `storage/` and `bootstrap/cache` and set group‑writable modes. For production servers outside Docker, follow: [Fix Laravel Permission Issues]({{< relref "blog/laravel/fix-laravel-permission-issues-production.md" >}}).

Production build
----------------
In production, bake dependencies and your code into the image. Avoid bind mounts; use read‑only file systems where possible, and send logs to stdout/stderr.

Example production compose (excerpt):
```yaml
services:
  app:
    build:
      context: .
      args:
        PHP_VERSION: "8.2"
    image: registry.example.com/laravel-app:2025-09-16
    environment:
      APP_ENV: production
      APP_DEBUG: "false"
    deploy:
      replicas: 2
      restart_policy:
        condition: on-failure
    healthcheck:
      test: ["CMD-SHELL", "php -v || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3

  web:
    image: nginx:1.25-alpine
    ports:
      - "80:80"
    depends_on:
      - app
```

Deployment routine
------------------
Use a predictable sequence to avoid stale caches and mismatched environments:

```bash
docker compose pull && docker compose build
docker compose up -d --no-deps --scale app=2 --build app web
docker compose exec app php artisan migrate --force
docker compose exec app php artisan cache:clear && php artisan config:clear && php artisan route:clear && php artisan view:clear
docker compose exec app php artisan config:cache && php artisan route:cache && php artisan view:cache
docker compose exec app php artisan queue:restart || true
```

Security and hardening
----------------------
- Never bake secrets into images. Pass them at runtime (env vars, orchestrator secrets).
- Serve over HTTPS and set secure cookies. Review: [Laravel Security Best Practices for Production]({{< relref "blog/laravel/laravel-security-best-practices-production.md" >}}).
- Keep the Nginx container minimal and stateless; store user uploads in object storage or mounted volumes.
- Limit token scopes for API access; Sanctum is a good fit for first‑party clients: [Laravel API Authentication with Sanctum]({{< relref "blog/laravel/laravel-api-authentication-sanctum-2025.md" >}}).

Troubleshooting
---------------
- If the app reads old values, you likely cached config earlier. Clear and rebuild. Background: [Laravel Environment Configuration]({{< relref "blog/laravel/laravel-environment-configuration-env-issues.md" >}}).
- If sessions or cookies fail behind a proxy, configure trusted proxies and cookie settings. See: [Fixing Laravel Session and Cache Issues]({{< relref "blog/laravel/fixing-laravel-session-cache-issues.md" >}}).
- For error spikes or 500 responses, check application and service logs first, then Nginx/PHP‑FPM. Patterns: [Advanced Laravel Debugging with Logs]({{< relref "blog/laravel/advanced-laravel-debugging-with-logs.md" >}}).
- CPU spikes while building assets? Run `composer install --no-dev` and only what you need in images; keep build artifacts out of runtime layers.

Summary
-------
A small set of containers—PHP‑FPM, Nginx, a database, and Redis—lets you develop locally and deploy consistently. Use bind mounts and Xdebug in development, but ship a multi‑stage, cached image in production with OPcache on. Keep secrets out of images, send logs to stdout, and follow a clear post‑deploy routine to rebuild caches and restart workers. Tie the setup to your existing operational practices to reduce surprises.
