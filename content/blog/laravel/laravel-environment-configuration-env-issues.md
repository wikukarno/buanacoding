---
title: "Laravel Environment Configuration Fixing .env and Config Cache Issues"
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
faq:
  - question: "Why does my .env change not take effect after config:cache?"
    answer: "php artisan config:cache compiles all config/*.php files into bootstrap/cache/config.php and stops reading .env on every request. Laravel reads this cached PHP array directly--your .env file is never touched again until you clear the cache. When cached: (1) .env changes ignored. (2) env() calls in config files frozen at cache time. (3) App uses bootstrap/cache/config.php exclusively. Fix: php artisan config:clear (deletes cache file, app reads .env again) -> edit .env -> php artisan config:cache (rebuilds cache with new values). Never edit .env while config cached without clearing first. Production workflow: (1) Update .env or environment variables. (2) php artisan config:clear. (3) Test the change. (4) php artisan config:cache. (5) Restart workers: php artisan queue:restart. (6) Reload PHP-FPM: systemctl reload php-fpm. Common mistake: editing .env, running config:cache immediately--new cache has old values if they weren't picked up yet. Always clear first."
  - question: "Should I call env() directly in controllers or use config()?"
    answer: "Never use env() in controllers, models, or application code--only in config/*.php files. Use config() everywhere else. Reason: (1) When config cached (config:cache), env() returns null outside config files. (2) Config is the abstraction layer--keeps config separated from environment. (3) Testing easier--mock config(), can't mock env(). (4) Better defaults--config('app.env', 'production') vs env('APP_ENV') ?: 'production'. Pattern: Define in config: config/services.php: ['stripe' => ['key' => env('STRIPE_KEY')]]. Use in code: config('services.stripe.key'). Wrong: env('STRIPE_KEY') in controller--works locally, breaks in production after config:cache. Laravel's design: env() bootstraps config files once, config() provides values everywhere. Exception: rare cases in service providers' boot() might use env() for conditional logic, but prefer config(). Testing: MockConfig in tests, not environment. Config cached in production is standard practice for performance--don't avoid caching to use env() everywhere."
  - question: "Why do my web requests see different environment values than queue workers?"
    answer: "Web requests (PHP-FPM) and queue workers (php artisan queue:work) are separate PHP processes that started at different times with potentially different environments. Causes: (1) Config cached before .env change--web sees new values, workers started earlier use old cached config. (2) Different .env files--web in /var/www/app, worker in /var/www/old-release. (3) Different systemd units--worker service has Environment= vars that differ from PHP-FPM pool. (4) Worker not restarted--changed .env, restarted PHP-FPM, forgot queue:restart. (5) OPcache caches old config--workers cache bootstrap/cache/config.php, need process restart to reload. Fix: (1) After config changes: php artisan queue:restart (graceful--finishes current jobs, spawns new workers). (2) If using Horizon: php artisan horizon:terminate && php artisan horizon. (3) If Supervisor: supervisorctl restart laravel-worker:*. (4) Verify: in queue job, Log::info(config('app.env')) to see what worker sees. Prevention: deployment script should restart all long-running processes after config changes."
  - question: "What's the difference between .env, .env.example, and .env.production?"
    answer: ".env--actual environment file with real secrets (database passwords, API keys). Never commit to git. Gitignored. Each environment (local, staging, production) has its own .env with different values. Laravel reads this on bootstrap (unless config cached). .env.example--template file without secrets. Committed to git. Documents required environment variables with safe placeholder values. New developers copy: cp .env.example .env, then fill in their local values. .env.production--convention file not used by Laravel by default. Some teams keep it in private repo or secrets manager as template for production values. Laravel doesn't automatically use .env.production--you'd need to rename it to .env or set environment differently. Better approach: don't use .env in production at all--set environment variables via systemd/Docker/AWS secrets, not files on disk. Workflow: (1) Development: .env with local values. (2) Production: systemd Environment= vars or Docker env, no .env file. (3) Git: commit .env.example only. Security: .env contains secrets--chmod 600, never commit, rotate if exposed. .env.example safe to share--no real credentials."
  - question: "How do I debug 'No application encryption key has been specified' error?"
    answer: "This error means APP_KEY in .env is empty, malformed, or config cache has stale empty value. Causes ranked: (1) .env missing APP_KEY--new project, forgot php artisan key:generate. (2) Config cached with empty APP_KEY--ran config:cache before generating key. (3) APP_KEY corrupted--wrong format (must be base64:xxxx), truncated, or has trailing spaces. (4) Wrong .env read--production reads /var/www/old/.env, deployed code in /var/www/new. (5) Environment variable overrides .env--systemd/Docker sets APP_KEY='' empty. Debug: (1) Check .env: cat .env | grep APP_KEY, should show 'base64:long-string'. (2) Check cached config: php artisan tinker, config('app.key'). (3) Check if cached: ls bootstrap/cache/config.php (if exists, config is cached). Fix: (1) php artisan key:generate --force (creates key, updates .env). (2) php artisan config:clear (clear stale cache). (3) php artisan config:cache (rebuild if production). (4) Restart PHP-FPM. Warning: changing APP_KEY invalidates all encrypted data (sessions, cookies, encrypted DB columns)--never rotate in production unless you know impact. Generate once, keep stable."
  - question: "What happens if I accidentally commit .env with secrets to Git?"
    answer: "Immediate security risk--anyone with repo access (or public GitHub) can read database credentials, API keys, APP_KEY, payment processor secrets. Even if you delete the file in next commit, it remains in Git history forever. Response steps: (1) Rotate ALL secrets immediately--database passwords, API keys (Stripe, AWS, Mailgun), APP_KEY, OAuth secrets. (2) Revoke old credentials in respective services before new ones work. (3) Remove .env from Git history--use git filter-branch or BFG Repo-Cleaner: git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch .env' --prune-empty --tag-name-filter cat -- --all, then force push: git push origin --force --all. (4) Notify team to re-clone repo (old clones still have .env in history). (5) Add .env to .gitignore if not already. (6) Scan logs for suspicious access (database connections, API calls from unknown IPs). (7) Enable 2FA on critical accounts. Prevention: (1) .gitignore should always include .env. (2) Pre-commit hooks: check for .env, secrets patterns. (3) GitHub secret scanning--warns if secrets detected. (4) Use .env.example, never .env. Cost: database breach, unauthorized API charges, compromised user data. This is critical security incident requiring immediate action."
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
- Don’t expose `.env` via web root. Ensure your DocumentRoot points to `public/`. If you’re setting up from scratch, follow: [Deploy Laravel to VPS with Nginx -- Complete Guide]({{< relref "blog/laravel/deploy-laravel-to-vps-with-nginx-complete-guide.md" >}}).

Performance notes
-----------------
Configuration caching helps performance. Reload FPM so OPcache and workers see fresh code/config. For more tuning: [Laravel Performance Optimization: 15 Techniques]({{< relref "blog/laravel/laravel-performance-optimization-15-techniques.md" >}}).

Summary
-------
If `.env` changes don’t apply or `config:cache` breaks the app, do this: keep a single source of truth for env vars, clear then rebuild caches in order, restart workers, and reload PHP‑FPM. Prefer real environment variables in production over editing `.env` by hand. A small, repeatable deploy routine prevents most surprises.
