---
title: "Uninstall Docker on Ubuntu 24.04 Complete Clean Removal"
date: 2025-08-23T13:30:00+07:00
draft: false
url: /2025/08/uninstall-docker-ubuntu-24-04-clean-removal.html
tags:
  - Linux
  - Docker
  - Ubuntu
  - Troubleshooting
description: "Completely uninstall Docker on Ubuntu 24.04 (Noble): stop services, purge packages, remove images/containers/volumes/networks, clean configs, rootless uninstall, and verify removal."
keywords: ["uninstall docker ubuntu 24.04", "remove docker completely", "docker compose v2 ubuntu", "purge docker", "uninstall containerd", "rootless docker uninstall"]
faq:
  - question: "Will uninstalling Docker delete all my containers and images?"
    answer: "Yes, following the complete uninstall process removes all containers, images, volumes, and networks. The guide includes an optional step to explicitly remove this data before purging packages. If you want to preserve data, skip step 1 and backup /var/lib/docker before proceeding with the removal."
  - question: "What's the difference between apt remove and apt purge for Docker?"
    answer: "The command apt remove uninstalls Docker packages but keeps configuration files in /etc/docker and /etc/containerd. Meanwhile, apt purge removes both packages and configuration files, providing a cleaner removal. This guide uses purge along with manual directory removal to ensure complete cleanup."
  - question: "Do I need to uninstall rootless Docker separately?"
    answer: "Yes, rootless Docker runs as a user service under systemd --user and stores data in your home directory (~/.local/share/docker). If you enabled rootless Docker, follow step 5 to stop the user service, run dockerd-rootless-setuptool.sh uninstall, and remove user-specific data and configs."
  - question: "How can I verify Docker is completely removed?"
    answer: "Run these verification commands: check if Docker CLI exists with 'command -v docker', search for remaining packages with 'dpkg -l | grep docker', verify services are stopped with 'systemctl status docker' and 'systemctl status containerd'. All commands should show Docker is not found or services are inactive."
  - question: "Can I reinstall Docker after complete removal?"
    answer: "Yes, complete removal actually creates a clean slate for reinstallation. After uninstalling, you can follow the fresh installation guide for Ubuntu 24.04 to reinstall Docker Engine, Compose v2 plugin, and optionally enable rootless mode again. The removal process doesn't prevent future installations."
  - question: "What should I do if I get permission denied errors during uninstall?"
    answer: "Permission denied errors during uninstall typically mean you need sudo privileges. Ensure all docker and systemctl commands use sudo. If removing user data (~/.docker, ~/.local/share/docker) fails, check file ownership with 'ls -la' and use sudo only for system directories, not your home directory files."
---

Need to remove Docker from Ubuntu 24.04 (Noble) cleanly? This guide shows a safe, step‑by‑step removal that gets rid of the Engine, Compose v2 plugin, configs, and data -- plus optional rootless Docker cleanup. If you plan to reinstall after this, see: [Install Docker on Ubuntu 24.04: Post‑Install, Rootless, and Compose v2]({{< relref "blog/linux/install-docker-on-ubuntu-24-04-with-compose-v2-and-rootless.md" >}}). For HTTPS and reverse proxy, see: [Nginx + Certbot on Ubuntu 24.04: Free HTTPS with Let’s Encrypt]({{< relref "blog/linux/nginx-certbot-ubuntu-24-04-free-https-with-letsencrypt.md" >}}).

Warning: The steps below can remove containers, images, volumes, and networks. Back up anything important before continuing.

What you’ll do
- Stop and disable Docker services (Engine and containerd)
- Optionally remove all containers, images, volumes, and networks
- Purge Docker packages and the Compose v2 plugin
- Delete configuration and data directories (Engine and containerd)
- Optionally uninstall rootless Docker
- Verify that Docker is completely gone

Prerequisites
- Ubuntu 24.04 LTS (Noble) with sudo access
- Terminal access to the machine (SSH or local)

1) (Optional) Remove containers, images, volumes, networks
If you want a fully clean state, remove runtime data first. If you prefer to keep data, skip this step.
```bash
# Remove all containers (running and stopped)
sudo docker ps -aq | xargs -r sudo docker rm -f

# Remove all images
sudo docker image prune -a -f

# Remove all volumes
sudo docker volume prune -f

# Remove unused networks
sudo docker network prune -f
```

2) Stop Docker services
```bash
sudo systemctl disable --now docker docker.socket containerd || true
```

3) Purge Docker packages
Remove Engine, CLI, Buildx, and Compose v2 plugin (installed as apt plugins on Ubuntu 24.04 per official repo). Also cover legacy packages.
```bash
sudo apt update
sudo apt purge -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin \
  docker-ce-rootless-extras || true

# In case older/alternative packages were installed
sudo apt purge -y docker.io docker-doc podman-docker containerd runc || true

sudo apt autoremove -y
sudo apt clean
```

4) Remove configuration, data, and repo files
```bash
# Engine & containerd data/config
sudo rm -rf /var/lib/docker /var/lib/containerd
sudo rm -rf /etc/docker /etc/containerd 2>/dev/null || true
sudo rm -rf /etc/systemd/system/docker.service.d 2>/dev/null || true

# Socket leftovers
sudo rm -f /var/run/docker.sock

# Apt repository and key (official Docker repo)
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.gpg
sudo apt update

# Per-user Docker config (CLI)
rm -rf ~/.docker
```

5) (Optional) Uninstall rootless Docker (if you enabled it)
Rootless Docker runs as a user service under systemd. If you used it, clean it up as well.
```bash
# Stop/disable user service if present
systemctl --user stop docker 2>/dev/null || true
systemctl --user disable docker 2>/dev/null || true
systemctl --user daemon-reload || true

# If you installed via the helper tool, uninstall it
command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1 && \
  dockerd-rootless-setuptool.sh uninstall || true

# Remove user data/config
rm -rf ~/.local/share/docker ~/.config/docker
rm -f ~/.config/systemd/user/docker.service

# Optional: disable lingering if you previously enabled it for rootless
sudo loginctl disable-linger "$USER" 2>/dev/null || true
```

6) Verify removal
```bash
# Docker CLI should be missing
if command -v docker; then echo "Docker still present"; else echo "Docker CLI not found ✔"; fi

# No Docker or containerd packages
dpkg -l | grep -E "^(ii|rc)\s+(docker|containerd)" || echo "No docker/containerd packages found ✔"

# Services should be inactive
systemctl status docker 2>/dev/null | grep -q running && echo "docker running" || echo "docker not running ✔"
systemctl status containerd 2>/dev/null | grep -q running && echo "containerd running" || echo "containerd not running ✔"
```

Common troubleshooting
- Stuck socket at `/var/run/docker.sock`: remove it with `sudo rm -f /var/run/docker.sock` and re‑check.
- Packages reappear after purge: run `sudo apt purge ...` again, then `sudo apt autoremove -y && sudo apt clean`.
- Rootless processes still around: `ps -u "$USER" | grep -E 'dockerd|containerd'` then kill the PIDs, re‑run step 5.
- WSL2 on Windows: make sure you uninstall Docker Desktop WSL integration separately; this guide targets native Ubuntu 24.04.

Reinstall later?
When you’re ready to install again, follow the fresh 24.04 guide (official repo, Compose v2 plugin, optional rootless): [Install Docker on Ubuntu 24.04: Post‑Install, Rootless, and Compose v2]({{< relref "blog/linux/install-docker-on-ubuntu-24-04-with-compose-v2-and-rootless.md" >}}).
