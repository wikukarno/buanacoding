---
title: "Install Docker on Ubuntu 24.04 Post-Install, Rootless, and Compose v2"
date: 2025-08-14T10:00:00+07:00
draft: false
url: /2025/08/install-docker-on-ubuntu-24-04-with-compose-v2-and-rootless.html
tags:
  - Linux
  - Docker
description: "Step-by-step guide to install Docker Engine on Ubuntu 24.04 (Noble), set up post-install permissions, enable rootless mode, and use Docker Compose v2. Includes testing, troubleshooting, and uninstall instructions."
keywords: ["ubuntu 24.04", "install docker", "docker compose v2", "rootless docker", "docker ubuntu", "docker installation", "noble"]

faq:
  - question: "How do I run Docker without sudo on Ubuntu 24.04?"
    answer: "After installing Docker, run `sudo usermod -aG docker $USER` to add your user to the docker group. Then run `newgrp docker` or log out and back in. Test with `docker run --rm hello-world` (without sudo)."

  - question: "What's the difference between Docker Compose v1 and v2?"
    answer: "Docker Compose v2 is a plugin integrated into the Docker CLI, using `docker compose` (space) instead of `docker-compose` (hyphen). It's faster, written in Go, and better integrated. v1 is deprecated and should be replaced."

  - question: "Should I use rootless Docker or regular Docker?"
    answer: "Use regular Docker for most cases - it has full features and better performance. Use rootless Docker only if you need extra security isolation, but note that some features (privileged containers, ports <1024) won't work in rootless mode."

  - question: "How do I fix 'permission denied' error when running Docker?"
    answer: "Run `groups` to check if you're in the docker group. If not, run `sudo usermod -aG docker $USER`, then either log out/in or run `newgrp docker`. If the issue persists, check `systemctl status docker` to ensure the daemon is running."

  - question: "How do I clean up Docker disk space on Ubuntu?"
    answer: "Use `docker system df` to check usage. Clean with `docker image prune -f` (unused images), `docker container prune -f` (stopped containers), `docker volume prune -f` (unused volumes), and `docker builder prune -f` (build cache). Remove `-f` for confirmation prompts."

  - question: "Can I install Docker on Ubuntu 24.04 without adding the repository?"
    answer: "No, Ubuntu's default Docker package is outdated. You must add Docker's official repository to get Docker Engine with Compose v2, Buildx, and the latest features. The guide shows the safe way to add the official repository."
---

This guide shows how to install Docker Engine on Ubuntu 24.04 LTS (Noble Numbat), configure it for non-root use, enable optional rootless mode, and use Docker Compose v2. It also includes test commands, common troubleshooting tips, and how to uninstall cleanly. For securing your site with HTTPS, see: [Nginx + Certbot on Ubuntu 24.04]({{< relref "blog/linux/nginx-certbot-ubuntu-24-04-free-https-with-letsencrypt.md" >}})

What you’ll do
- Add the official Docker repository for Ubuntu 24.04 (Noble)
- Install Docker Engine, Buildx, and Compose v2 plugins
- Run Docker as your regular user (without sudo)
- Optionally enable rootless Docker
- Verify with test containers and fix common errors

Prerequisites
- Fresh or updated Ubuntu 24.04 LTS (Noble)
- A user with sudo privileges

1) Remove old Docker packages (if any)
```bash
sudo apt remove -y docker docker-engine docker.io containerd runc || true
```

2) Set up the Docker repository
```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release; echo $VERSION_CODENAME) stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
```

3) Install Docker Engine, Buildx, and Compose v2
```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

4) Test Docker (root)
```bash
sudo docker run --rm hello-world
```
You should see a confirmation message.

5) Post-install: run Docker without sudo
```bash
sudo usermod -aG docker $USER
newgrp docker  # reload group membership for current shell
docker run --rm hello-world
```
If the second command works without sudo, your user is set up correctly.

6) Docker Compose v2
`docker compose` is included as a plugin. Check the version:
```bash
docker compose version
```
Example usage:
```bash
cat > compose.yaml <<'YAML'
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
YAML

docker compose up -d
docker compose ps
docker compose down
```

6a) Verify Buildx
`docker buildx` is the modern builder with multi-platform support and advanced caching.
```bash
docker buildx version
```
You should see a version string. Optionally, try a quick build to confirm the builder is healthy:
```bash
docker buildx bake --print 2>/dev/null || echo "Buildx is installed and ready."
```

7) Optional: Rootless Docker
Rootless mode runs the Docker daemon and containers without root privileges. Good for tighter isolation (with some feature limitations).

Install requirements and set up:
```bash
sudo apt install -y uidmap dbus-user-session
dockerd-rootless-setuptool.sh install
```

Start and enable the user service:
```bash
systemctl --user start docker
systemctl --user enable docker
# Keep user services running after logout
sudo loginctl enable-linger $USER
```

Use the rootless daemon by pointing the client to your user socket (usually done automatically by the setup tool):
```bash
export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock
docker info | grep -i rootless
```

Notes on rootless mode
- Some features (e.g., privileged containers, low ports <1024) are restricted.
- For Kubernetes-in-Docker or system-wide networking, classic (rootful) Docker is recommended.

8) Troubleshooting
- Permission denied on /var/run/docker.sock
  - Run: `groups` and ensure `docker` is listed. If not, run `sudo usermod -aG docker $USER` then re-login or `newgrp docker`.
- Network issues pulling images
  - Check DNS and proxy settings. Try `docker pull alpine` and `ping registry-1.docker.io` (may be blocked by firewall).
- Cannot connect to the Docker daemon
  - Check service: `systemctl status docker` (rootful) or `systemctl --user status docker` (rootless).
- Compose command not found
  - Ensure you installed `docker-compose-plugin` and run `docker compose` (space), not `docker-compose`.
- Apt update/upgrade errors during install
  - Lihat: How to fix broken update error in Linux (Terminal) → /2023/11/how-to-fix-broken-update-error-in-linux.html

8a) Maintenance & Cleanup (disk usage)
Over time, images/layers can consume disk space. Inspect usage and prune carefully:
```bash
docker system df
docker image prune -f                # remove unused images (dangling)
docker container prune -f            # remove stopped containers
docker volume prune -f               # remove unused volumes
docker builder prune -f              # remove unused build cache
```
Tip: omit `-f` to get a prompt before deleting. Review before pruning on production hosts.

9) Uninstall Docker completely
```bash
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
sudo rm -rf /var/lib/docker /var/lib/containerd
sudo rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg
sudo apt autoremove -y
```

Security note
- Members of the `docker` group can effectively escalate privileges on the host (they can start containers with access to the filesystem). Only add trusted users to the `docker` group.

That’s it! You now have Docker Engine, Compose v2, and (optionally) rootless mode on Ubuntu 24.04.
