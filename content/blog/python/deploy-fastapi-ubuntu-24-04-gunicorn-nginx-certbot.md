---
title: "Deploy FastAPI on Ubuntu 24.04: Gunicorn + Nginx + Certbot (HTTPS)"
date: 2025-08-15T18:00:00+07:00
draft: false
url: /2025/08/deploy-fastapi-ubuntu-24-04-gunicorn-nginx-certbot.html
tags:
  - Python
  - FastAPI
  - Ubuntu
  - Nginx
  - Deploy
  - HTTPS
description: "A complete guide to deploying FastAPI on Ubuntu 24.04 using Gunicorn as the ASGI server and Nginx as a reverse proxy, plus free HTTPS via Certbot/Let’s Encrypt. Includes a systemd service, UFW firewall, and troubleshooting."
keywords: ["fastapi", "deploy fastapi", "ubuntu 24.04", "gunicorn", "uvicorn", "nginx", "certbot", "let's encrypt", "systemd", "ufw"]
---

Want to deploy FastAPI on Ubuntu 24.04 with a clean, secure, and maintainable setup? This guide walks you through running Gunicorn (ASGI server), Nginx (reverse proxy), and free HTTPS from Let’s Encrypt using Certbot. We’ll also use systemd so your service starts on boot and is easy to restart after updates.

<!--readmore-->

What you’ll build:
- A minimal FastAPI project structure
- Running the app with Gunicorn (Uvicorn worker)
- A systemd service for start/stop/restart
- Nginx reverse proxy to Gunicorn
- HTTPS (Certbot) with auto‑renewal
- UFW firewall (open 80/443), logs, and troubleshooting tips



Prerequisites
-------------
- Ubuntu 24.04 server (sudo access)
- A domain pointing to the server (A/AAAA records)
- Python 3.10+ (Ubuntu 24.04 default is fine)

1) Prepare the project structure on the server
----------------------------------------------
A tidy layout makes automation easier.

```bash
sudo mkdir -p /opt/fastapi/app
sudo adduser --system --group --home /opt/fastapi fastapi
sudo chown -R fastapi:fastapi /opt/fastapi
```

2) Create a virtualenv and install dependencies
-----------------------------------------------
```bash
sudo apt update
sudo apt install -y python3-venv

sudo -u fastapi python3 -m venv /opt/fastapi/venv
sudo -u fastapi /opt/fastapi/venv/bin/pip install --upgrade pip
sudo -u fastapi /opt/fastapi/venv/bin/pip install fastapi uvicorn gunicorn
```

Create a requirements.txt for easier dependency management:
```bash
sudo -u fastapi tee /opt/fastapi/requirements.txt >/dev/null <<'REQS'
fastapi==0.104.1
uvicorn[standard]==0.24.0
gunicorn==21.2.0
pydantic==2.5.0
REQS

sudo -u fastapi /opt/fastapi/venv/bin/pip install -r /opt/fastapi/requirements.txt
```

3) Create a minimal FastAPI app
--------------------------------
```bash
sudo -u fastapi tee /opt/fastapi/app/main.py >/dev/null <<'PY'
from fastapi import FastAPI

app = FastAPI()

@app.get("/healthz")
def healthz():
    return {"status": "ok"}

@app.get("/")
def root():
    return {"message": "Hello from FastAPI on Ubuntu 24.04!"}
PY
```

Optional: quick local test
```bash
# IMPORTANT: Change to app directory first to avoid permission errors
cd /opt/fastapi
sudo -u fastapi /opt/fastapi/venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
Visit `http://SERVER_IP:8000` to verify it works.

**Common Error Fix:**
If you get `PermissionError: Permission denied (os error 13) about ["/root"]`, it means uvicorn is trying to watch the wrong directory. Always `cd /opt/fastapi` first before running the command.

4) Run with Gunicorn (ASGI) manually for testing
------------------------------------------------
```bash
sudo -u fastapi /opt/fastapi/venv/bin/gunicorn \
  -k uvicorn.workers.UvicornWorker \
  -w 2 \
  -b 0.0.0.0:8000 \
  app.main:app
```
If logs look healthy and port 8000 serves requests (try `curl http://SERVER_IP:8000/healthz` or `curl 127.0.0.1:8000/healthz`), proceed to the service setup.

5) Choose your process manager (pick one)
===========================================

You need to choose how to run your FastAPI app as a service. Pick **either** Option A (systemd) **or** Option B (PM2):

Option A: Create a systemd service for Gunicorn (Recommended)
------------------------------------------------------------
```bash
sudo tee /etc/systemd/system/fastapi.service >/dev/null <<'SERVICE'
[Unit]
Description=FastAPI app with Gunicorn
After=network.target

[Service]
User=fastapi
Group=fastapi
WorkingDirectory=/opt/fastapi
Environment="PATH=/opt/fastapi/venv/bin"
ExecStart=/opt/fastapi/venv/bin/gunicorn -k uvicorn.workers.UvicornWorker -w 2 -b 0.0.0.0:8000 app.main:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable --now fastapi
sudo systemctl status fastapi --no-pager
```

Option B: Using PM2 (Alternative Process Manager)
--------------------------------------------------
PM2 is great for Node.js but also works excellently with Python apps. It provides easy clustering, monitoring, and log management.

**Install PM2:**
```bash
# Install Node.js and PM2
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g pm2
```

**Create PM2 ecosystem config:**
```bash
sudo -u fastapi tee /opt/fastapi/ecosystem.config.js >/dev/null <<'JS'
module.exports = {
  apps: [{
    name: 'fastapi-app',
    script: '/opt/fastapi/venv/bin/gunicorn',
    args: '-k uvicorn.workers.UvicornWorker -w 2 -b 127.0.0.1:8000 app.main:app',
    cwd: '/opt/fastapi',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production'
    },
    error_file: '/opt/fastapi/logs/err.log',
    out_file: '/opt/fastapi/logs/out.log',
    log_file: '/opt/fastapi/logs/combined.log',
    time: true
  }]
}
JS

# Create logs directory
sudo -u fastapi mkdir -p /opt/fastapi/logs
```

**Start with PM2:**
```bash
# Start the application
sudo -u fastapi pm2 start /opt/fastapi/ecosystem.config.js

# Save PM2 process list
sudo -u fastapi pm2 save

# Setup PM2 to start on boot
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u fastapi --hp /opt/fastapi

# Check status
sudo -u fastapi pm2 status
sudo -u fastapi pm2 logs fastapi-app
```

**PM2 Management Commands:**
```bash
# Restart app
sudo -u fastapi pm2 restart fastapi-app

# Stop app
sudo -u fastapi pm2 stop fastapi-app

# Monitor in real-time
sudo -u fastapi pm2 monit

# View logs
sudo -u fastapi pm2 logs fastapi-app --lines 50
```

**Systemd vs PM2 Comparison:**

| Feature | Systemd | PM2 |
|---------|---------|-----|
| Built-in Ubuntu | Yes | Requires Node.js |
| Memory usage | Lower | Higher (Node.js overhead) |
| Monitoring UI | Command line only | pm2 monit dashboard |
| Log management | journalctl | Built-in log rotation |
| Clustering | Manual setup | Easy clustering |
| Learning curve | Moderate | Easier |
| Production ready | Enterprise grade | Battle tested |

**Choose systemd if:** You want minimal overhead and native Ubuntu integration.
**Choose PM2 if:** You want easier monitoring, log management, and plan to scale horizontally.

**IMPORTANT:** You must complete either Option A or Option B above before proceeding to Nginx setup!

6) Install and configure Nginx (reverse proxy)
----------------------------------------------
```bash
sudo apt install -y nginx

sudo tee /etc/nginx/sites-available/example.com >/dev/null <<'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
    }
}
NGINX

sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

7) Open the firewall (UFW) for HTTP/HTTPS
-----------------------------------------
```bash
sudo ufw allow 'Nginx Full'   # opens 80/tcp and 443/tcp
sudo ufw allow 8000           # allow direct access to FastAPI for testing
sudo ufw status
```

8) Issue free HTTPS with Certbot
--------------------------------
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d example.com -d www.example.com
```
Certbot will configure the 443 server block and set up auto‑renewal. You can test renewal with:
```bash
sudo certbot renew --dry-run
```

9) Checks and monitoring
------------------------
- Try: `curl -I https://example.com/healthz`
- App logs: `journalctl -u fastapi -f`
- Nginx logs: `/var/log/nginx/access.log` and `error.log`

10) Production optimizations
-----------------------------
Add some production-ready configurations:

**Gunicorn production config:**
```bash
sudo -u fastapi tee /opt/fastapi/gunicorn.conf.py >/dev/null <<'GUNICORN'
# Gunicorn configuration file
bind = "0.0.0.0:8000"
worker_class = "uvicorn.workers.UvicornWorker"
workers = 2
worker_connections = 1000
max_requests = 1000
max_requests_jitter = 100
preload_app = True
keepalive = 2
timeout = 30
graceful_timeout = 30
GUNICORN

# Update systemd service to use config file
sudo sed -i 's|ExecStart=.*|ExecStart=/opt/fastapi/venv/bin/gunicorn -c /opt/fastapi/gunicorn.conf.py app.main:app|' /etc/systemd/system/fastapi.service
sudo systemctl daemon-reload
sudo systemctl restart fastapi
```

**Enhanced Nginx config with security headers:**
```bash
sudo tee /etc/nginx/sites-available/example.com >/dev/null <<'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name example.com www.example.com;

    # SSL configuration (handled by Certbot)
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }

    # Health check endpoint (no logging)
    location /healthz {
        proxy_pass http://127.0.0.1:8000;
        access_log off;
    }
}
NGINX

sudo nginx -t && sudo systemctl reload nginx
```

11) Update and deployment strategies
-----------------------------------

**For systemd deployments:**
```bash
# Create deployment script
sudo tee /opt/fastapi/deploy.sh >/dev/null <<'DEPLOY'
#!/bin/bash
set -e

echo "Starting deployment..."

# Pull latest code (if using git)
cd /opt/fastapi
sudo -u fastapi git pull origin main

# Update dependencies
sudo -u fastapi /opt/fastapi/venv/bin/pip install -r requirements.txt

# Run any migrations or setup scripts here
# sudo -u fastapi /opt/fastapi/venv/bin/python manage.py migrate

# Test the app syntax
sudo -u fastapi /opt/fastapi/venv/bin/python -c "import app.main"

# Restart the service
sudo systemctl restart fastapi

# Wait a moment and check if it's running
sleep 5
sudo systemctl is-active --quiet fastapi && echo "Deployment successful!" || echo "Deployment failed!"

echo "Checking app health..."
curl -f http://127.0.0.1:8000/healthz || echo "Health check failed"
DEPLOY

sudo chmod +x /opt/fastapi/deploy.sh
```

**For PM2 deployments:**
```bash
# PM2 deployment
sudo -u fastapi pm2 stop fastapi-app
cd /opt/fastapi
sudo -u fastapi git pull origin main
sudo -u fastapi /opt/fastapi/venv/bin/pip install -r requirements.txt
sudo -u fastapi pm2 restart fastapi-app
sudo -u fastapi pm2 save
```

**Zero-downtime deployment with PM2:**
```bash
# Update ecosystem.config.js for zero-downtime
sudo -u fastapi tee /opt/fastapi/ecosystem.config.js >/dev/null <<'JS'
module.exports = {
  apps: [{
    name: 'fastapi-app',
    script: '/opt/fastapi/venv/bin/gunicorn',
    args: '-c /opt/fastapi/gunicorn.conf.py app.main:app',
    cwd: '/opt/fastapi',
    instances: 2,  // Multiple instances for zero-downtime
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    kill_timeout: 5000,
    wait_ready: true,
    listen_timeout: 10000,
    env: {
      NODE_ENV: 'production'
    }
  }]
}
JS

# Reload with zero downtime
sudo -u fastapi pm2 reload fastapi-app
```

12) Monitoring and logging
---------------------------

**Basic monitoring with systemd:**
```bash
# Check service status
sudo systemctl status fastapi

# View logs in real-time
sudo journalctl -u fastapi -f

# Check resource usage
sudo systemctl show fastapi --property=MainPID
ps aux | grep $(sudo systemctl show fastapi --property=MainPID --value)
```

**Basic monitoring with PM2:**
```bash
# Real-time monitoring dashboard
sudo -u fastapi pm2 monit

# Check memory and CPU usage
sudo -u fastapi pm2 list

# View detailed process info
sudo -u fastapi pm2 describe fastapi-app
```

**Log rotation setup:**
```bash
# For systemd logs
sudo tee /etc/logrotate.d/fastapi >/dev/null <<'LOGROTATE'
/var/log/nginx/access.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        sudo systemctl reload nginx > /dev/null 2>&1
    endscript
}
LOGROTATE
```

Tips & troubleshooting
----------------------

**Common issues and solutions:**

**Permission denied error when testing uvicorn:**
```bash
# Wrong: This will cause permission error if run from /root
sudo -u fastapi /opt/fastapi/venv/bin/uvicorn app.main:app --reload

# Correct: Always change directory first
cd /opt/fastapi
sudo -u fastapi /opt/fastapi/venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Or run without reload flag for testing
sudo -u fastapi /opt/fastapi/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```
**Root cause:** Uvicorn with `--reload` tries to watch the current working directory. If you run from `/root`, the `fastapi` user cannot access it.

**502 Bad Gateway:**
```bash
# Check if FastAPI service is running
sudo systemctl status fastapi
# or for PM2
sudo -u fastapi pm2 status

# Check application logs
sudo journalctl -u fastapi -f --since "10 minutes ago"
# or for PM2
sudo -u fastapi pm2 logs fastapi-app --lines 50

# Test direct connection to Gunicorn
curl -I http://127.0.0.1:8000/healthz
# Or test from outside
curl -I http://SERVER_IP:8000/healthz
```

**High memory usage:**
```bash
# Check memory consumption
sudo systemctl show fastapi --property=MemoryCurrent
# Restart if memory is too high
sudo systemctl restart fastapi

# For PM2 - automatic restart on high memory
# Already configured with max_memory_restart: '1G'
```

**Performance tuning:**
```bash
# Adjust workers based on CPU cores
# Rule of thumb: (2 x CPU cores) + 1
nproc  # Check CPU cores

# Update gunicorn workers in config
sudo sed -i 's/workers = 2/workers = 3/' /opt/fastapi/gunicorn.conf.py
sudo systemctl restart fastapi
```

**SSL certificate issues:**
```bash
# Test certificate renewal
sudo certbot renew --dry-run

# Check certificate expiry
sudo certbot certificates

# Manual renewal if needed
sudo certbot renew --force-renewal -d example.com
```

**Security hardening checklist:**
- Non-root user (fastapi)
- Firewall (UFW) configured
- SSL/TLS encryption
- Security headers in Nginx
- No direct access to Gunicorn port
- Consider: fail2ban, regular security updates
- Consider: database connection encryption
- Consider: rate limiting in Nginx

Recommended next steps
----------------------
- **Monitoring**: Set up Prometheus + Grafana for advanced metrics
- **Backup**: Database backups, SSL certificate backups  
- **CI/CD**: GitHub Actions for automated testing and deployment
- **Load balancing**: Multiple app servers behind Nginx for high availability
- **Caching**: Redis for session storage and caching
- **Database**: PostgreSQL with connection pooling (SQLAlchemy + asyncpg)

Related articles:
- [Nginx + Certbot on Ubuntu 24.04](/2025/08/nginx-certbot-ubuntu-24-04-free-https.html) - SSL setup guide
- [Install Docker on Ubuntu 24.04](/2025/08/install-docker-on-ubuntu-24-04-compose-v2-rootless.html) - Containerized deployment option

That's it! You now have a production-ready FastAPI deployment on Ubuntu 24.04 with multiple process management options (systemd vs PM2), HTTPS encryption, and comprehensive monitoring. Choose the approach that best fits your infrastructure and scaling needs. Happy coding!
