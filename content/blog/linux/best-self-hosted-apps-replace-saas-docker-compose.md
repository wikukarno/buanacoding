---
title: Best Self-Hosted Apps to Replace SaaS You're Paying For (with Docker Compose)
description: >-
  Tired of paying monthly SaaS subscriptions? Here are the best self-hosted open
  source apps you can run on your own server with Docker Compose — from
  analytics and monitoring to password managers and file storage.
date: '2026-02-24T12:00:00+07:00'
tags:
  - Linux
  - Docker
  - Self-Hosting
  - DevOps
  - Open Source
  - Server
  - Privacy
draft: false
author: Wiku Karno
keywords:
  - self-hosted apps
  - self-hosting docker compose
  - best self-hosted applications
  - replace saas with self-hosted
  - open source alternatives saas
  - self-hosted analytics
  - self-hosted password manager
  - uptime kuma
  - vaultwarden
  - plausible analytics
  - nextcloud docker
  - self-hosting guide
  - docker compose self-hosted
  - homelab apps
  - self-hosted monitoring
url: /2026/02/best-self-hosted-apps-replace-saas-docker-compose.html
image: /images/blog/code.webp
faq:
  - question: How much does it cost to self-host apps?
    answer: >-
      A basic VPS with 2GB RAM and 40GB storage costs around $5-10/month and can
      comfortably run 5-8 lightweight apps like Uptime Kuma, Vaultwarden, and
      Plausible. Heavier apps like Nextcloud or Immich need more resources —
      budget $15-30/month for a server with 4-8GB RAM and 100GB+ storage.
      Compare that to paying $50-100/month for the equivalent SaaS
      subscriptions.
  - question: Is self-hosting safe for sensitive data like passwords?
    answer: >-
      Yes, if you follow basic security practices. Use a reverse proxy with
      HTTPS (Nginx + Let's Encrypt), keep your server updated, enable firewall
      rules (UFW), harden SSH access, and regularly back up your data. Tools
      like Vaultwarden use the same encryption as Bitwarden cloud — the
      difference is you control where the data lives.
  - question: Can I self-host on a Raspberry Pi?
    answer: >-
      Absolutely. A Raspberry Pi 4 or 5 with 4GB+ RAM can run many lightweight
      self-hosted apps including Uptime Kuma, Vaultwarden, Pi-hole, Gitea, and
      Memos. Heavier apps like Nextcloud and Immich will work but may feel slow
      under load. For anything serious, a small VPS or mini PC gives you better
      performance and reliability.
  - question: What if a self-hosted app breaks or loses data?
    answer: >-
      This is the real trade-off of self-hosting: you are responsible for
      backups and maintenance. Set up automated backups to an external location
      (S3, another server, or even Google Drive). Use Docker volumes so your
      data survives container rebuilds. And subscribe to release notifications
      for security patches. If all that sounds like too much work, stick with
      SaaS for mission-critical services and self-host the rest.
  - question: Do I need to know Docker to self-host?
    answer: >-
      Technically no — many apps can be installed directly on Linux. But Docker
      Compose makes self-hosting dramatically easier. You define your entire
      stack in a YAML file, run one command, and everything starts up with the
      right configuration. Updates are just pulling the latest image and
      restarting. If you can follow a tutorial and copy-paste commands, you can
      self-host with Docker.
---

Every month I used to look at my credit card statement and see a long list of SaaS subscriptions. $10 here for monitoring, $15 there for analytics, $5 for a password manager, another $12 for file storage. None of them were expensive on their own, but together they added up fast.

At some point I started wondering: could I just run this stuff myself?

Turns out, yes. And it's way easier than it used to be. Docker Compose made self-hosting dead simple — what used to take hours of manual configuration now takes a single YAML file and one command.

Here are the apps I've moved off SaaS and onto my own server. They all run in Docker, they're all open source, and they've collectively saved me a solid chunk of money each month.

## What You Need Before Starting

You don't need a server rack in your closet. A basic VPS works fine for most of this. Here's the minimum:

- **A VPS or home server** — 2GB RAM handles lightweight apps, 4GB+ if you're running several things at once
- **Docker and Docker Compose** — if you haven't set this up yet, here's a guide to [install Docker on Ubuntu 24.04](/2025/08/install-docker-on-ubuntu-24-04-with-compose-v2-and-rootless.html)
- **A domain name** — for HTTPS and clean URLs
- **Basic Linux knowledge** — enough to SSH in and edit files
- **Nginx as a reverse proxy** — route traffic to different apps on the same server. Here's how to [set up Nginx with free SSL](/2025/08/nginx-certbot-ubuntu-24-04-free-https.html)

Once you've got Docker running and Nginx handling HTTPS, adding new apps is just creating a new `docker-compose.yml` and pointing a subdomain at it. The hard part is deciding what to host first.

## 1. Uptime Kuma — Monitoring That Doesn't Cost $20/Month

**Replaces:** UptimeRobot Pro, Pingdom, StatusCake

This was the first thing I self-hosted, and honestly it's what convinced me to keep going. Uptime Kuma is a beautiful, responsive monitoring dashboard. You set up checks for your websites, APIs, databases, whatever — and it pings them at intervals you choose. When something goes down, it notifies you through Telegram, Discord, Slack, email, or about 90 other notification channels.

The dashboard alone is worth it. Clean UI, response time graphs, uptime percentages. It looks better than most paid monitoring tools.

```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: always
    ports:
      - "3001:3001"
    volumes:
      - ./data:/app/data
```

That's it. Run `docker compose up -d` and you have a monitoring system. The whole thing uses about 80MB of RAM.

## 2. Vaultwarden — Your Own Bitwarden Server

**Replaces:** Bitwarden Cloud ($10/year), 1Password ($36/year), LastPass

If there's one thing worth self-hosting for privacy reasons alone, it's your password manager. Vaultwarden is a lightweight, unofficial Bitwarden server implementation written in Rust. It's fully compatible with all official Bitwarden clients — browser extensions, mobile apps, desktop apps — but uses a fraction of the resources.

I switched from Bitwarden Cloud about a year ago. The transition was painless: export from Bitwarden, import into Vaultwarden, done. Everything works exactly the same.

```yaml
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: always
    ports:
      - "8080:80"
    environment:
      - SIGNUPS_ALLOWED=false
      - ADMIN_TOKEN=your-very-long-random-admin-token
    volumes:
      - ./vw-data:/data
```

Important: set `SIGNUPS_ALLOWED=false` after creating your account. And put this behind HTTPS. Seriously. This is your passwords we're talking about. Make sure your [server's SSH is properly hardened](/2025/10/how-to-secure-ssh-server-ubuntu-hardening-guide.html) too.

## 3. Plausible Analytics — Privacy-Friendly Google Analytics Alternative

**Replaces:** Google Analytics, Fathom ($14/month), Simple Analytics ($19/month)

Google Analytics is free, sure. But it's also bloated, confusing, and tracks your visitors across the entire internet. Plausible gives you the numbers you actually care about — page views, referrers, countries, devices — in a clean one-page dashboard. No cookies, no personal data collection, fully GDPR compliant.

The self-hosted version is completely free. The script it injects is under 1KB. Compare that to Google Analytics at 45KB+.

```yaml
services:
  plausible-db:
    image: postgres:16-alpine
    container_name: plausible-db
    restart: always
    environment:
      - POSTGRES_PASSWORD=postgres
    volumes:
      - ./db-data:/var/lib/postgresql/data

  plausible-events-db:
    image: clickhouse/clickhouse-server:24.3-alpine
    container_name: plausible-events-db
    restart: always
    volumes:
      - ./event-data:/var/lib/clickhouse
    ulimits:
      nofile:
        soft: 262144
        hard: 262144

  plausible:
    image: ghcr.io/plausible/community-edition:v2.1
    container_name: plausible
    restart: always
    command: sh -c "sleep 10 && /entrypoint.sh db createdb && /entrypoint.sh db migrate && /entrypoint.sh run"
    ports:
      - "8000:8000"
    depends_on:
      - plausible-db
      - plausible-events-db
    environment:
      - BASE_URL=https://analytics.yourdomain.com
      - SECRET_KEY_BASE=your-random-64-char-secret-here
      - DATABASE_URL=postgres://postgres:postgres@plausible-db:5432/plausible_db
      - CLICKHOUSE_DATABASE_URL=http://plausible-events-db:8123/plausible_events_db
```

Plausible needs more resources than the lightweight apps — ClickHouse for event storage is the hungry one. Budget about 1GB RAM for this setup with moderate traffic.

## 4. Gitea — Self-Hosted Git That Feels Like GitHub

**Replaces:** GitHub (for private repos), GitLab, Bitbucket

For personal projects and private repos, Gitea is perfect. It's a lightweight Git hosting platform with a UI that clearly took inspiration from GitHub. Issues, pull requests, code review, CI/CD with Gitea Actions, organizations, webhooks — it's all there.

Written in Go, it starts up in seconds and barely uses any memory compared to GitLab (which wants 4GB+ just to breathe).

```yaml
services:
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    restart: always
    ports:
      - "3000:3000"
      - "2222:22"
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=sqlite3
    volumes:
      - ./gitea-data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
```

I still use GitHub for public open source stuff. But for private projects, experiments, and anything I don't want on someone else's server, Gitea handles it all.

## 5. Nextcloud — Replace Google Drive and Dropbox

If you're paying for Dropbox ($12/month) or living inside Google Drive and want out, Nextcloud is the obvious pick. It tries to be everything. At its core it's file storage and sync, but it also does calendars, contacts, notes, office documents, video calls, task boards, and probably makes coffee if you install the right plugin.

Fair warning though: this is the most resource-hungry app on this list. Give it dedicated resources and don't expect it to run smoothly on a 1GB VPS alongside five other apps.

```yaml
services:
  nextcloud-db:
    image: mariadb:11
    container_name: nextcloud-db
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=rootpassword
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_PASSWORD=nextcloudpassword
    volumes:
      - ./db-data:/var/lib/mysql

  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    restart: always
    ports:
      - "8081:80"
    depends_on:
      - nextcloud-db
    environment:
      - MYSQL_HOST=nextcloud-db
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_PASSWORD=nextcloudpassword
    volumes:
      - ./nextcloud-data:/var/www/html
```

My honest take: I use Nextcloud mainly for file sync and calendar. The collaborative office stuff works but it's not Google Docs. If you just need file sync, Syncthing (below) is lighter and faster.

## 6. n8n — Automate Everything Without Paying Zapier Prices

**Replaces:** Zapier ($20-50/month), Make (Integromat), IFTTT

This one surprised me. n8n is a workflow automation tool with a visual editor — drag nodes, connect them, build automations. Webhook triggers, database queries, API calls, email sending, file processing, conditional logic. The node library covers hundreds of services.

I use it for stuff like: new GitHub star → Telegram notification, daily database backup → upload to S3, form submission → create row in spreadsheet → send confirmation email. Things that would cost real money on Zapier's higher tiers.

```yaml
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=your-strong-password
      - GENERIC_TIMEZONE=Asia/Jakarta
    volumes:
      - ./n8n-data:/home/node/.n8n
```

The visual workflow builder is solid. I'd argue it's more powerful than Zapier in some ways because you can write custom JavaScript/Python in any node.

## 7. Immich — Google Photos but on Your Server

**Replaces:** Google Photos, iCloud Photos, Amazon Photos

If you've been looking for a self-hosted Google Photos replacement, Immich is the one that finally nailed it. Mobile apps for iOS and Android with automatic photo backup, facial recognition, map view, shared albums, search by content ("photos with dogs"), and a timeline that actually feels smooth.

The project moves fast — new features every couple weeks. A year ago it was rough around the edges. Now it's a serious competitor to Google Photos.

```yaml
services:
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich-server
    restart: always
    ports:
      - "2283:2283"
    environment:
      - DB_HOSTNAME=immich-db
      - DB_USERNAME=postgres
      - DB_PASSWORD=postgres
      - DB_DATABASE_NAME=immich
      - REDIS_HOSTNAME=immich-redis
    volumes:
      - ./upload:/usr/src/app/upload
    depends_on:
      - immich-db
      - immich-redis

  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:release
    container_name: immich-ml
    restart: always
    volumes:
      - ./model-cache:/cache

  immich-redis:
    image: redis:7-alpine
    container_name: immich-redis
    restart: always

  immich-db:
    image: tensorchord/pgvecto-rs:pg16-v0.2.0
    container_name: immich-db
    restart: always
    environment:
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_USER=postgres
      - POSTGRES_DB=immich
    volumes:
      - ./db-data:/var/lib/postgresql/data
```

Heads up: Immich needs decent resources, especially the machine learning container for facial recognition and smart search. 4GB RAM minimum, and plan for storage — photos add up fast.

## 8. Memos — Quick Notes Without the Notion Overhead

Not everything needs to be a Notion database with 47 properties and 12 linked views. Sometimes you just want to jot something down. That's Memos. Think of it as a private Twitter feed for your thoughts — open it, type something, tag it, done. Markdown support, image attachments, and a simple API if you want to integrate it with other stuff.

I use it as a daily scratch pad — random commands I want to remember, meeting notes, links to read later. It does this one thing and does it well.

```yaml
services:
  memos:
    image: neosmemo/memos:stable
    container_name: memos
    restart: always
    ports:
      - "5230:5230"
    volumes:
      - ./memos-data:/var/opt/memos
```

Under 50MB of RAM. Starts in a second. No database to configure. This is what self-hosting should feel like.

## 9. Portainer — Manage All Your Containers Visually

This one doesn't replace a SaaS product. It just makes your life easier once you're running 5+ containers and managing them purely through the terminal gets old.

Portainer gives you a web UI for your Docker environment. Start/stop containers, view logs, manage volumes, check resource usage, deploy new stacks from the browser. Basic stuff, but having it in a dashboard saves time.

```yaml
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./portainer-data:/data
```

Not a replacement for the command line — I still SSH in for most things. But for quick checks and showing non-technical people what's running, it's nice to have.

## 10. Syncthing — File Sync Without the Cloud

**Replaces:** Dropbox (sync only), Google Drive (sync only), Resilio Sync

Unlike Nextcloud, Syncthing does exactly one thing: keep folders synchronized between devices. No web interface for browsing files, no app marketplace, no video calling. Just fast, encrypted, peer-to-peer file sync.

Your data never touches anyone else's server. Device A talks directly to Device B through encrypted channels. No account needed, no cloud relay (unless both devices are behind strict NATs).

```yaml
services:
  syncthing:
    image: syncthing/syncthing:latest
    container_name: syncthing
    restart: always
    ports:
      - "8384:8384"
      - "22000:22000/tcp"
      - "22000:22000/udp"
      - "21027:21027/udp"
    environment:
      - PUID=1000
      - PGID=1000
    volumes:
      - ./syncthing-data:/var/syncthing
```

I run Syncthing between my laptop, phone, and VPS. Documents, configs, dotfiles — all synced within seconds of saving. Zero monthly cost, zero third-party access.

## Putting It All Together

Running all of these? Probably overkill unless you have a beefy server. But pick the 3-4 that match what you're actually paying for right now:

| App | RAM Usage | Replaces | Monthly Savings |
|-----|-----------|----------|-----------------|
| Uptime Kuma | ~80MB | UptimeRobot Pro ($7) | $7 |
| Vaultwarden | ~50MB | Bitwarden Premium ($1) | $1 |
| Plausible | ~800MB | Plausible Cloud ($9) | $9 |
| Gitea | ~150MB | GitHub Team ($4/user) | $4+ |
| Nextcloud | ~500MB | Dropbox Plus ($12) | $12 |
| n8n | ~300MB | Zapier Starter ($20) | $20 |
| Immich | ~2GB | Google One ($3) | $3 |
| Memos | ~50MB | Notion Plus ($10) | $10 |
| Portainer | ~100MB | — | $0 |
| Syncthing | ~100MB | Dropbox Basic ($10) | $10 |

A 4GB VPS at $15-20/month running Uptime Kuma, Vaultwarden, Gitea, Memos, and Syncthing replaces about $30-40 in SaaS fees. Add a bigger server for Plausible and Nextcloud and the savings grow from there.

## Security Is Your Responsibility Now

This is the part that turns people off from self-hosting, and honestly, they're not wrong to be cautious. When you self-host, *you* are the sysadmin. Patches, backups, firewall rules — that's all on you.

A few things you can't skip:

- **HTTPS everywhere** — Use Nginx as a reverse proxy with Let's Encrypt certificates
- **Firewall** — Only open ports you actually need. Here's a guide on [configuring UFW and Firewalld](/2025/10/how-to-manage-firewall-linux-ufw-firewalld.html)
- **SSH hardening** — Key-only auth, non-standard port, fail2ban. No exceptions
- **Automated backups** — Back up Docker volumes to an external location. Test your restores
- **Updates** — Pull new images regularly. Subscribe to security advisories for apps you run

If any of that sounds like too much, start with one or two apps that aren't holding sensitive data. Uptime Kuma and Memos are great first picks — low risk, high reward, and they teach you the workflow.

## My Honest Take After a Year of Self-Hosting

Not everything is worth self-hosting. I tried running my own email server once and lasted about three weeks before crawling back to a paid provider. Some things (email, DNS) are just better left to people who do it full-time.

But for the apps I listed above? Totally worth it. My VPS costs me about $20/month and replaces well over $60 in SaaS fees. Beyond the money, there's something satisfying about knowing exactly where your data lives and having full control over your tools.

Start small. Pick one app from this list that replaces something you're currently paying for. Get it running, use it for a month, see how it feels. If you like it, add another one. Before you know it, you'll have a little stack of services that are entirely yours.

And when you inevitably break something at 2am and have to fix it yourself — well, that's part of the charm.
