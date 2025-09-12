---
title: "Laravel Environment Configuration: Fixing .env and Config Cache Issues"
date: 2025-09-12T10:00:00+07:00
draft: false
url: /2025/09/laravel-environment-configuration-env-issues.html
description: "Seeing odd errors after deploy or config:cache? Learn how Laravel reads env vars, how config caching works, and the exact steps to fix common issues safely in production."
keywords: ["laravel env", ".env production", "laravel config cache", "php artisan config:cache error", "APP_KEY missing", "laravel environment variables", "php-fpm environment", "nginx fastcgi_param", "apache SetEnv", "config caching"]
tags:
  - Laravel
  - Configuration
  - Environment
  - Cache
featured: false
---

Env problems often show up right after a deploy or a cache command: the app works locally but fails in production with “No application encryption key has been specified”, wrong database credentials, missing API keys, or stale config even after you edited `.env`. This happens because of how Laravel loads environment variables and how config caching freezes values.

<!--readmore-->

How Laravel reads environment variables
--------------------------------------
Laravel reads environment variables in two ways:

- During bootstrap from `.env` via Dotenv for local/dev and many simple servers.
- From the real process environment (what PHP‑FPM/Apache passes to PHP) when `.env` is not available or when you deploy containerized systems and set vars externally.

When you run `php artisan config:cache`, Laravel compiles your configuration into a single PHP file (`bootstrap/cache/config.php`). From that point on, your app no longer looks at `.env` on each request. Any change in `.env` will not take effect until you clear and rebuild the config cache.

Common symptoms
---------------
- You updated `.env` but the app still uses old values.
- `APP_KEY` error (HTTP 500) after `config:cache` or fresh deploy.
- Queue/cron jobs using different values compared to web requests.
- Env vars set in Nginx/Apache don’t appear in `config()`.

Fix sequence (production)
-------------------------
From your project root on the server:

```bash
# 1) Ensure the PHP user can read .env (but do not make it world-readable)
sudo chown deploy:www-data .env  # adjust users/groups
sudo chmod 640 .env

# 2) Clear stale caches
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear

# 3) Rebuild caches only after verifying .env and real environment
php artisan config:cache
php artisan route:cache
php artisan view:cache

# 4) Reload PHP-FPM to refresh OPcache and workers
sudo systemctl reload php8.2-fpm || sudo systemctl reload php8.1-fpm || true
```

APP_KEY and encryption
----------------------
If you see “No application encryption key has been specified”, your `APP_KEY` is empty, truncated, or the cached config is stale.

```bash
php artisan key:generate --force
php artisan config:clear && php artisan config:cache
sudo systemctl reload php8.2-fpm || true
```

Generate the key only once; persist it across deployments. Regenerating on a live app will invalidate encrypted data (sessions/cookies).

Where to set variables in production
-----------------------------------
Prefer setting environment variables at the process level in production instead of editing `.env` on the server. This reduces drift and surprises:

- systemd for PHP‑FPM: set variables in the PHP‑FPM pool or unit file.
- Nginx: pass variables to PHP via `fastcgi_param`.
- Apache: use `SetEnv` (mod_env) or `PassEnv`.
- Containers: set `ENV` at runtime (not in the image) and use secrets for sensitive values.

Examples
--------
PHP‑FPM pool (Ubuntu) at `/etc/php/8.2/fpm/pool.d/www.conf`:
```ini
; Make sure clear_env is disabled so PHP sees the environment
clear_env = no
env[APP_ENV] = production
env[APP_DEBUG] = false
env[DB_HOST] = 127.0.0.1
env[DB_DATABASE] = app
env[DB_USERNAME] = app
env[DB_PASSWORD] = secret
```

Nginx location (complementary, sometimes used for a few vars):
```nginx
location ~ \.php$ {
  include snippets/fastcgi-php.conf;
  fastcgi_pass unix:/run/php/php8.2-fpm.sock;
  fastcgi_param APP_ENV production;
  fastcgi_param APP_DEBUG 0;
}
```

Apache vhost:
```apache
<VirtualHost *:80>
  DocumentRoot /var/www/app/current/public
  SetEnv APP_ENV production
  SetEnv APP_DEBUG false
</VirtualHost>
```

Note: after you cache config, Laravel reads from the cached array, not from `.env`. Keep a single source of truth.

Queues, Horizon, and cron may use different environments
-------------------------------------------------------
Common trap: web requests see the new env, but queue workers and scheduled jobs still use old values because they were started earlier.

Fix by restarting workers after changing any env or config:

```bash
php artisan queue:restart
sudo systemctl restart supervisor || true  # if you use Supervisor
```

If you deploy via a script, add these steps right after cache rebuild and migrations.

Config cache pitfalls and tips
------------------------------
- Cache after setting env: Don’t run `config:cache` if your `.env` is incomplete; you’ll freeze the wrong values.
- Don’t hardcode env in `config/*.php`: Keep `env('KEY')` calls only in config files, not in application code.
- Immutable config between releases: Avoid editing `.env` on servers; use your deploy tool or infrastructure to inject env consistently.
- Clear first, then rebuild: `config:clear` before `config:cache` helps avoid stale entries.
- Match PHP versions across web/CLI: A different PHP binary used by CLI might look at a different `php.ini` or FPM pool.

Troubleshooting checklist
-------------------------
1) Print what the app sees (in a tinker shell or temporary route):

```bash
php artisan tinker
>>> config('app.env')
>>> env('APP_ENV')  // only reliable during bootstrap and in tinker
```

2) Compare web vs CLI:

```bash
php -v
php -i | grep -i fpm
which php
```

3) Review logs for clues (permissions, parse errors, missing vars):

```bash
tail -f storage/logs/laravel.log
sudo journalctl -u php8.2-fpm -f
```

For deeper diagnostics and structured logging techniques, read: [Advanced Laravel Debugging with Logs]({{< relref "blog/laravel/advanced-laravel-debugging-with-logs.md" >}}).

Deployment flow that avoids env drift
-------------------------------------
Use a predictable deployment script:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/var/www/app/current
PHP_SVC=php8.2-fpm

cd "$APP_DIR"
composer install --no-dev --prefer-dist --optimize-autoloader
php artisan migrate --force

php artisan cache:clear && php artisan config:clear && php artisan route:clear && php artisan view:clear
php artisan config:cache && php artisan route:cache && php artisan view:cache

php artisan queue:restart || true
sudo systemctl reload $PHP_SVC || true
```

Security considerations for .env
--------------------------------
- Never commit `.env` to git. Keep a `.env.example` without secrets.
- Least privilege: limit read access to the web/process user (e.g., `chmod 640`).
- Use secrets managers when possible, or OS‑level environment variables for production.
- Don’t expose `.env` via web root. Ensure your DocumentRoot points to `public/`. If you’re setting up from scratch, follow: [Deploy Laravel to VPS with Nginx — Complete Guide]({{< relref "blog/laravel/deploy-laravel-to-vps-with-nginx-complete-guide.md" >}}).

Performance notes
-----------------
Configuration caching helps performance. Reload FPM so OPcache and workers see fresh code/config. For more tuning: [Laravel Performance Optimization: 15 Techniques]({{< relref "blog/laravel/laravel-performance-optimization-15-techniques.md" >}}).

Summary
-------
If `.env` changes don’t apply or `config:cache` breaks the app, do this: keep a single source of truth for env vars, clear then rebuild caches in order, restart workers, and reload PHP‑FPM. Prefer real environment variables in production over editing `.env` by hand. A small, repeatable deploy routine prevents most surprises.
