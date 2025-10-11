#!/bin/bash

# ========================================
# Quick Manual Deploy Script
# For emergency deployments tanpa GitHub Actions
# ========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Quick Manual Deploy - Buana Coding${NC}"
echo ""

# Check if running on VPS
if [ ! -d "/var/www/buanacoding.com" ]; then
    echo -e "${RED}Error: Not running on VPS or /var/www/buanacoding.com not found${NC}"
    exit 1
fi

# Variables
REPO_URL="https://github.com/wikukarno/buanacoding.git"
TEMP_DIR="/tmp/buanacoding-deploy-$$"
WEB_ROOT="/var/www/buanacoding.com"
BACKUP_DIR="/var/www/buanacoding.com-backup-$(date +%Y%m%d-%H%M%S)"

# 1. Backup current site
echo -e "${YELLOW}Creating backup...${NC}"
sudo cp -r $WEB_ROOT $BACKUP_DIR
echo -e "${GREEN}Backup created: $BACKUP_DIR${NC}"
echo ""

# 2. Clone repository
echo -e "${YELLOW}Cloning repository...${NC}"
git clone --depth 1 $REPO_URL $TEMP_DIR
cd $TEMP_DIR
echo -e "${GREEN}Repository cloned${NC}"
echo ""

# 3. Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
npm ci
echo -e "${GREEN}Dependencies installed${NC}"
echo ""

# 4. Build Tailwind CSS
echo -e "${YELLOW}Building Tailwind CSS...${NC}"
chmod +x ./bin/tailwindcss
./bin/tailwindcss -i ./assets/css/style.css -o ./static/css/style.css --minify
echo -e "${GREEN}Tailwind CSS built${NC}"
echo ""

# 5. Build Hugo site
echo -e "${YELLOW}Building Hugo site...${NC}"
if ! command -v hugo &> /dev/null; then
    echo -e "${RED}Hugo not installed!${NC}"
    echo -e "${YELLOW}Installing Hugo...${NC}"

    # Detect architecture
    if [ "$(uname -m)" = "x86_64" ]; then
        HUGO_ARCH="amd64"
    else
        HUGO_ARCH="arm64"
    fi

    # Download and install Hugo
    wget -q https://github.com/gohugoio/hugo/releases/download/v0.121.0/hugo_extended_0.121.0_linux-${HUGO_ARCH}.tar.gz
    tar -xzf hugo_extended_0.121.0_linux-${HUGO_ARCH}.tar.gz
    sudo mv hugo /usr/local/bin/
    rm hugo_extended_0.121.0_linux-${HUGO_ARCH}.tar.gz
    echo -e "${GREEN}Hugo installed${NC}"
fi

hugo --minify --gc
echo -e "${GREEN}Hugo site built${NC}"
echo ""

# 6. Deploy to web root
echo -e "${YELLOW}Deploying to $WEB_ROOT...${NC}"
sudo rm -rf $WEB_ROOT/*
sudo cp -r public/* $WEB_ROOT/
echo -e "${GREEN}Files deployed${NC}"
echo ""

# 7. Set permissions
echo -e "${YELLOW}Setting permissions...${NC}"
sudo chown -R www-data:www-data $WEB_ROOT
sudo find $WEB_ROOT -type d -exec chmod 755 {} \;
sudo find $WEB_ROOT -type f -exec chmod 644 {} \;
echo -e "${GREEN}Permissions set${NC}"
echo ""

# 8. Reload Nginx
echo -e "${YELLOW}Reloading Nginx...${NC}"
sudo systemctl reload nginx
echo -e "${GREEN}Nginx reloaded${NC}"
echo ""

# 9. Cleanup
echo -e "${YELLOW}Cleaning up...${NC}"
cd /
rm -rf $TEMP_DIR
echo -e "${GREEN}Cleanup completed${NC}"
echo ""

# 10. Test website
echo -e "${YELLOW}Testing website...${NC}"
RESPONSE=$(curl -o /dev/null -s -w "%{http_code}" https://www.buanacoding.com)
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}Website is up! HTTP $RESPONSE${NC}"
else
    echo -e "${RED}Website returned HTTP $RESPONSE${NC}"
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Backup location: $BACKUP_DIR${NC}"
echo -e "${YELLOW}Website: https://www.buanacoding.com${NC}"
echo ""
echo -e "${YELLOW}To rollback:${NC}"
echo -e "  sudo rm -rf $WEB_ROOT/*"
echo -e "  sudo cp -r $BACKUP_DIR/* $WEB_ROOT/"
echo -e "  sudo systemctl reload nginx"
