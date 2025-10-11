#!/bin/bash

# ========================================
# VPS Setup Script for Buana Coding
# Ubuntu 22.04/24.04 LTS
# ========================================

set -e

echo "Starting VPS setup for Buana Coding..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo -e "${RED}Please run as root (use sudo)${NC}"
   exit 1
fi

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
apt update && apt upgrade -y

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
apt install -y nginx certbot python3-certbot-nginx ufw fail2ban git curl wget

# Install Node.js (for potential future needs)
echo -e "${YELLOW}Installing Node.js...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Create deploy user
echo -e "${YELLOW}Creating deploy user...${NC}"
if ! id "deploy" &>/dev/null; then
    useradd -m -s /bin/bash deploy
    usermod -aG sudo deploy
    echo "deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl reload nginx, /usr/bin/systemctl restart nginx, /usr/bin/chown, /usr/bin/find, /usr/bin/chmod" >> /etc/sudoers.d/deploy
    chmod 440 /etc/sudoers.d/deploy
    echo -e "${GREEN}User 'deploy' created${NC}"
else
    echo -e "${GREEN}User 'deploy' already exists${NC}"
fi

# Create web directory
echo -e "${YELLOW}Creating web directory...${NC}"
WEB_ROOT="/var/www/buanacoding.com"
mkdir -p $WEB_ROOT
chown -R deploy:deploy $WEB_ROOT
chmod -R 755 $WEB_ROOT

# Setup SSH for deploy user
echo -e "${YELLOW}Setting up SSH for deploy user...${NC}"
mkdir -p /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
touch /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh

echo -e "${YELLOW}Add your GitHub Actions public key to: /home/deploy/.ssh/authorized_keys${NC}"

# Configure UFW Firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
ufw --force enable
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw status

# Configure Fail2ban
echo -e "${YELLOW}Configuring Fail2ban...${NC}"
systemctl enable fail2ban
systemctl start fail2ban

# Create Nginx log directory
mkdir -p /var/log/nginx/buanacoding.com
chown -R www-data:adm /var/log/nginx/buanacoding.com

echo -e "${GREEN}VPS setup completed!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Add SSH public key to /home/deploy/.ssh/authorized_keys"
echo "2. Copy and configure Nginx config: /etc/nginx/sites-available/buanacoding.com"
echo "3. Create symbolic link: ln -s /etc/nginx/sites-available/buanacoding.com /etc/nginx/sites-enabled/"
echo "4. Test Nginx config: nginx -t"
echo "5. Reload Nginx: systemctl reload nginx"
echo "6. Setup SSL: certbot --nginx -d buanacoding.com -d www.buanacoding.com"
echo "7. Configure GitHub Secrets in repository settings"
