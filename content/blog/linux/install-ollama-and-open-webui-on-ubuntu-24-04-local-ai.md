---
title: "Install Ollama and Open WebUI on Ubuntu 24.04: Local AI (CPU/GPU)"
date: 2025-08-19T10:00:00+07:00
draft: false
url: /2025/08/install-ollama-openwebui-ubuntu-24-04.html
tags:
  - Linux
  - AI
  - Ollama
  - Open WebUI
description: "Step-by-step guide to install Ollama and Open WebUI on Ubuntu 24.04 (Noble) for running LLMs locally, with notes for CPU and NVIDIA GPU acceleration, services, and troubleshooting."
keywords: ["ubuntu 24.04", "ollama", "open webui", "local llm", "cuda", "nvidia", "ai on ubuntu"]
---

If you want to run AI models locally on Ubuntu 24.04 with a clean web UI, this guide is for you. We’ll install [Ollama](https://ollama.com), pull a model, and use [Open WebUI](https://github.com/open-webui/open-webui) for a modern chat interface. The steps cover CPU‑only and NVIDIA GPU notes, optional systemd services, and practical troubleshooting.

What you'll do
- Install Ollama on Ubuntu 24.04 (Noble)
- Pull and run a starter model (e.g., `llama3.1`)
- Run Open WebUI (Docker) and connect to Ollama
- Optionally enable NVIDIA GPU acceleration (CUDA)
- Set up systemd services and basic hardening tips

Prerequisites
- Ubuntu 24.04 LTS (Noble), sudo user
- 4GB RAM minimum (8GB+ recommended)
- Optional: NVIDIA GPU with recent drivers for acceleration

Step 1: Install Ollama
```bash
curl -fsSL https://ollama.com/install.sh | sh
```
Start (or restart) the service:
```bash
sudo systemctl enable --now ollama
sudo systemctl status ollama --no-pager
```

Step 2: Pull a model and test
Examples:
```bash
ollama pull llama3.1
ollama run llama3.1
```
In the REPL, type a prompt and press Enter. Exit with `Ctrl+C`.

Step 3 (optional): NVIDIA GPU acceleration
If you have an NVIDIA GPU, ensure drivers and CUDA libraries are present. A common path is to install the official NVIDIA driver from Ubuntu’s Additional Drivers tool, then add CUDA if needed. Minimal CLI install:
```bash
sudo apt update
sudo apt install -y ubuntu-drivers-common
ubuntu-drivers devices   # see recommended driver
sudo ubuntu-drivers install   # installs the recommended driver
sudo reboot
```
After reboot, verify:
```bash
nvidia-smi
```
Ollama will detect CUDA automatically when available.

Step 4: Run Open WebUI (Docker)
Open WebUI connects to Ollama via its API (default `http://127.0.0.1:11434`).
```bash
docker run -d \
  --name open-webui \
  -p 3000:8080 \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -v open-webui:/app/backend/data \
  --restart unless-stopped \
  ghcr.io/open-webui/open-webui:latest
```
Notes:
- On Linux, `host.docker.internal` works on recent Docker. If it doesn't, you can either:
  - Add host gateway mapping: `--add-host=host.docker.internal:host-gateway`, or
  - Use host networking: `--network host` and set `-e OLLAMA_BASE_URL=http://127.0.0.1:11434`.
- Visit `http://SERVER_IP:3000` to access the UI.

Step 5 (optional): Make Ollama listen on LAN
By default, Ollama binds to localhost. To make it reachable (e.g., from other machines or containers without host network), create an override:
```bash
sudo systemctl edit ollama
```
Paste the following (then save):
```
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```
Apply the change:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```
Secure with a firewall (UFW) and reverse proxy auth if exposing publicly. For example, allow only your management IP and HTTPS:
```bash
sudo ufw allow 22/tcp
sudo ufw allow 443/tcp
sudo ufw allow from YOUR_IP to any port 11434 proto tcp  # optional, management only
sudo ufw enable
```

Step 6: Persist and manage with systemd (Open WebUI option)
If you prefer systemd over `docker run`, create a simple unit that uses Docker Compose or a raw Docker command. Example raw Docker service:
```bash
sudo tee /etc/systemd/system/open-webui.service > /dev/null <<'EOF'
[Unit]
Description=Open WebUI (Docker)
After=network-online.target docker.service
Wants=network-online.target

[Service]
Restart=always
TimeoutStartSec=0
ExecStartPre=/usr/bin/docker rm -f open-webui || true
ExecStart=/usr/bin/docker run --name open-webui \
  -p 3000:8080 \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
  -v open-webui:/app/backend/data \
  --restart unless-stopped \
  ghcr.io/open-webui/open-webui:latest
ExecStop=/usr/bin/docker stop open-webui

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now open-webui
```

Step 7 (optional): Reverse proxy (Nginx)
If you want `https://ai.example.com`, set up an Nginx proxy and a Let’s Encrypt cert. See this guide for TLS issuance and hardening: [Nginx + Certbot on Ubuntu 24.04]({{< relref "blog/linux/nginx-certbot-ubuntu-24-04-free-https-with-letsencrypt.md" >}})
Then proxy `ai.example.com` → `127.0.0.1:3000`.

Troubleshooting
- Port 11434 in use: `sudo lsof -i :11434` to find the process. Restart Ollama: `sudo systemctl restart ollama`.
- `nvidia-smi` missing or fails: ensure proper NVIDIA driver install; consider purging and reinstalling drivers.
- Open WebUI can’t reach Ollama: verify `OLLAMA_BASE_URL`, container networking, and that `curl http://127.0.0.1:11434/api/tags` returns JSON.
- Low RAM: try smaller models (e.g., `phi3`, `qwen2:0.5b`, or quantized variants) and keep a single model loaded.

Uninstall
Ollama:
```bash
sudo systemctl disable --now ollama
sudo rm -f /etc/systemd/system/ollama.service
sudo rm -rf /usr/local/bin/ollama ~/.ollama
sudo systemctl daemon-reload
```
Open WebUI:
```bash
sudo systemctl disable --now open-webui || true
sudo rm -f /etc/systemd/system/open-webui.service
sudo systemctl daemon-reload
docker rm -f open-webui || true
docker volume rm open-webui || true
```

That’s it — you now have a local AI stack on Ubuntu 24.04 with Ollama and Open WebUI. Start lightweight models first, then scale up as your hardware allows.
