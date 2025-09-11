---
title: "Fix Laravel Permission Issues: Solving 403 and 500 Errors on Production Server"
date: 2025-09-11T08:00:00+07:00
draft: false
url: /2025/09/fix-laravel-permission-issues-production.html
description: "Getting 403 or 500 after deploying Laravel? This guide shows how to fix file ownership, permissions, web server config, SELinux contexts, and common pitfalls so your app runs reliably in production."
keywords: ["laravel permissions", "laravel 403", "laravel 500", "laravel storage permissions", "bootstrap cache permissions", "nginx laravel try_files", "apache laravel .htaccess", "selinux laravel", "php-fpm user group", "production deployment"]
tags:
  - Laravel
  - Deployment
  - Server
  - Production
featured: false
---

When a fresh Laravel deployment returns 403 Forbidden or 500 Internal Server Error, it almost always comes down to a few predictable issues: wrong file ownership and permissions, an incorrect web server configuration, missing PHP extensions, or security layers like SELinux getting in the way. The good news is you can diagnose and fix these quickly with a structured checklist.

This step-by-step guide explains how to resolve 403 and 500 errors on Ubuntu/Debian (Nginx/Apache with PHP‑FPM) and CentOS/RHEL (with SELinux), including safe permission settings you can reuse for every release.

<!--readmore-->

Why you see 403 vs 500
-----------------------
- 403 Forbidden from the web server: The server blocked access before Laravel ran. Common causes: wrong document root (not pointing to `public/`), missing `try_files`, directory or file not readable, SELinux contexts, or a security module (WAF/mod_security/Cloudflare) rejecting the request.
- 403 from Laravel: Authorization middleware/policies, CSRF token failures, or custom gates deny the action.
- 500 Internal Server Error: PHP crashed or threw an exception. Common causes: wrong permissions on `storage/` or `bootstrap/cache`, missing PHP extensions, invalid `.env`, wrong `APP_KEY`, or syntax/runtime errors.

Quick fix checklist (safe defaults)
-----------------------------------
Run these commands from your project root (adjust the PHP‑FPM user for your distro):

```bash
# 1) Identify your web user
ps aux | egrep "php-fpm|php-fpm8|php7|php8|apache2|httpd" | grep -v grep
# Ubuntu/Debian (Nginx/Apache): usually www-data
# CentOS/RHEL (Nginx): usually nginx

# 2) Set correct ownership for writable paths
sudo chown -R www-data:www-data storage bootstrap/cache

# 3) Apply safe, group-writable permissions
sudo find storage bootstrap/cache -type d -exec chmod 775 {} \;
sudo find storage bootstrap/cache -type f -exec chmod 664 {} \;

# 4) If you deploy as a different user (e.g., deploy), share write access via ACLs
sudo setfacl -R -m u:www-data:rwx -m u:$(whoami):rwx storage bootstrap/cache
sudo setfacl -dR -m u:www-data:rwx -m u:$(whoami):rwx storage bootstrap/cache

# 5) Clear and rebuild caches (after fixing perms)
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear
php artisan optimize

# 6) Reload PHP-FPM to refresh OPcache
sudo systemctl reload php8.2-fpm || sudo systemctl reload php8.1-fpm || true
```

Never use `777`. It opens write access to everyone and can be exploited. Prefer `775` for directories and `664` for files, with correct ownership/ACLs.

Point the server to public/ and use try_files
---------------------------------------------
Laravel must be served from the `public/` directory. If you point Nginx/Apache to the project root, you’ll get 403/404 and expose sensitive files.

For an end‑to‑end walkthrough of provisioning and deploying with Nginx and PHP‑FPM, see [Deploy Laravel to VPS with Nginx — Complete Guide]({{< relref "blog/laravel/deploy-laravel-to-vps-with-nginx-complete-guide.md" >}}).

Nginx example (Ubuntu):

```nginx
server {
  server_name example.com;
  root /var/www/app/current/public;
  index index.php index.html;

  location / {
    try_files $uri $uri/ /index.php?$query_string;
  }

  location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php8.2-fpm.sock;
  }

  location ~* \.(?!well-known).* { # optional security hardening
    access_log off;
  }
}
```

Apache example:

```apache
<VirtualHost *:80>
  ServerName example.com
  DocumentRoot /var/www/app/current/public

  <Directory /var/www/app/current/public>
    AllowOverride All
    Require all granted
  </Directory>
</VirtualHost>
```

If you migrated configs, confirm that the socket path (or host:port) matches your PHP‑FPM version. A wrong `fastcgi_pass` leads to 502/500 depending on the stack.

Fix permissions the right way
-----------------------------
Laravel writes logs, cache, compiled views, and sessions to `storage/` and `bootstrap/cache`. If PHP‑FPM cannot write there, you’ll see 500 and log errors like “Permission denied”.

Recommended pattern:
- Ownership: `www-data:www-data` (Ubuntu/Debian) or `nginx:nginx` (CentOS/RHEL) on `storage/` and `bootstrap/cache`.
- Permissions: `775` for directories, `664` for files.
- Shared deploy scenario: If you deploy as `deploy` user, keep the project owned by `deploy:deploy`, add `www-data` to the group, and use setgid or ACLs:

```bash
sudo usermod -aG www-data deploy
sudo chgrp -R www-data storage bootstrap/cache
sudo chmod -R g+rwX storage bootstrap/cache
# Ensure new files inherit the group (setgid bit)
sudo find storage bootstrap/cache -type d -exec chmod g+s {} \;
```

Or prefer ACL (more explicit and less brittle across releases):

```bash
sudo setfacl -R -m u:www-data:rwx storage bootstrap/cache
sudo setfacl -dR -m u:www-data:rwx storage bootstrap/cache
```

SELinux on CentOS/RHEL
----------------------
If SELinux is enforcing, standard chmod/chown may not be enough. Label writable paths for the web server context:

```bash
sudo chcon -R -t httpd_sys_rw_content_t storage bootstrap/cache
sudo setsebool -P httpd_unified 1  # optional; unify contexts for httpd/php-fpm
```

Avoid disabling SELinux; prefer correct contexts. Check denials with `sudo ausearch -m avc -ts recent` or review `/var/log/audit/audit.log`.

Environment sanity checks
-------------------------
- `APP_KEY`: Must be set in production. If missing, sessions and encryption fail and can trigger 500. Generate once and keep it stable:

```bash
php artisan key:generate --force
```

- `.env` permissions: Make it readable by the PHP‑FPM user but not world‑readable:

```bash
sudo chown deploy:www-data .env
sudo chmod 640 .env
```

- `APP_DEBUG=false`: Always disable debug in production. Keep detailed errors in logs, not on screen.

If you keep hitting configuration pitfalls, review your config cache and `.env` handling practices, and prefer immutable environment variables in your runtime (e.g., systemd or Docker) over editing files in production.

Cache and optimize properly
---------------------------
After deployments, clear stale caches and rebuild:

```bash
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear

php artisan config:cache
php artisan route:cache
php artisan view:cache

# Reload FPM to refresh OPcache
sudo systemctl reload php8.2-fpm || sudo systemctl reload php8.1-fpm || true
```

Want to push performance further? Try this next:
- [Laravel Performance Optimization: 15 Techniques]({{< relref "blog/laravel/laravel-performance-optimization-15-techniques.md" >}})

Double‑check Composer and PHP extensions
---------------------------------------
A 500 can also come from missing extensions (e.g., `pdo_mysql`, `mbstring`, `openssl`, `intl`, `xml`, `ctype`, `json`, `tokenizer`, `bcmath`). Install the right set for your PHP version:

```bash
# Ubuntu example (adjust php version)
sudo apt-get update
sudo apt-get install -y php8.2-fpm php8.2-cli php8.2-mysql php8.2-xml php8.2-mbstring php8.2-curl php8.2-intl php8.2-zip php8.2-bcmath

# Deploy dependencies without dev and optimize autoloader
composer install --no-dev --prefer-dist --optimize-autoloader
```

Read the right logs
-------------------
When you still get 403/500, the logs tell you why:

```bash
# Laravel app errors
tail -f storage/logs/laravel.log

# Nginx errors
sudo journalctl -u nginx -f
sudo tail -f /var/log/nginx/error.log

# Apache errors
sudo journalctl -u apache2 -f
sudo tail -f /var/log/apache2/error.log

# PHP-FPM errors
sudo journalctl -u php8.2-fpm -f
sudo tail -f /var/log/php8.2-fpm.log 2>/dev/null || true
```

For deeper diagnostics and better logs, see: [Advanced Laravel Debugging with Logs]({{< relref "blog/laravel/advanced-laravel-debugging-with-logs.md" >}}).

403 from Laravel vs server
--------------------------
If the 403 is generated by Laravel (you’ll see it in `laravel.log`), check:
- Policies/Gates: confirm the authenticated user really has access.
- Middleware: role checks or custom guards.
- CSRF: webhooks and third‑party callbacks often need to be excluded from `VerifyCsrfToken`.
- CORS: a failed preflight can look like a blocked request; verify your CORS settings if you serve APIs.

Broader troubleshooting tip: keep error logs clean, avoid noisy debugging in production, and reproduce issues locally with the same PHP version and extensions.

Hardening and good practices
----------------------------
- Avoid `chmod -R 777`. Use group write with setgid or ACLs instead.
- Keep `storage/` and `bootstrap/cache` writable only by the web user and deploy user.
- Rotate logs to avoid full disks (e.g., logrotate). A full disk yields 500s when Laravel cannot write logs.
- Run queues/scheduled jobs under the same user that has access to `storage/`.
- Validate symlinks if you deploy with releases: ensure `current/` points to the latest and `storage` links are intact.

Security hardening reference:
- [Laravel Security Best Practices for Production]({{< relref "blog/laravel/laravel-security-best-practices-production.md" >}})

Example deploy snippet
----------------------
This minimal script makes repeated deployments predictable:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/var/www/app/current
PHP_SVC=php8.2-fpm
WEB_USER=www-data

cd "$APP_DIR"
composer install --no-dev --prefer-dist --optimize-autoloader
php artisan migrate --force

# Permissions
sudo chown -R $WEB_USER:$WEB_USER storage bootstrap/cache
sudo find storage bootstrap/cache -type d -exec chmod 775 {} \;
sudo find storage bootstrap/cache -type f -exec chmod 664 {} \;

# Caches
php artisan cache:clear && php artisan config:clear && php artisan route:clear && php artisan view:clear
php artisan optimize

sudo systemctl reload $PHP_SVC
```

If you run workers, ensure the worker user has the same permissions as your web user, and reload workers after deployments to pick up new code and config.

Summary
-------
Most 403/500 issues after a Laravel deploy are solved by four things: serve from `public/` with a correct `try_files`; give PHP‑FPM write access to `storage/` and `bootstrap/cache` with safe permissions; ensure your environment and PHP extensions are correct; and, on CentOS/RHEL, fix SELinux contexts. With those in place—and a small deploy script—you’ll have stable, repeatable releases without resorting to risky `777` permissions.

Further reading
---------------
- [Deploy Laravel to VPS with Nginx — Complete Guide]({{< relref "blog/laravel/deploy-laravel-to-vps-with-nginx-complete-guide.md" >}})
- [Laravel Performance Optimization: 15 Techniques]({{< relref "blog/laravel/laravel-performance-optimization-15-techniques.md" >}})
- [Advanced Laravel Debugging with Logs]({{< relref "blog/laravel/advanced-laravel-debugging-with-logs.md" >}})
- [Laravel Security Best Practices for Production]({{< relref "blog/laravel/laravel-security-best-practices-production.md" >}})
