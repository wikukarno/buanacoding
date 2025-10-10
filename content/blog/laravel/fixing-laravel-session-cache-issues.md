---
title: "Fixing Laravel Session and Cache Issues Complete Troubleshooting Guide"
date: 2025-09-12T12:00:00+07:00
draft: false
url: /2025/09/fixing-laravel-session-cache-issues.html
description: "Users keep getting logged out? Cache values won't update? This hands‑on guide shows how to diagnose and fix Laravel session and cache problems in production—covering drivers, permissions, cookies, proxies, Redis, and safe cache workflows."
keywords: ["laravel session not working", "laravel logged out automatically", "laravel cache not updating", "laravel session driver", "laravel redis session cache", "SESSION_DOMAIN", "SESSION_SECURE_COOKIE", "config cache issues", "php fpm reload", "sticky sessions"]
tags:
  - Laravel
  - Session
  - Cache
  - Troubleshooting
featured: false
faq:
  - question: "Why do users keep getting logged out randomly in Laravel?"
    answer: "Common causes ranked by frequency: (1) SESSION_SECURE_COOKIE=true on HTTP site (not HTTPS)—browser rejects insecure cookies. Fix: use HTTPS or set false for development. (2) SESSION_DOMAIN mismatch—logged in on www.example.com but SESSION_DOMAIN=example.com (or vice versa). Fix: use .example.com (leading dot) to cover all subdomains. (3) storage/framework/sessions not writable—PHP can't save sessions. Fix: chown www-data:www-data storage && chmod 775 storage/framework/sessions. (4) Load balancer without sticky sessions + file session driver—each request hits different server. Fix: use Redis/database driver or enable sticky sessions. (5) Cached config outdated—cleared .env but config:cache still has old values. Fix: php artisan config:clear && config:cache. (6) PHP session garbage collection deletes active sessions—SESSION_LIFETIME too short. Fix: increase to 120-720 minutes. (7) SESSION_SAME_SITE=strict breaks OAuth redirects. Fix: use lax. Debug: check browser DevTools → Application → Cookies, see if session cookie appears and has correct domain/secure flags."
  - question: "What's the difference between cache:clear and config:clear?"
    answer: "cache:clear flushes application cache—data stored via Cache::put(), Cache::remember(), etc. in your cache driver (Redis/file/memcached). Doesn't touch Laravel's internal config cache. config:clear removes cached configuration from bootstrap/cache/config.php—configs loaded from config/*.php and .env. Laravel caches these for performance with php artisan config:cache. When to use each: (1) cache:clear after deploying new code that changes cached business logic/queries. (2) config:clear after changing .env or config/*.php files. (3) Both after deployment. Common mistake: changing .env, running cache:clear, config still old—need config:clear. Other clears: route:clear (routes), view:clear (compiled Blade), optimize:clear (all of above). Best practice: php artisan optimize:clear clears everything, then php artisan optimize rebuilds. In production: always run config:cache and route:cache after clear for performance. Never cache routes if using closures—will break."
  - question: "Why does cache work in tinker but not in the browser?"
    answer: "Web and CLI use different PHP processes with potentially different configs. Causes: (1) Different PHP versions—CLI uses /usr/bin/php 8.1, web uses PHP-FPM 8.2 with different .env path. Check: php -v vs php-fpm -v. (2) Different .env files—CLI reads /var/www/app/.env, web reads cached config from different location. (3) CACHE_DRIVER different—.env has CACHE_DRIVER=redis but CLI defaults to file. (4) Redis connection wrong for web—web can't connect to Redis due to network/firewall, CLI can. (5) OPcache caches old config for PHP-FPM—CLI bypasses OPcache. Fix: sudo systemctl reload php8.2-fpm. (6) Permissions—CLI runs as deploy user (can write), PHP-FPM runs as www-data (can't write to cache directory). Debug steps: (1) In browser route, return config('cache.default') and compare to CLI. (2) Check Cache::getStore()->getConnection() for Redis. (3) Run tinker as web user: sudo -u www-data php artisan tinker. (4) Enable query logging to see if cache reads hit database."
  - question: "Should I use file, database, or Redis for Laravel sessions in production?"
    answer: "Redis is best for production—fast, scalable, supports multiple servers. Database is second best—centralized, handles load balancers, easier than Redis setup. File is fine for single-server small apps. Comparison: File sessions—simplest setup (default), but (1) doesn't scale across servers (load balancer needs sticky sessions), (2) slow with 1000+ concurrent users (file lock contention), (3) can fill disk if not pruned. Use for: single server, <1000 users. Database sessions—(1) scales across servers (centralized), (2) easier backup than files, (3) slower than Redis (database query per request), (4) requires session table migration. Use for: multi-server without Redis. Redis sessions—(1) fastest (in-memory), (2) scales horizontally, (3) built-in TTL/expiry, (4) requires Redis server. Use for: high-traffic apps, multiple servers, need best performance. Setup Redis: SESSION_DRIVER=redis, SESSION_CONNECTION=default, configure database.php redis connection. Hybrid approach: use Redis with database fallback in app code for critical data. Never use cookie driver for production—4KB limit, exposes session data to client."
  - question: "Why do my cache changes in code not reflect after deployment?"
    answer: "Multiple layers cache in Laravel: (1) OPcache caches compiled PHP bytecode—code changes don't show until PHP-FPM restarts. Fix: sudo systemctl reload php8.2-fpm. (2) Config cache (bootstrap/cache/config.php)—if CACHE_DRIVER changed in .env but config cached, app uses old driver. Fix: php artisan config:clear. (3) Route cache—if cache keys hardcoded in routes, cached routes use old keys. Fix: php artisan route:clear. (4) View cache—Blade @cache directive or custom view caching. Fix: php artisan view:clear. (5) Application cache—Cache::remember() with long TTL means data won't refresh. Fix: cache:clear or use shorter TTLs. (6) CDN/browser cache—frontend caches old API responses. Fix: add Cache-Control headers, increment asset version. (7) Queue workers cache old code—must restart after deploy. Fix: php artisan queue:restart. Deployment checklist: (1) git pull. (2) composer install. (3) php artisan migrate. (4) php artisan optimize:clear (clears all). (5) php artisan optimize (rebuilds). (6) php artisan queue:restart. (7) sudo systemctl reload php-fpm. Without these steps, deployments silently fail—users see old code."
  - question: "How do I debug 'Session store not set on request' error?"
    answer: "This error means Laravel can't initialize session middleware. Causes ranked by frequency: (1) SESSION_DRIVER invalid/typo—SESSION_DRIVER=redi (typo) instead of redis. Fix: check .env for typos. (2) Session middleware not in middleware groups—removed StartSession from global middleware. Fix: ensure StartSession::class in app/Http/Kernel.php web middleware group (Laravel 10-) or bootstrap/app.php (Laravel 11+). (3) Config cached with invalid driver—previous deploy had wrong SESSION_DRIVER, config:cache locked it in. Fix: php artisan config:clear && verify .env && config:cache. (4) Redis connection failed—SESSION_DRIVER=redis but Redis server down. Fix: check Redis: redis-cli PING, verify REDIS_HOST/PORT in .env. (5) Database session table missing—SESSION_DRIVER=database but migrations not run. Fix: php artisan session:table && migrate. (6) Custom session driver not registered—using custom driver but provider not loaded. Fix: register ServiceProvider in config/app.php or bootstrap. (7) Running PHP artisan command that doesn't boot web middleware—some commands skip sessions. This is normal. Debug: (1) Check storage/logs/laravel.log for full stack trace. (2) Add dd(config('session')) in routes to see config. (3) Test: switch SESSION_DRIVER=file temporarily to isolate driver issue."
---

Sessions and cache power many core features in Laravel—from authentication to performance. When they break, symptoms can be confusing: users get logged out randomly, “remember me” does nothing, flash messages disappear, or recent cache writes don’t show up. Use the checklist below to quickly find and fix the cause.

<!--readmore-->

How sessions and cache fail
---------------------------
- Sessions persist state across requests. Laravel can store them in files, database, Redis, Memcached, or array (for tests). If the storage can’t be written or the cookie can’t be read back, the user appears “logged out”.
- Cache stores computed data for speed. If the driver points to a different backend than you expect, or the key gets namespaced differently, you’ll read stale or missing values.

Quick fixes that solve most cases
---------------------------------
Run these from your app root (adjust user/group):

```bash
# Writable directories for file sessions/view cache
sudo chown -R www-data:www-data storage bootstrap/cache
sudo find storage bootstrap/cache -type d -exec chmod 775 {} \;
sudo find storage bootstrap/cache -type f -exec chmod 664 {} \;

# Clear stale caches before re‑testing
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear

# Rebuild when stable
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Reload FPM so workers/OPcache see changes
sudo systemctl reload php8.2-fpm || sudo systemctl reload php8.1-fpm || true
```

If permissions were the problem, random logouts and “unable to create directory” errors should be gone. See: [Fix Laravel Permission Issues]({{< relref "blog/laravel/fix-laravel-permission-issues-production.md" >}}).

Verify your drivers and stores
------------------------------
Open your `.env` and confirm the intended drivers:

```env
SESSION_DRIVER=file        # file|cookie|database|redis|memcached
SESSION_LIFETIME=120       # minutes
CACHE_DRIVER=file          # file|redis|memcached|database|array
CACHE_PREFIX=laravel_      # especially important on shared Redis
```

Common pitfalls by driver
-------------------------
File (default):
- Make sure `storage/framework/sessions` is writable by PHP‑FPM.
- On high‑traffic setups, file sessions can become slow; consider Redis or database.

Database:
- Run `php artisan session:table && php artisan migrate`.
- Verify the connection used in `config/database.php` matches what workers and web use.

Redis:
- Ensure the same Redis host/port/db is used by all app processes (web, queue, scheduler).
- Use a `CACHE_PREFIX` and `SESSION_CONNECTION`/`SESSION_PREFIX` to avoid key collisions.
- If you run multiple apps on one Redis, prefixes are essential.

Cookie:
- Session data lives in the cookie itself; if it exceeds browser limits (~4 KB), data may be truncated. Use another driver for larger payloads.

Cookie settings that break logins
---------------------------------
Check these keys in `.env` and `config/session.php`:

```env
APP_URL=https://example.com
SESSION_DOMAIN=.example.com        # include leading dot to cover subdomains
SESSION_SECURE_COOKIE=true         # true if you use HTTPS
SESSION_SAME_SITE=lax              # lax|strict|none (none requires secure cookie)
SESSION_PATH=/
```

Guidelines:
- On HTTPS, set `SESSION_SECURE_COOKIE=true`. If not, browsers may refuse to send cookies back.
- For subdomains, use `.example.com` as `SESSION_DOMAIN`. Mismatches cause “works on www, breaks on root” issues.
- If you embed cross‑site (rare for app UIs), `SAME_SITE=none` requires `SECURE_COOKIE=true`.

Proxies, load balancers, and sticky sessions
--------------------------------------------
Behind a load balancer, two things can break sessions:

1) Cookies stripped or altered by proxy headers. Configure trusted proxies so Laravel reads headers correctly.

```php
// app/Http/Middleware/TrustProxies.php
protected $proxies = '*';
protected $headers = \Illuminate\Http\Request::HEADER_X_FORWARDED_AWS_ELB;
```

2) Non‑sticky load balancing with file/database sessions. If each request hits a different server with different session store, users appear logged out. Solutions:
- Use a centralized store (Redis) for sessions.
- Or enable sticky sessions at the load balancer.

Cache not updating (stale data)
-------------------------------
First confirm which store you’re reading from. Quick tinker check:

```bash
php artisan tinker
>>> cache()->put('probe', now()->timestamp, 600)
>>> cache()->get('probe')
```

If this works in CLI but not over HTTP, your web and CLI are using different PHP environments or configs. Check `which php`, PHP versions, and `.env` visibility for both. Also ensure workers (Horizon/queue) were restarted after changing config.

Redis tips:
- Use `CACHE_PREFIX` to prevent collisions, especially when multiple apps share Redis.
- Check the selected database index (`database` in `config/database.php` for Redis) and that all processes agree.
- Inspect keys via `redis-cli KEYS "laravel_*" | head` for a quick sanity check.

Don’t mix up config cache with app cache
----------------------------------------
`php artisan config:cache` caches configuration, not your application cache keys. If `.env` changes “don’t work”, clear and rebuild config cache. For app data, use `php artisan cache:clear` or invalidate specific keys.

Queues and schedulers read stale config
--------------------------------------
After changing `.env` or config, restart workers so they reload the container:

```bash
php artisan queue:restart
sudo systemctl restart supervisor || true
```

For background on environment handling (and why CLI and web can differ), see: [Laravel Environment Configuration]({{< relref "blog/laravel/laravel-environment-configuration-env-issues.md" >}}).

Test route to prove where the problem is
---------------------------------------
Add a temporary route and controller/closure to reproduce:

```php
// routes/web.php
Route::get('/session-test', function (\Illuminate\Http\Request $request) {
    $count = session()->get('count', 0) + 1;
    session(['count' => $count]);
    cache()->put('session_probe', $count, 600);
    return [
        'count' => $count,
        'session_id' => $request->session()->getId(),
        'cache_probe' => cache()->get('session_probe'),
        'driver' => config('session.driver'),
        'domain' => config('session.domain'),
        'secure' => config('session.secure'),
        'same_site' => config('session.same_site'),
    ];
});
```

Reload the page several times. If `count` resets to 1, the session cookie never comes back or the backend can’t persist. Use devtools (Application → Cookies) to inspect cookie domain/secure flags.

Clean up stale sessions and caches
----------------------------------
Over time, old files and keys pile up:
- File sessions: schedule a cleanup via Laravel’s scheduler or systemd timer that runs `php artisan session:prune` (Laravel 11+) or a custom command to delete expired files.
- Redis: set TTLs (sessions already expire), and occasionally sample keys with `SCAN` to ensure prefixes are consistent.
- Views/cache: add a deploy step that clears and then rebuilds caches to avoid mixing stale artifacts with new code.

Production checklist
--------------------
```bash
# 1) Permissions (file sessions/views)
sudo chown -R www-data:www-data storage bootstrap/cache
sudo find storage bootstrap/cache -type d -exec chmod 775 {} \;
sudo find storage bootstrap/cache -type f -exec chmod 664 {} \;

# 2) Drivers and cookies
grep -E "^(SESSION_|CACHE_|APP_URL=)" .env || true

# 3) Clear/rebuild caches
php artisan cache:clear && php artisan config:clear && php artisan route:clear && php artisan view:clear
php artisan config:cache && php artisan route:cache && php artisan view:cache

# 4) Restart workers and reload FPM
php artisan queue:restart || true
sudo systemctl reload php8.2-fpm || true

# 5) Verify Redis if used
redis-cli PING || true
```

Summary
-------
Most session and cache issues boil down to: wrong permissions or drivers, cookie settings (domain/secure/same‑site), different environments between web and CLI/workers, or stale caches. Fix storage/permissions first, confirm drivers, set cookies correctly, clear then rebuild caches, restart workers, and reload PHP‑FPM. Use the small test route to see exactly where it fails.
