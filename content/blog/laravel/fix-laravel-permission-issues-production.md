---
title: "Fix Laravel Permission Issues Solving 403 and 500 Errors on Production Server"
date: 2025-09-11T08:00:00+07:00
draft: false
url: /2025/09/fix-laravel-permission-issues-production.html
description: "Getting 403 or 500 after deploy? Fix file ownership and permissions, web server config, SELinux contexts, and other common causes so your app runs cleanly in production."
keywords: ["laravel permissions", "laravel 403", "laravel 500", "laravel storage permissions", "bootstrap cache permissions", "nginx laravel try_files", "apache laravel .htaccess", "selinux laravel", "php-fpm user group", "production deployment"]
tags:
  - Laravel
  - Deployment
  - Server
  - Production
featured: false
faq:
  - question: "Why should I never use chmod 777 on Laravel files?"
    answer: "chmod 777 gives read/write/execute permissions to everyone (owner, group, world)--any process or user on server can modify/delete files. Security risks: (1) Malware uploaded via vulnerability can write to anywhere in project. (2) Other users on shared hosting can read .env (database credentials, API keys). (3) Compromised PHP-FPM can overwrite application code. (4) Doesn't fix root problem--just masks permission errors. Correct solution: (1) Ownership--chown www-data:www-data storage bootstrap/cache. (2) Permissions--chmod 775 (directories) and 664 (files) with group write. (3) ACLs for shared deploy: setfacl -R -m u:www-data:rwx storage. Why 775 not 777: (1) 775 = owner+group can write, others read-only. (2) 777 = everyone can write. Web server only needs group write access. Real-world impact: 777 files get exploited when attacker finds file upload vulnerability--they can replace index.php with malicious code. Use 775+correct ownership instead."
  - question: "What's the difference between chmod and chown and when do I need each?"
    answer: "chown changes file owner/group--who owns the file. chmod changes permissions--what owner/group/others can do (read/write/execute). Use chown first, then chmod. Example: sudo chown www-data:www-data storage (owner=www-data, group=www-data), then sudo chmod 775 storage (owner+group can rwx, others r-x). When to use: (1) After git pull by deploy user--files owned by deploy, but PHP-FPM runs as www-data. chown www-data:www-data storage so PHP can write. (2) Wrong permissions after composer install--vendor/ owned by root if sudo composer. Fix: chown deploy:deploy vendor. (3) New files created as wrong user--set setgid bit: chmod g+s storage so new files inherit group. Common mistake: only running chmod without fixing ownership--chmod 777 storage masks the real issue (wrong owner). Check current ownership: ls -la storage shows owner:group. PHP-FPM user must match: ps aux | grep php-fpm shows which user runs PHP. If www-data, chown to www-data."
  - question: "How do I identify which user PHP-FPM runs as?"
    answer: "Check running processes: ps aux | grep php-fpm | grep -v grep. Look for 'www-data', 'nginx', or 'apache' in output. Ubuntu/Debian default: www-data. CentOS/RHEL with Nginx: nginx. CentOS/RHEL with Apache: apache. Verify in config: (1) Ubuntu: grep '^user' /etc/php/8.2/fpm/pool.d/www.conf shows user = www-data. (2) CentOS: grep '^user' /etc/php-fpm.d/www.conf. Once identified, use that user for chown: sudo chown www-data:www-data storage. Common mismatch: deploy user deploys files (owned by deploy), PHP-FPM runs as www-data (can't write). Solutions: (1) chown www-data storage after deploy. (2) Add deploy to www-data group: usermod -aG www-data deploy, use group permissions. (3) ACLs: setfacl -m u:www-data:rwx -m u:deploy:rwx storage. Test: sudo -u www-data touch storage/test.txt. If 'Permission denied', ownership/permissions wrong."
  - question: "What are ACLs and when should I use them instead of chmod?"
    answer: "ACLs (Access Control Lists) allow fine-grained permissions beyond owner/group/others--can grant specific users/groups access without changing ownership. Standard permissions (chmod): only support owner, group, others. If deploy user owns files and www-data needs write access, you'd need to make deploy:www-data and chmod g+w--but multiple deploys from different users get messy. ACLs: setfacl -m u:www-data:rwx storage grants www-data write access while keeping deploy as owner. Benefits: (1) Multiple users need access without sharing group. (2) Explicit permissions per user. (3) Doesn't change ownership. (4) Default ACLs: setfacl -d -m u:www-data:rwx storage makes new files inherit permissions. Use ACLs when: (1) CI/CD deploys as different user than web server. (2) Multiple deploy users need access. (3) Want explicit grant without chmod 777. Check ACLs: getfacl storage. Remove ACLs: setfacl -b storage. Limitation: not all filesystems support ACLs (check with mount | grep acl). Works on ext4, xfs, not vfat. ACLs are superior to chmod for multi-user deploy scenarios."
  - question: "Why does Laravel work on Ubuntu but fail with 500 on CentOS with 'Permission denied'?"
    answer: "CentOS/RHEL have SELinux enabled by default--enforces mandatory access control beyond standard Linux permissions. Even with chmod 777, SELinux blocks if security context wrong. Check SELinux status: getenforce shows Enforcing/Permissive/Disabled. Check denials: sudo ausearch -m avc -ts recent shows blocked operations. Fix: label writable directories: sudo chcon -R -t httpd_sys_rw_content_t storage bootstrap/cache. This tells SELinux 'allow httpd/PHP-FPM to write here'. Persistent labels: sudo semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/app/storage(/.*)?' && sudo restorecon -R storage. Enable unified httpd context: sudo setsebool -P httpd_unified 1 allows PHP-FPM to read/write all httpd files. Never disable SELinux: setenforce 0 removes protection. Always use correct contexts. Ubuntu doesn't have SELinux by default (uses AppArmor, less strict). Deploy from Ubuntu -> CentOS often fails because developers forget SELinux. Debug: check /var/log/audit/audit.log for 'avc: denied' messages."
  - question: "What's the best permission setup for Laravel shared hosting or deploy user scenario?"
    answer: "Shared hosting/deploy user scenario: files owned by deploy user, PHP-FPM runs as www-data, both need write to storage/. Best setup using ACLs: (1) Keep project owned by deploy: chown -R deploy:deploy /var/www/app. (2) Grant www-data write via ACL: setfacl -R -m u:www-data:rwx storage bootstrap/cache. (3) Set default ACL for new files: setfacl -dR -m u:www-data:rwx storage bootstrap/cache. (4) Directories 755, files 644 for application code: find . -type d -not -path './storage/*' -not -path './bootstrap/cache' -exec chmod 755 {} \\; && find . -type f -not -path './storage/*' -not -path './bootstrap/cache' -exec chmod 644 {} \\;. (5) storage/ and bootstrap/cache: 775 directories, 664 files with ACLs. Alternative using groups: (1) Add deploy to www-data group: usermod -aG www-data deploy. (2) chown -R deploy:www-data storage bootstrap/cache. (3) chmod -R g+rwX storage bootstrap/cache. (4) setgid bit: find storage bootstrap/cache -type d -exec chmod g+s {} \\; so new files inherit group. Benefits: deploy user can edit files, www-data can write to storage, other users blocked. Avoid: 777 (anyone can write), wrong owner (PHP can't write), missing ACLs (deploy breaks after next push)."
---

If a fresh deploy returns 403 or 500, the cause is usually predictable: wrong ownership/permissions, web server misconfig, missing PHP extensions, or SELinux. Use the checklist below to find and fix it quickly. Examples cover Ubuntu/Debian (Nginx/Apache with PHP‑FPM) and CentOS/RHEL (SELinux).

<!--readmore-->

Why 403 vs 500
--------------
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

Never use `777`. Prefer `775` for directories and `664` for files, with correct ownership/ACLs.

Serve from public/ and use try_files
------------------------------------
Laravel must be served from the `public/` directory. If you point Nginx/Apache to the project root, you’ll get 403/404 and expose sensitive files.

For an end‑to‑end walkthrough of provisioning and deploying with Nginx and PHP‑FPM, see [Deploy Laravel to VPS with Nginx -- Complete Guide]({{< relref "blog/laravel/deploy-laravel-to-vps-with-nginx-complete-guide.md" >}}).

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

If you moved configs, confirm the socket path (or host:port) matches your PHP‑FPM version. A wrong `fastcgi_pass` leads to 502/500.

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
Most 403/500 issues after a Laravel deploy are solved by four things: serve from `public/` with a correct `try_files`; give PHP‑FPM write access to `storage/` and `bootstrap/cache` with safe permissions; ensure your environment and PHP extensions are correct; and, on CentOS/RHEL, fix SELinux contexts. With those in place--and a small deploy script--you’ll have stable, repeatable releases without resorting to risky `777` permissions.

Further reading
---------------
- [Deploy Laravel to VPS with Nginx -- Complete Guide]({{< relref "blog/laravel/deploy-laravel-to-vps-with-nginx-complete-guide.md" >}})
- [Laravel Performance Optimization: 15 Techniques]({{< relref "blog/laravel/laravel-performance-optimization-15-techniques.md" >}})
- [Advanced Laravel Debugging with Logs]({{< relref "blog/laravel/advanced-laravel-debugging-with-logs.md" >}})
- [Laravel Security Best Practices for Production]({{< relref "blog/laravel/laravel-security-best-practices-production.md" >}})
