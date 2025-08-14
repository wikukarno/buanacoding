---
title: "Nginx + Certbot on Ubuntu 24.04: Free HTTPS with Let’s Encrypt"
date: 2025-08-15T10:00:00+07:00
draft: false
url: /2025/08/nginx-certbot-ubuntu-24-04-free-https.html
tags:
  - Linux
  - Nginx
  - SSL
  - Let's Encrypt
description: "Step-by-step guide to install Nginx and secure it with a free Let’s Encrypt SSL certificate on Ubuntu 24.04 using Certbot. Includes DNS setup, firewall, automatic renewal, HTTP→HTTPS redirect, TLS hardening, and troubleshooting."
keywords: ["ubuntu 24.04", "nginx", "certbot", "let's encrypt", "https", "ssl", "tls", "ubuntu nginx ssl"]
---

Want a free, trusted HTTPS certificate for your site on Ubuntu 24.04? This guide walks you through installing Nginx, opening the right firewall ports, issuing a free Let’s Encrypt certificate with Certbot, enabling automatic renewal, forcing HTTP→HTTPS redirects, and applying sane TLS settings. You’ll also see common troubleshooting steps and how to test your configuration. If you need to containerize your apps first, set up Docker here: /2025/08/install-docker-on-ubuntu-24-04-compose-v2-rootless.html

What you’ll do
- Point your domain to your server via DNS (A/AAAA records)
- Install Nginx from Ubuntu repositories
- Allow HTTP/HTTPS through the firewall
- Install Certbot and issue a Let’s Encrypt certificate
- Auto-renew the certificate and verify renewal
- Redirect HTTP to HTTPS and harden TLS settings
- Test, troubleshoot, and (optionally) revoke/uninstall

Prerequisites
- Ubuntu 24.04 LTS (Noble) with sudo access
- A domain name (e.g., example.com) you control
- DNS A/AAAA records pointing to your server’s public IP

1) Configure DNS
Make sure your domain points to your server. At your DNS provider, set:

- A record: example.com → YOUR_IPV4
- AAAA record: example.com → YOUR_IPV6 (optional)
- Optional: wildcard or subdomain records (e.g., www.example.com)

Propagation can take minutes to hours. You can check resolution with:
```bash
dig +short example.com
dig +short www.example.com
```

2) Install Nginx
```bash
sudo apt update
sudo apt install -y nginx
```
Validate Nginx is running:
```bash
systemctl status nginx --no-pager
```
Open your server’s IP in a browser; you should see the default Nginx welcome page.

3) Open the firewall (UFW)
If UFW is enabled, allow Nginx traffic:
```bash
sudo ufw allow 'Nginx Full'   # opens 80/tcp and 443/tcp
sudo ufw status
```
If UFW is disabled, you can skip this step. For cloud providers, also ensure security groups allow ports 80 and 443.

4) Create a basic server block (optional but recommended)
By default, Nginx serves the default site. Create a server block for your domain to keep things organized:
```bash
sudo mkdir -p /var/www/example.com/html
echo '<h1>It works!</h1>' | sudo tee /var/www/example.com/html/index.html > /dev/null

sudo tee /etc/nginx/sites-available/example.com >/dev/null <<'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;
    root /var/www/example.com/html;
    index index.html;
    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX

sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```
Visit http://example.com to confirm it serves your content.

5) Install Certbot (recommended via snap)
The Certbot team recommends snap for the latest version.
```bash
sudo apt install -y snapd
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot || true
```

6) Obtain and install a certificate (Nginx plugin)
Use the Nginx plugin to edit config and reload automatically:
```bash
sudo certbot --nginx -d example.com -d www.example.com
```
Follow the prompts (email, ToS). Choose the redirect option when asked so HTTP automatically redirects to HTTPS.

Alternative: Webroot method (if you prefer manual control)
```bash
sudo certbot certonly --webroot -w /var/www/example.com/html -d example.com -d www.example.com
```
If you used webroot, add SSL directives to your server block and reload Nginx (see step 8 for TLS settings).

7) Auto-renewal
Snap installs a systemd timer for Certbot. Verify it:
```bash
systemctl list-timers | grep certbot
sudo certbot renew --dry-run
```
Dry-run should complete without errors. Certificates renew automatically ~30 days before expiry.

8) Force HTTP→HTTPS and apply TLS best practices
If you didn’t choose the redirect option during Certbot run or you used webroot, update your Nginx config. A sane baseline (based on Mozilla’s “intermediate” profile) is:
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name example.com www.example.com;

    root /var/www/example.com/html;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';
    ssl_prefer_server_ciphers off;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy no-referrer-when-downgrade;

    location / {
        try_files $uri $uri/ =404;
    }
}
```
Then test and reload:
```bash
sudo nginx -t && sudo systemctl reload nginx
```
Use SSL Labs (Qualys) to analyze: https://www.ssllabs.com/ssltest/

Canonical redirect (optional)
If you want to force a single hostname (e.g., redirect www→apex), add a dedicated server block:
```nginx
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name www.example.com;
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    return 301 https://example.com$request_uri;
}
```

OCSP stapling (recommended)
Reduce TLS handshake latency and improve scores with OCSP stapling:
```nginx
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;
resolver 1.1.1.1 1.0.0.1 valid=300s;
resolver_timeout 5s;
```
Place these inside the TLS server block (port 443) after your `ssl_certificate` lines.

Compression (performance)
Enable gzip (widely available) for text assets:
```nginx
gzip on;
gzip_comp_level 5;
gzip_min_length 256;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/svg+xml;
gzip_vary on;
```
Note: Brotli offers better compression but may not be compiled by default in Ubuntu’s Nginx. If you install a Brotli-enabled build, you can use:
```nginx
# brotli on;
# brotli_comp_level 5;
# brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/svg+xml;
```

9) Test your HTTPS setup
- Browser: go to https://example.com and inspect the lock icon
- CLI: `curl -I https://example.com` should return `HTTP/2 200` (or 301 → 200 if redirecting from www)
- Check Nginx logs: `/var/log/nginx/access.log` and `/var/log/nginx/error.log`

Troubleshooting
- DNS/Challenge failed: Ensure your A/AAAA records point to this server and port 80 is reachable from the internet. Temporarily disable any reverse proxy or CDN during issuance.
- Firewall blocks: Open ports 80 and 443 in UFW/security groups. `nc -vz your.ip 80` from an external host can help verify reachability.
- Nginx conflicts: Run `sudo nginx -t` to find syntax errors or duplicated server_name blocks.
- Rate limits: Let’s Encrypt enforces rate limits. Use `--dry-run` for testing or wait before re-issuing.
- Webroot path mismatch: If using `--webroot`, ensure the `-w` path matches your server root and that Nginx serves `/.well-known/acme-challenge/`.
 - Apt update/upgrade errors when installing snap/certbot
   - Lihat: How to fix broken update error in Linux (Terminal) → /2023/11/how-to-fix-broken-update-error-in-linux.html

Multiple sites tip
- Untuk beberapa domain, buat satu file di `sites-available/` per domain. Hindari overlap `server_name` agar Certbot dan Nginx bisa memilih blok yang tepat.

Renewal and maintenance tips
- Certificates renew automatically; review logs in `/var/log/letsencrypt/`.
- After major Nginx changes, run `sudo certbot renew --dry-run` to confirm hooks still work.
- Consider enabling OCSP stapling and caching for further optimization if you terminate high traffic.

Revoke or uninstall (if needed)
Revoke a cert (compromised key or domain transfer):
```bash
sudo certbot revoke --cert-path /etc/letsencrypt/live/example.com/fullchain.pem
```
Remove cert files:
```bash
sudo certbot delete --cert-name example.com
```
Remove Certbot (snap) and Nginx:
```bash
sudo snap remove certbot
sudo apt purge -y nginx* && sudo apt autoremove -y
```

That’s it—your site now serves a trusted HTTPS certificate with automatic renewal on Ubuntu 24.04. Enjoy the speed and security of Nginx + Let’s Encrypt!
