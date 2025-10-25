---
title: 'How to Set Up and Manage Firewall on Linux with UFW and Firewalld'
date: 2025-10-25T14:00:00+07:00
draft: false
url: /2025/10/how-to-manage-firewall-linux-ufw-firewalld.html
tags:
- Linux
- Firewall
- UFW
- Firewalld
- Security
- Ubuntu
- CentOS
description: 'Master Linux firewall configuration with UFW for Ubuntu/Debian and Firewalld for CentOS/RHEL. Learn how to set up allow/deny rules, manage ports, whitelist/blacklist IP addresses, configure firewall zones, create rich rules for advanced filtering, and implement security best practices to protect your server from attacks.'
keywords: ['linux firewall','ufw ubuntu','firewalld centos','ufw commands','firewall rules','port forwarding','ip whitelisting','firewall zones','ufw allow deny','firewalld rich rules']
featured: false
faq:
  - question: "What is the difference between UFW and Firewalld?"
    answer: "UFW (Uncomplicated Firewall) is the default on Ubuntu/Debian, designed for simplicity with straightforward commands like ufw allow 80. Firewalld is default on RHEL/CentOS/Fedora, more powerful with zones and rich rules but has a steeper learning curve. UFW uses iptables/nftables as backend, Firewalld uses nftables/iptables. UFW is better for simple servers needing basic port rules. Firewalld is better for complex enterprise setups with multiple network interfaces and dynamic rules. Both protect your server equally well when configured right."
  - question: "Should I use default deny or default allow policy for incoming connections?"
    answer: "Always use default deny for incoming connections. This blocks everything by default and you explicitly allow only what you need (SSH, HTTP, etc.). Default allow would let all traffic through unless explicitly denied, which is dangerous because you'd need to deny every possible attack vector. With default deny, forgotten services don't become security holes. The principle: deny all, allow specific. All major firewall guides recommend deny incoming, allow outgoing. Outgoing can be allow by default unless you're running a zero-trust environment."
  - question: "How do I allow a port only for specific IP addresses with UFW?"
    answer: "Use from clause in UFW: sudo ufw allow from 192.168.1.100 to any port 22 allows SSH only from that IP. Or sudo ufw allow from 192.168.1.0/24 to any port 3306 allows MySQL from that subnet. Deny works the same: sudo ufw deny from 203.0.113.0/24. Check rules with sudo ufw status numbered. Delete specific rules by number: sudo ufw delete 2. This is perfect for restricting admin panels, databases, or SSH to office IPs while blocking the rest of the internet."
  - question: "What are Firewalld zones and when should I use them?"
    answer: "Zones are security levels for different network interfaces or connections. Common zones: public (default, low trust for internet-facing), home (higher trust for home networks), work (medium trust), trusted (full access), dmz (isolated servers), drop (reject everything). Each zone has different default rules. Use zones when a server has multiple network interfaces (eth0 facing internet in public zone, eth1 facing internal network in trusted zone). Change interface zones with sudo firewall-cmd --zone=home --change-interface=eth1. Most single-interface servers just use public zone."
  - question: "How do I make firewall rules permanent instead of temporary?"
    answer: "UFW: All rules are permanent by default, saved to /etc/ufw/*.rules and survive reboots. No flags needed. Firewalld: Add --permanent flag to make rules permanent: sudo firewall-cmd --permanent --add-service=http. Without --permanent, rules only last until firewalld restart. Reload to apply permanent rules: sudo firewall-cmd --reload. Or add to runtime and save: sudo firewall-cmd --add-service=http then sudo firewall-cmd --runtime-to-permanent. Check permanent config: sudo firewall-cmd --permanent --list-all. Always use --permanent in production."
  - question: "Can I backup and restore my firewall rules?"
    answer: "UFW: Backup rules with sudo cp /etc/ufw/*.rules /backup/. Restore by copying back and sudo ufw reload. Or use iptables-save > firewall-backup.txt. Firewalld: Backup /etc/firewalld/ directory: sudo tar -czf firewall-backup.tar.gz /etc/firewalld/. Restore by extracting and reloading: sudo firewall-cmd --reload. For both, test backups by restoring on a test server first. Take backups before major changes. Store backups encrypted off-server. Automating backups with cron prevents disasters when rules break."
---

Firewalls control what network traffic can reach your Linux server. Without a firewall, every service you run is exposed to the internet. Attackers scan for open ports and exploit vulnerable services. A firewall blocks unwanted traffic while allowing legitimate connections.

This guide covers firewall management on Linux using UFW (Ubuntu/Debian) and Firewalld (RHEL/CentOS). You'll learn how to allow and deny ports, manage application profiles, restrict access by IP address, configure zones, set up port forwarding, and troubleshoot common issues.

<!--readmore-->

## Why firewalls matter for Linux servers

Every network service binds to a port. SSH on 22, HTTP on 80, MySQL on 3306. If these ports are open to the internet, attackers can access them.

A firewall blocks ports by default and you explicitly allow only what's needed. This reduces your attack surface dramatically.

Real example: You install MySQL for a web app. Without a firewall, MySQL listens on 0.0.0.0:3306 (all interfaces). Anyone can try to connect. With a firewall, you allow port 3306 only from localhost or your application server IP. External access blocked.

Firewalls also stop port scans, DDoS amplification attacks, and block known malicious IPs.

## UFW vs Firewalld: Which to use

UFW is default on Ubuntu, Debian, and derivatives. Simple syntax, perfect for basic setups.

Firewalld is default on RHEL, CentOS, Fedora, AlmaLinux, Rocky Linux. More features, zone-based, suited for enterprise.

Both use nftables or iptables as backend. Both work well. Use whichever comes with your distro.

This guide covers both. Skip to the section for your system.

## UFW Firewall (Ubuntu/Debian)

### Install UFW

UFW comes pre-installed on Ubuntu. If missing:

```bash
sudo apt update
sudo apt install ufw -y
```

Check status:

```bash
sudo ufw status
```

Should show "Status: inactive" initially.

### Set default policies

Default deny incoming, allow outgoing:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

This blocks all incoming connections unless explicitly allowed. Outgoing connections (your server connecting to update servers, APIs, etc.) are allowed.

### Allow SSH before enabling firewall

Critical: Allow SSH before enabling UFW or you'll lock yourself out of remote servers.

```bash
sudo ufw allow ssh
# Or specific port if you changed it
sudo ufw allow 2222/tcp
```

### Enable UFW

```bash
sudo ufw enable
```

Confirm with "y". UFW is now active.

Check status:

```bash
sudo ufw status verbose
```

Shows:
```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
```

### Allow ports and services

Allow specific ports:

```bash
# Allow port 80 (HTTP)
sudo ufw allow 80/tcp

# Allow port 443 (HTTPS)
sudo ufw allow 443/tcp

# Allow UDP port
sudo ufw allow 53/udp

# Allow port range
sudo ufw allow 6000:6007/tcp
```

Allow by service name:

```bash
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 'Nginx Full'  # HTTP + HTTPS
sudo ufw allow 'OpenSSH'
```

Service names come from `/etc/services` and application profiles in `/etc/ufw/applications.d/`.

### Deny specific ports

```bash
sudo ufw deny 3306/tcp  # Block MySQL from external access
sudo ufw deny 5432/tcp  # Block PostgreSQL
```

Deny takes precedence if there's a conflict.

### Allow from specific IP addresses

Allow SSH only from your office IP:

```bash
sudo ufw allow from 203.0.113.50 to any port 22
```

Allow MySQL only from application server:

```bash
sudo ufw allow from 10.0.0.5 to any port 3306
```

Allow entire subnet:

```bash
sudo ufw allow from 192.168.1.0/24 to any port 22
```

### Deny specific IPs

Block an abusive IP:

```bash
sudo ufw deny from 198.51.100.50
```

Block entire subnet:

```bash
sudo ufw deny from 198.51.100.0/24
```

### Delete rules

List rules with numbers:

```bash
sudo ufw status numbered
```

Output:
```
     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere
[ 2] 80/tcp                     ALLOW IN    Anywhere
[ 3] 443/tcp                    ALLOW IN    Anywhere
```

Delete by number:

```bash
sudo ufw delete 2  # Deletes rule 2 (port 80)
```

Or delete by rule specification:

```bash
sudo ufw delete allow 80/tcp
```

### Rate limiting (prevent brute-force)

Limit SSH connections (max 6 attempts in 30 seconds):

```bash
sudo ufw limit ssh
```

This is similar to fail2ban but built into UFW. Useful for SSH protection.

### Allow specific interfaces

Only allow connections on specific network interface:

```bash
sudo ufw allow in on eth0 to any port 80
sudo ufw allow in on eth1 to any port 3306  # Database on private network
```

### UFW application profiles

List available profiles:

```bash
sudo ufw app list
```

Common profiles:
- Nginx Full (80, 443)
- Nginx HTTP (80)
- Nginx HTTPS (443)
- OpenSSH (22)
- Apache Full (80, 443)

Allow profile:

```bash
sudo ufw allow 'Nginx Full'
```

View profile details:

```bash
sudo ufw app info 'Nginx Full'
```

Create custom profile in `/etc/ufw/applications.d/myapp`:

```
[MyApp]
title=My Application
description=Custom app using port 8080
ports=8080/tcp
```

Update app list and allow:

```bash
sudo ufw app update MyApp
sudo ufw allow MyApp
```

### UFW logging

Enable logging:

```bash
sudo ufw logging on
```

Log levels: off, low, medium, high, full.

```bash
sudo ufw logging medium
```

View logs:

```bash
sudo tail -f /var/log/ufw.log
```

Logs show blocked connections, allowed connections, and rule matches.

### Disable and reset UFW

Disable temporarily:

```bash
sudo ufw disable
```

Re-enable:

```bash
sudo ufw enable
```

Reset to factory defaults (deletes all rules):

```bash
sudo ufw reset
```

## Firewalld (CentOS/RHEL/Fedora)

### Install Firewalld

Firewalld comes pre-installed on RHEL/CentOS. If missing:

```bash
sudo dnf install firewalld -y  # RHEL 8+, Fedora
sudo yum install firewalld -y  # CentOS 7
```

Start and enable:

```bash
sudo systemctl start firewalld
sudo systemctl enable firewalld
```

Check status:

```bash
sudo firewall-cmd --state
```

Should return "running".

### Understand zones

Firewalld uses zones to define trust levels. Default zone is "public".

List zones:

```bash
sudo firewall-cmd --get-zones
```

Common zones:
- **drop**: Drop all incoming, no reply
- **block**: Reject all incoming with icmp-host-prohibited
- **public**: Default, low trust (for internet-facing interfaces)
- **external**: For masquerading/NAT
- **dmz**: Isolated servers
- **work**: Medium trust
- **home**: Higher trust
- **trusted**: Full access, all traffic allowed

Check active zones:

```bash
sudo firewall-cmd --get-active-zones
```

Check default zone:

```bash
sudo firewall-cmd --get-default-zone
```

Set default zone:

```bash
sudo firewall-cmd --set-default-zone=public
```

### View current rules

List all rules in default zone:

```bash
sudo firewall-cmd --list-all
```

List specific zone:

```bash
sudo firewall-cmd --zone=public --list-all
```

### Allow services

Allow HTTP:

```bash
sudo firewall-cmd --zone=public --add-service=http
```

Allow HTTPS:

```bash
sudo firewall-cmd --zone=public --add-service=https
```

Common services: ssh, http, https, mysql, postgresql, smtp, dns, ftp.

List available services:

```bash
sudo firewall-cmd --get-services
```

### Make rules permanent

By default, Firewalld rules are temporary (lost on restart). Add `--permanent`:

```bash
sudo firewall-cmd --permanent --zone=public --add-service=http
```

Reload to apply permanent rules:

```bash
sudo firewall-cmd --reload
```

Or add to runtime and save:

```bash
sudo firewall-cmd --zone=public --add-service=http
sudo firewall-cmd --runtime-to-permanent
```

### Allow ports

Allow specific port:

```bash
sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
sudo firewall-cmd --reload
```

Allow port range:

```bash
sudo firewall-cmd --zone=public --add-port=5000-5010/tcp --permanent
sudo firewall-cmd --reload
```

Allow UDP:

```bash
sudo firewall-cmd --zone=public --add-port=53/udp --permanent
sudo firewall-cmd --reload
```

### Remove services and ports

```bash
sudo firewall-cmd --zone=public --remove-service=http --permanent
sudo firewall-cmd --zone=public --remove-port=8080/tcp --permanent
sudo firewall-cmd --reload
```

### Rich rules (advanced filtering)

Allow SSH only from specific IP:

```bash
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="203.0.113.50" port protocol="tcp" port="22" accept'
sudo firewall-cmd --reload
```

Block specific IP:

```bash
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="198.51.100.50" reject'
sudo firewall-cmd --reload
```

Allow port range from subnet:

```bash
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="10.0.0.0/24" port protocol="tcp" port="3000-3999" accept'
sudo firewall-cmd --reload
```

Rate limit SSH (max 5 connections per minute):

```bash
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule service name="ssh" limit value="5/m" accept'
sudo firewall-cmd --reload
```

List rich rules:

```bash
sudo firewall-cmd --zone=public --list-rich-rules
```

Remove rich rule:

```bash
sudo firewall-cmd --permanent --zone=public --remove-rich-rule='rule family="ipv4" source address="203.0.113.50" port protocol="tcp" port="22" accept'
sudo firewall-cmd --reload
```

### Assign interfaces to zones

Check which zone an interface is in:

```bash
sudo firewall-cmd --get-zone-of-interface=eth0
```

Change interface zone:

```bash
sudo firewall-cmd --zone=trusted --change-interface=eth1 --permanent
sudo firewall-cmd --reload
```

Example: eth0 (internet) in public zone, eth1 (internal network) in trusted zone.

### Port forwarding

Forward external port 80 to internal port 8080:

```bash
sudo firewall-cmd --zone=public --add-forward-port=port=80:proto=tcp:toport=8080 --permanent
sudo firewall-cmd --reload
```

Forward to different IP:

```bash
sudo firewall-cmd --zone=public --add-forward-port=port=80:proto=tcp:toaddr=10.0.0.10:toport=80 --permanent
sudo firewall-cmd --reload
```

Enable masquerading first for forwarding to different IP:

```bash
sudo firewall-cmd --zone=public --add-masquerade --permanent
sudo firewall-cmd --reload
```

### Custom services

Create custom service definition:

```bash
sudo firewall-cmd --permanent --new-service=myapp
```

Configure service:

```bash
sudo firewall-cmd --permanent --service=myapp --set-description="My Custom Application"
sudo firewall-cmd --permanent --service=myapp --set-short="MyApp"
sudo firewall-cmd --permanent --service=myapp --add-port=8080/tcp
sudo firewall-cmd --permanent --service=myapp --add-port=8443/tcp
sudo firewall-cmd --reload
```

Allow custom service:

```bash
sudo firewall-cmd --zone=public --add-service=myapp --permanent
sudo firewall-cmd --reload
```

### Firewalld logging

Enable logging for denied packets:

```bash
sudo firewall-cmd --set-log-denied=all
```

Options: all, unicast, broadcast, multicast, off.

View logs in journalctl:

```bash
sudo journalctl -f -u firewalld
```

Or check kernel logs:

```bash
sudo dmesg | grep -i REJECT
```

### Panic mode (emergency)

Block all network traffic:

```bash
sudo firewall-cmd --panic-on
```

This drops ALL traffic. Use only in emergencies (active attack, testing).

Disable panic mode:

```bash
sudo firewall-cmd --panic-off
```

Check panic status:

```bash
sudo firewall-cmd --query-panic
```

## Common firewall scenarios

### Web server (HTTP/HTTPS)

UFW:
```bash
sudo ufw allow 'Nginx Full'
# Or
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

Firewalld:
```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### Database server (restrict to app server)

UFW:
```bash
sudo ufw allow from 10.0.0.5 to any port 3306  # MySQL
sudo ufw allow from 10.0.0.5 to any port 5432  # PostgreSQL
```

Firewalld:
```bash
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="10.0.0.5" port protocol="tcp" port="3306" accept'
sudo firewall-cmd --reload
```

### SSH from specific IP only

UFW:
```bash
sudo ufw delete allow 22/tcp  # Remove general SSH rule
sudo ufw allow from 203.0.113.50 to any port 22
```

Firewalld:
```bash
sudo firewall-cmd --permanent --zone=public --remove-service=ssh
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="203.0.113.50" service name="ssh" accept'
sudo firewall-cmd --reload
```

### Block country IP ranges

Get IP ranges (example: block IP from specific country):

```bash
# Using ipset for large lists
sudo ipset create blocklist hash:net
sudo ipset add blocklist 198.51.100.0/24
sudo ipset add blocklist 203.0.113.0/24
```

UFW doesn't support ipset directly. Use iptables:

```bash
sudo iptables -I INPUT -m set --match-set blocklist src -j DROP
```

Firewalld with ipset:

```bash
sudo firewall-cmd --permanent --new-ipset=blocklist --type=hash:net
sudo firewall-cmd --permanent --ipset=blocklist --add-entry=198.51.100.0/24
sudo firewall-cmd --permanent --zone=public --add-rich-rule='rule source ipset="blocklist" drop'
sudo firewall-cmd --reload
```

## Testing your firewall

Check if ports are open from external machine:

```bash
# From another machine
nmap server-ip
```

Or use telnet:

```bash
telnet server-ip 80  # Should connect if HTTP is allowed
telnet server-ip 3306  # Should fail if MySQL is blocked
```

Online tools:
- https://www.yougetsignal.com/tools/open-ports/
- https://mxtoolbox.com/PortScan.aspx

Test from server itself (won't work, tests local not external):

```bash
# This tests local firewall, not external access
curl localhost:80  # Tests if service runs, not firewall
```

Test specific IPs:

```bash
# Allow from specific IP, test from that IP
ssh user@server-ip  # Should work from allowed IP
# Try from different IP, should fail
```

## Backup and restore firewall rules

UFW backup:

```bash
# Backup rules
sudo cp /etc/ufw/user.rules /backup/ufw-user.rules
sudo cp /etc/ufw/user6.rules /backup/ufw-user6.rules

# Restore
sudo cp /backup/ufw-user.rules /etc/ufw/user.rules
sudo cp /backup/ufw-user6.rules /etc/ufw/user6.rules
sudo ufw reload
```

Firewalld backup:

```bash
# Backup entire config
sudo tar -czf firewall-backup.tar.gz /etc/firewalld/

# Restore
sudo tar -xzf firewall-backup.tar.gz -C /
sudo firewall-cmd --reload
```

## Troubleshooting

**Can't connect after enabling firewall:**
- Check you allowed the service: `sudo ufw status` or `sudo firewall-cmd --list-all`
- Verify service is running: `sudo systemctl status nginx`
- Check service binds to correct interface: `sudo netstat -tulpn | grep :80`

**Rule not working:**
- UFW: Rules are immediately active after adding
- Firewalld: Did you forget `--permanent`? Add rule again with `--permanent` and `--reload`
- Check rule order: Earlier rules take precedence

**Locked out of SSH:**
- Use hosting provider console/VNC to access server
- Check firewall allowed SSH: `sudo ufw allow ssh` or `sudo firewall-cmd --add-service=ssh`
- If SSH port changed, allow correct port

**Service allowed but still can't connect:**
- Check if service is running: `sudo systemctl status servicename`
- Verify service binds to 0.0.0.0 not 127.0.0.1: `sudo netstat -tulpn`
- Check application-level firewall settings
- Look for SELinux blocking (RHEL/CentOS): `sudo ausearch -m avc -ts recent`

## Security tips

Use default deny policy. Only allow what's needed.

Allow SSH only from known IPs if possible. Public SSH gets hammered by bots.

Block unused ports. If you're not running a service, block its port explicitly.

Enable logging to monitor blocked connections. Patterns show attack attempts.

Update firewall rules when deploying new services. Don't leave ports open "temporarily".

Test rules in staging before production. Broken rules can cause outages.

Document your rules. Comment why each rule exists.

Regular audit: Review rules quarterly. Remove unused rules.

Combine with fail2ban for brute-force protection on allowed services.

## Common mistakes to avoid

Don't enable firewall before allowing SSH on remote servers. You'll lock yourself out.

Don't forget `--permanent` flag with firewalld. Temporary rules vanish on restart.

Don't allow services you don't use. Default profiles might open ports you don't need.

Don't rely on firewall alone. Defense in depth - use firewalls, service configuration, regular updates, monitoring.

Don't block ICMP entirely. Breaks path MTU discovery. Allow essential ICMP types.

Don't forget about IPv6. Configure rules for both IPv4 and IPv6.

## Wrapping up

Firewalls protect Linux servers from unwanted access. UFW works great on Ubuntu/Debian with simple allow/deny commands. Firewalld gives you more control on RHEL/CentOS with zones and rich rules.

Start with default deny incoming, allow outgoing. Only allow required services. Restrict database ports to application server IPs. Use rate limiting for public services like SSH. Test rules before deploying to production.

Keep rules documented and backed up. Review regularly and remove unused rules. Use firewall together with SSH hardening, fail2ban, and regular updates.

For more Linux security, check out the SSH hardening guide and systemd service management article.
