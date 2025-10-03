---
title: 'Deploy Laravel to VPS with Nginx Complete Production Guide'
date: 2025-08-24T09:00:00.000+07:00
draft: false
url: /2025/08/deploy-laravel-to-vps-with-nginx-complete-guide.html
tags:
  - Laravel
description: "Complete step-by-step guide to deploy Laravel applications to VPS using Nginx, PHP-FPM, SSL certificate, and production best practices for optimal performance and security."
keywords: ["laravel deployment", "vps deployment", "nginx laravel", "laravel production", "laravel nginx ssl", "deploy laravel ubuntu", "laravel server setup"]
---

Deploying a Laravel application to a VPS (Virtual Private Server) with Nginx gives you complete control over your hosting environment and superior performance compared to shared hosting. This comprehensive guide will walk you through the entire process, from server setup to production optimization.

## What You'll Learn

- Set up a VPS for Laravel deployment
- Configure Nginx for optimal Laravel performance
- Secure your application with SSL certificates
- Implement production best practices
- Set up automated deployments
- Monitor and maintain your application

## Prerequisites

Before starting, ensure you have:

- A VPS running Ubuntu 20.04/22.04 LTS (DigitalOcean, Linode, AWS EC2, etc.)
- SSH access to your server
- A domain name pointing to your VPS IP
- Basic terminal/command line knowledge
- A Laravel application ready for deployment

## Step 1: Initial Server Setup

### Connect to Your VPS

```bash
ssh root@your-server-ip
```

### Update System Packages

```bash
apt update && apt upgrade -y
```

### Create a Non-Root User

```bash
# Create new user
adduser deploy

# Add to sudo group
usermod -aG sudo deploy

# Switch to new user
su - deploy
```

### Configure SSH Key Authentication

```bash
# On your local machine, copy your public key
ssh-copy-id deploy@your-server-ip

# Or manually add your key
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
# Paste your public key and save
chmod 600 ~/.ssh/authorized_keys
```

## Step 2: Install Required Software

### Install Nginx

```bash
sudo apt install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
```

### Install PHP 8.2 and Extensions

```bash
# Add PHP repository
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Install PHP and required extensions
sudo apt install php8.2-fpm php8.2-common php8.2-mysql php8.2-xml php8.2-xmlrpc php8.2-curl php8.2-gd php8.2-imagick php8.2-cli php8.2-dev php8.2-imap php8.2-mbstring php8.2-opcache php8.2-soap php8.2-zip php8.2-intl php8.2-bcmath -y
```

### Install Composer

```bash
cd ~
curl -sS https://getcomposer.org/installer -o composer-setup.php
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php
```

### Install MySQL

```bash
sudo apt install mysql-server -y
sudo mysql_secure_installation
```

### Create Database and User

```bash
sudo mysql -u root -p
```

```sql
CREATE DATABASE laravel_app;
CREATE USER 'laravel_user'@'localhost' IDENTIFIED BY 'strong_password_here';
GRANT ALL PRIVILEGES ON laravel_app.* TO 'laravel_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### Install Git

```bash
sudo apt install git -y
```

## Step 3: Deploy Your Laravel Application

### Clone Your Repository

```bash
cd /var/www
sudo git clone https://github.com/username/your-laravel-app.git
sudo chown -R deploy:deploy your-laravel-app
cd your-laravel-app
```

### Install Dependencies

```bash
composer install --optimize-autoloader --no-dev
```

### Configure Environment

```bash
cp .env.example .env
nano .env
```

Update your `.env` file:

```env
APP_NAME="Your Laravel App"
APP_ENV=production
APP_DEBUG=false
APP_URL=https://yourdomain.com

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel_app
DB_USERNAME=laravel_user
DB_PASSWORD=strong_password_here

CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120
```

### Generate Application Key

```bash
php artisan key:generate
```

### Run Database Migrations

```bash
php artisan migrate --force
```

### Optimize for Production

```bash
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan storage:link
```

### Set File Permissions

```bash
sudo chown -R www-data:www-data /var/www/your-laravel-app
sudo chmod -R 755 /var/www/your-laravel-app
sudo chmod -R 775 /var/www/your-laravel-app/storage
sudo chmod -R 775 /var/www/your-laravel-app/bootstrap/cache
```

## Step 4: Configure Nginx

### Create Nginx Configuration

```bash
sudo nano /etc/nginx/sites-available/your-laravel-app
```

Add the following configuration:

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    root /var/www/your-laravel-app/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    # Security headers
    add_header Referrer-Policy "no-referrer-when-downgrade";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    # Asset caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Deny access to sensitive files
    location ~ /\.(htaccess|htpasswd|env) {
        deny all;
    }

    # Client max body size (for file uploads)
    client_max_body_size 20M;
}
```

### Enable the Site

```bash
sudo ln -s /etc/nginx/sites-available/your-laravel-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Remove Default Nginx Site

```bash
sudo rm /etc/nginx/sites-enabled/default
```

## Step 5: Configure PHP-FPM

### Optimize PHP-FPM Settings

```bash
sudo nano /etc/php/8.2/fpm/pool.d/www.conf
```

Update these settings:

```ini
user = www-data
group = www-data
listen.owner = www-data
listen.group = www-data

pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
```

### PHP Configuration

```bash
sudo nano /etc/php/8.2/fpm/php.ini
```

Update these settings:

```ini
upload_max_filesize = 20M
post_max_size = 25M
memory_limit = 256M
max_execution_time = 300
max_input_vars = 3000
opcache.enable=1
opcache.memory_consumption=128
opcache.max_accelerated_files=10000
```

### Restart PHP-FPM

```bash
sudo systemctl restart php8.2-fpm
```

## Step 6: SSL Certificate with Let's Encrypt

### Install Certbot

```bash
sudo apt install certbot python3-certbot-nginx -y
```

### Obtain SSL Certificate

```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

### Auto-renewal Setup

```bash
sudo crontab -e
```

Add this line:

```bash
0 12 * * * /usr/bin/certbot renew --quiet
```

## Step 7: Firewall Configuration

### Configure UFW

```bash
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
sudo ufw status
```

## Step 8: Production Optimization

### Configure Queue Processing

Create a supervisor configuration:

```bash
sudo apt install supervisor -y
sudo nano /etc/supervisor/conf.d/laravel-worker.conf
```

```ini
[program:laravel-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/your-laravel-app/artisan queue:work
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/your-laravel-app/storage/logs/worker.log
stopwaitsecs=3600
```

```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start laravel-worker:*
```

### Setup Log Rotation

```bash
sudo nano /etc/logrotate.d/laravel
```

```bash
/var/www/your-laravel-app/storage/logs/*.log {
    daily
    rotate 14
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
}
```

### Configure Redis (Optional)

```bash
sudo apt install redis-server -y
sudo systemctl enable redis-server
```

Update `.env`:

```env
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
```

## Step 9: Automated Deployment Script

Create a deployment script:

```bash
nano ~/deploy.sh
```

```bash
#!/bin/bash

APP_DIR="/var/www/your-laravel-app"
BRANCH="main"

echo "Starting deployment..."

# Navigate to app directory
cd $APP_DIR

# Enable maintenance mode
sudo -u www-data php artisan down

# Pull latest changes
git pull origin $BRANCH

# Install/update composer dependencies
sudo -u www-data composer install --optimize-autoloader --no-dev

# Clear and cache config
sudo -u www-data php artisan config:clear
sudo -u www-data php artisan config:cache

# Clear and cache routes
sudo -u www-data php artisan route:clear
sudo -u www-data php artisan route:cache

# Clear and cache views
sudo -u www-data php artisan view:clear
sudo -u www-data php artisan view:cache

# Run database migrations
sudo -u www-data php artisan migrate --force

# Restart PHP-FPM and queue workers
sudo systemctl reload php8.2-fpm
sudo supervisorctl restart laravel-worker:*

# Disable maintenance mode
sudo -u www-data php artisan up

echo "Deployment completed successfully!"
```

Make it executable:

```bash
chmod +x ~/deploy.sh
```

## Step 10: Monitoring and Security

### Install Fail2Ban

```bash
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
```

### Configure Nginx Rate Limiting

Add to your Nginx configuration:

```nginx
# Add to http block in /etc/nginx/nginx.conf
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

# Add to your server block
location /login {
    limit_req zone=login burst=5 nodelay;
    try_files $uri $uri/ /index.php?$query_string;
}
```

### Monitor Logs

```bash
# View Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# View Laravel logs
tail -f /var/www/your-laravel-app/storage/logs/laravel.log

# View PHP-FPM logs
sudo tail -f /var/log/php8.2-fpm.log
```

## Step 11: Backup Strategy

### Database Backup Script

```bash
nano ~/backup-db.sh
```

```bash
#!/bin/bash

BACKUP_DIR="/home/deploy/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="laravel_app"
DB_USER="laravel_user"
DB_PASS="your_password"

mkdir -p $BACKUP_DIR

# Create database backup
mysqldump -u $DB_USER -p$DB_PASS $DB_NAME > $BACKUP_DIR/db_backup_$DATE.sql

# Keep only last 7 days of backups
find $BACKUP_DIR -name "db_backup_*.sql" -mtime +7 -delete

echo "Database backup completed: $BACKUP_DIR/db_backup_$DATE.sql"
```

### Schedule Daily Backups

```bash
crontab -e
```

```bash
0 2 * * * /home/deploy/backup-db.sh
```

## Troubleshooting Common Issues

### 1. 502 Bad Gateway

```bash
# Check PHP-FPM status
sudo systemctl status php8.2-fpm

# Check PHP-FPM socket
sudo ls -la /var/run/php/

# Restart services
sudo systemctl restart php8.2-fpm nginx
```

### 2. Permission Issues

```bash
sudo chown -R www-data:www-data /var/www/your-laravel-app
sudo chmod -R 755 /var/www/your-laravel-app
sudo chmod -R 775 /var/www/your-laravel-app/storage
sudo chmod -R 775 /var/www/your-laravel-app/bootstrap/cache
```

### 3. Storage Link Issues

```bash
php artisan storage:link
sudo chown -R www-data:www-data /var/www/your-laravel-app/public/storage
```

### 4. Memory Issues

```bash
# Increase PHP memory limit
sudo nano /etc/php/8.2/fpm/php.ini
# Set: memory_limit = 512M

# Restart PHP-FPM
sudo systemctl restart php8.2-fpm
```

## Performance Optimization Tips

### 1. Enable OPcache

Ensure these settings in `/etc/php/8.2/fpm/php.ini`:

```ini
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0
opcache.save_comments=1
opcache.fast_shutdown=0
```

### 2. Optimize MySQL

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

```ini
[mysqld]
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
query_cache_type = 1
query_cache_size = 32M
```

### 3. Use CDN for Assets

Consider using a CDN service like Cloudflare for static assets to improve loading times globally.

## Security Best Practices

1. **Regular Updates**: Keep your server and applications updated
2. **Strong Passwords**: Use complex passwords and consider key-based authentication
3. **Firewall**: Configure UFW properly
4. **SSL/TLS**: Always use HTTPS in production
5. **Hide Server Info**: Remove server version information from headers
6. **Regular Backups**: Implement automated backup strategies
7. **Monitor Logs**: Regularly check access and error logs
8. **Rate Limiting**: Implement rate limiting for sensitive endpoints

## Conclusion

You now have a robust Laravel application running on a VPS with Nginx, complete with SSL certificates, optimization, and security measures. This setup provides excellent performance and gives you full control over your hosting environment.

Key benefits of this setup:
- **Performance**: Nginx + PHP-FPM provides excellent performance
- **Security**: SSL certificates and security headers protect your application
- **Scalability**: Easy to scale as your application grows
- **Control**: Full control over server configuration and optimization
- **Cost-effective**: VPS hosting is often more cost-effective than managed hosting

Remember to:
- Monitor your application regularly
- Keep everything updated
- Implement proper backup strategies
- Test your deployment process in a staging environment first

Happy deploying!