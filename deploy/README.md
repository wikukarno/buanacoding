# Deployment Guide - Buana Coding ke VPS Ubuntu

Panduan lengkap untuk deploy Buana Coding dari Vercel ke VPS Ubuntu dengan auto-deployment menggunakan GitHub Actions.

## Prasyarat

### VPS Requirements
- Ubuntu 22.04/24.04 LTS
- RAM: Minimal 2GB (recommended 4GB+)
- Storage: Minimal 20GB
- CPU: Minimal 2 cores
- Root/sudo access

### Domain & DNS
- Domain: buanacoding.com & www.buanacoding.com
- DNS A Record pointing ke IP VPS

### GitHub Repository
- Repository public: Yes
- GitHub Actions enabled: Yes

---

## Setup VPS (One-Time Setup)

### 1. Koneksi ke VPS

```bash
ssh root@YOUR_VPS_IP
```

### 2. Jalankan Setup Script

```bash
# Download setup script
wget https://raw.githubusercontent.com/wikukarno/buanacoding/main/deploy/setup-vps.sh

# Atau jika clone repository
git clone https://github.com/wikukarno/buanacoding.git
cd buanacoding/deploy

# Jalankan script
sudo bash setup-vps.sh
```

Script ini akan:
- Update system packages
- Install Nginx, Certbot, UFW, Fail2ban
- Install Node.js 20
- Buat user `deploy`
- Setup firewall rules
- Buat web directory `/var/www/buanacoding.com`
- Configure security

### 3. Generate SSH Keys untuk GitHub Actions

Di **local machine** (bukan VPS):

```bash
# Generate SSH key pair
ssh-keygen -t ed25519 -C "github-actions-buanacoding" -f ~/.ssh/github_actions_buanacoding

# Lihat public key
cat ~/.ssh/github_actions_buanacoding.pub

# Lihat private key (untuk GitHub Secrets)
cat ~/.ssh/github_actions_buanacoding
```

### 4. Tambahkan Public Key ke VPS

Di **VPS**, tambahkan public key ke authorized_keys:

```bash
# Login sebagai deploy user
sudo su - deploy

# Tambahkan public key
echo "YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys

# Set permissions
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh

exit
```

Test koneksi SSH:

```bash
# Di local machine
ssh -i ~/.ssh/github_actions_buanacoding deploy@YOUR_VPS_IP
```

Jika berhasil login, berarti SSH key sudah benar!

---

## Setup Nginx

### 1. Copy Nginx Configuration

```bash
# Di VPS
sudo cp /var/www/buanacoding.com/deploy/nginx-buanacoding.conf /etc/nginx/sites-available/buanacoding.com

# Atau copy manual dari repository
sudo nano /etc/nginx/sites-available/buanacoding.com
# Paste konfigurasi dari deploy/nginx-buanacoding.conf
```

### 2. Enable Site

```bash
# Buat symbolic link
sudo ln -s /etc/nginx/sites-available/buanacoding.com /etc/nginx/sites-enabled/

# Hapus default site (opsional)
sudo rm /etc/nginx/sites-enabled/default

# Test konfigurasi
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### 3. Setup SSL dengan Let's Encrypt

```bash
# Install SSL certificate
sudo certbot --nginx -d buanacoding.com -d www.buanacoding.com

# Pilih opsi:
# 1. Email address (untuk renewal notifications)
# 2. Agree to Terms of Service: Yes
# 3. Redirect HTTP to HTTPS: Yes (option 2)
```

Certbot akan otomatis:
- Generate SSL certificate
- Update Nginx config
- Setup auto-renewal (cron job)

Test SSL renewal:

```bash
sudo certbot renew --dry-run
```

---

## Setup GitHub Secrets

Buka repository di GitHub → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Tambahkan secrets berikut:

### 1. SSH_PRIVATE_KEY

```bash
# Copy seluruh isi private key
cat ~/.ssh/github_actions_buanacoding
```

Paste ke GitHub Secrets dengan nama: `SSH_PRIVATE_KEY`

### 2. REMOTE_HOST

Value: IP address VPS kamu
```
Example: 203.0.113.50
```

### 3. REMOTE_USER

Value: `deploy`

### 4. REMOTE_TARGET

Value: `/var/www/buanacoding.com`

---

## Testing Deployment

### 1. Manual Trigger

Buka repository → **Actions** → **Deploy to VPS** → **Run workflow**

### 2. Auto Deploy (Push to Main)

```bash
# Di local machine
cd /path/to/buanacoding

# Buat perubahan kecil
echo "# Test deployment" >> deploy/README.md

# Commit dan push
git add .
git commit -m "test: trigger deployment"
git push origin main
```

GitHub Actions akan otomatis:
1. Checkout repository
2. Setup Hugo
3. Setup Node.js
4. Build Tailwind CSS
5. Build Hugo site
6. Deploy ke VPS via SSH
7. Set permissions
8. Reload Nginx

### 3. Monitor Deployment

Buka **Actions** tab di GitHub untuk melihat progress real-time.

### 4. Verify Website

```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://www.buanacoding.com

# Test HTTPS
curl -I https://www.buanacoding.com

# Test SSL grade
curl https://www.ssllabs.com/ssltest/analyze.html?d=www.buanacoding.com
```

Buka browser: https://www.buanacoding.com

---

## Monitoring & Maintenance

### Check Nginx Logs

```bash
# Access logs
sudo tail -f /var/log/nginx/buanacoding.com/access.log

# Error logs
sudo tail -f /var/log/nginx/buanacoding.com/error.log
```

### Check Nginx Status

```bash
sudo systemctl status nginx
```

### Reload Nginx (after config changes)

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### Check Disk Space

```bash
df -h
du -sh /var/www/buanacoding.com
```

### Check SSL Certificate Expiry

```bash
sudo certbot certificates
```

### Manual SSL Renewal

```bash
sudo certbot renew
sudo systemctl reload nginx
```

---

## Troubleshooting

### Issue: GitHub Actions deployment gagal (Permission denied)

**Solusi:**

```bash
# Di VPS, cek permissions
ls -la /var/www/buanacoding.com

# Fix permissions
sudo chown -R deploy:deploy /var/www/buanacoding.com
sudo chmod -R 755 /var/www/buanacoding.com
```

### Issue: Nginx 502 Bad Gateway

**Solusi:**

```bash
# Cek error logs
sudo tail -50 /var/log/nginx/buanacoding.com/error.log

# Cek apakah file ada
ls -la /var/www/buanacoding.com/index.html

# Reload Nginx
sudo systemctl reload nginx
```

### Issue: SSL certificate error

**Solusi:**

```bash
# Renew certificate
sudo certbot renew --force-renewal

# Reload Nginx
sudo systemctl reload nginx
```

### Issue: Website tidak bisa diakses

**Cek Firewall:**

```bash
sudo ufw status
sudo ufw allow 'Nginx Full'
```

**Cek Nginx:**

```bash
sudo systemctl status nginx
sudo nginx -t
```

**Cek DNS:**

```bash
dig buanacoding.com
dig www.buanacoding.com
```

---

## Optimizations

### Enable Brotli Compression (Optional)

```bash
# Install Brotli module
sudo apt install nginx-module-brotli

# Add to Nginx config
sudo nano /etc/nginx/nginx.conf
```

Add inside `http` block:

```nginx
brotli on;
brotli_comp_level 6;
brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/svg+xml;
```

### Setup Log Rotation

Nginx log rotation sudah otomatis via logrotate. Config ada di:

```bash
/etc/logrotate.d/nginx
```

### Monitor with htop

```bash
sudo apt install htop
htop
```

---

## File Structure di VPS

```
/var/www/buanacoding.com/
├── 404.html
├── ads.txt
├── blog/
│   ├── general/
│   ├── go/
│   ├── laravel/
│   ├── linux/
│   ├── python/
│   └── security/
├── css/
├── images/
├── index.html
├── robots.txt
├── sitemap.xml
└── tags/
```

---

## Workflow Summary

```
Developer Push → GitHub Repository → GitHub Actions
                                           ↓
                                    1. Checkout code
                                    2. Setup Hugo
                                    3. Build Tailwind
                                    4. Build Hugo
                                    5. Deploy via SSH
                                           ↓
                                     VPS Ubuntu
                                           ↓
                                    /var/www/buanacoding.com
                                           ↓
                                    Nginx serves site
                                           ↓
                                 https://www.buanacoding.com
```

---

## Support

Jika ada masalah:

1. Cek GitHub Actions logs
2. Cek Nginx error logs: `/var/log/nginx/buanacoding.com/error.log`
3. Cek SSH connection: `ssh -i ~/.ssh/github_actions_buanacoding deploy@VPS_IP`
4. Verify DNS: `dig www.buanacoding.com`
5. Test Nginx config: `sudo nginx -t`

---

## Checklist Deployment

- [ ] VPS setup completed (`setup-vps.sh`)
- [ ] SSH keys generated dan ditambahkan
- [ ] Nginx installed dan configured
- [ ] SSL certificate installed
- [ ] GitHub Secrets configured
- [ ] DNS pointing to VPS IP
- [ ] Test deployment via GitHub Actions
- [ ] Website accessible via HTTPS
- [ ] Redirect non-www to www working
- [ ] SSL grade A+ (check ssllabs.com)
- [ ] Auto-deployment working on push

---

**Happy Deploying!**
