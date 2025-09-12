---
title: "Fixing Laravel Session and Cache Issues: Complete Troubleshooting Guide"
date: 2025-09-12T12:00:00+07:00
draft: false
url: /2025/09/fixing-laravel-session-cache-issues.html
description: "Users keep getting logged out? Cache values won’t update? This hands‑on guide shows how to diagnose and fix Laravel session and cache problems in production—covering drivers, permissions, cookies, proxies, Redis, and safe cache workflows."
keywords: ["laravel session not working", "laravel logged out automatically", "laravel cache not updating", "laravel session driver", "laravel redis session cache", "SESSION_DOMAIN", "SESSION_SECURE_COOKIE", "config cache issues", "php fpm reload", "sticky sessions"]
tags:
  - Laravel
  - Session
  - Cache
  - Troubleshooting
featured: false
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
