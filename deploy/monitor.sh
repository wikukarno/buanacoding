#!/bin/bash

# ========================================
# Monitoring Script for Buana Coding
# Quick status check untuk VPS
# ========================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Buana Coding - Status Monitor${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Nginx Status
echo -e "${YELLOW}Nginx Status:${NC}"
if systemctl is-active --quiet nginx; then
    echo -e "   ${GREEN}Running${NC}"
else
    echo -e "   ${RED}Not running${NC}"
fi
echo ""

# 2. Disk Usage
echo -e "${YELLOW}Disk Usage:${NC}"
df -h / | tail -n 1 | awk '{print "   Used: "$3" / "$2" ("$5")"}'
echo ""

# 3. Memory Usage
echo -e "${YELLOW}Memory Usage:${NC}"
free -h | awk 'NR==2{printf "   Used: %s / %s (%.2f%%)\n", $3, $2, $3*100/$2}'
echo ""

# 4. Website Directory Size
echo -e "${YELLOW}Website Size:${NC}"
if [ -d "/var/www/buanacoding.com" ]; then
    du -sh /var/www/buanacoding.com | awk '{print "   "$1}'
else
    echo -e "   ${RED}Directory not found${NC}"
fi
echo ""

# 5. SSL Certificate Status
echo -e "${YELLOW}SSL Certificate:${NC}"
if command -v certbot &> /dev/null; then
    CERT_INFO=$(sudo certbot certificates 2>/dev/null | grep -A 2 "buanacoding.com" | grep "Expiry Date")
    if [ ! -z "$CERT_INFO" ]; then
        echo "   $CERT_INFO"
    else
        echo -e "   ${RED}No certificate found${NC}"
    fi
else
    echo -e "   ${YELLOW}Certbot not installed${NC}"
fi
echo ""

# 6. Recent Access Logs (last 5)
echo -e "${YELLOW}Recent Access (Last 5):${NC}"
if [ -f "/var/log/nginx/buanacoding.com/access.log" ]; then
    tail -5 /var/log/nginx/buanacoding.com/access.log | awk '{print "   "$1" - "$7" - "$9}'
else
    echo -e "   ${RED}Log file not found${NC}"
fi
echo ""

# 7. Error Count (Today)
echo -e "${YELLOW}Error Count (Today):${NC}"
if [ -f "/var/log/nginx/buanacoding.com/error.log" ]; then
    TODAY=$(date +%Y/%m/%d)
    ERROR_COUNT=$(grep "$TODAY" /var/log/nginx/buanacoding.com/error.log 2>/dev/null | wc -l)
    echo -e "   $ERROR_COUNT errors"
else
    echo -e "   ${YELLOW}Log file not found${NC}"
fi
echo ""

# 8. Website Response Test
echo -e "${YELLOW}Website Response:${NC}"
RESPONSE=$(curl -o /dev/null -s -w "%{http_code}" https://www.buanacoding.com)
if [ "$RESPONSE" = "200" ]; then
    echo -e "   ${GREEN}HTTP $RESPONSE - Website is up!${NC}"
else
    echo -e "   ${RED}HTTP $RESPONSE - Website may be down!${NC}"
fi
echo ""

# 9. Last Deployment
echo -e "${YELLOW}Last Deployment:${NC}"
if [ -d "/var/www/buanacoding.com" ]; then
    LAST_MOD=$(stat -c %y /var/www/buanacoding.com/index.html 2>/dev/null || stat -f "%Sm" /var/www/buanacoding.com/index.html 2>/dev/null)
    echo -e "   $LAST_MOD"
else
    echo -e "   ${RED}Unknown${NC}"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Use: sudo systemctl status nginx (detailed status)${NC}"
echo -e "${GREEN}Use: sudo tail -f /var/log/nginx/buanacoding.com/error.log (live errors)${NC}"
echo -e "${BLUE}========================================${NC}"
