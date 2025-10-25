---
title: 'How to Secure SSH Server on Ubuntu - Complete Hardening Guide'
date: 2025-10-25T09:00:00+07:00
draft: false
url: /2025/10/how-to-secure-ssh-server-ubuntu-hardening-guide.html
tags:
- Linux
- Ubuntu
- SSH
- Security
- Server
- Hardening
description: 'Step-by-step guide to secure your SSH server on Ubuntu and prevent unauthorized access. Learn how to implement SSH key authentication, disable password login, configure fail2ban to block brute-force attacks, set up two-factor authentication (2FA), and apply firewall rules to protect your Linux server from hackers.'
keywords: ['ssh security','ubuntu ssh hardening','ssh key authentication','disable root login ssh','fail2ban ssh','ssh two factor authentication','ssh firewall','brute force protection','openssh security','linux server security']
featured: false
faq:
  - question: "Why should I disable password authentication and use SSH keys instead?"
    answer: "Password authentication is vulnerable to brute-force attacks where attackers try thousands of password combinations. SSH keys use cryptographic key pairs (public and private keys) that are virtually impossible to brute-force. A 2048-bit RSA key has 2^2048 possible combinations compared to typical passwords with maybe 10^12 combinations. Keys can't be guessed, stolen from password dumps, or phished. Even if someone steals your public key, they can't use it to log in - they need your private key which never leaves your machine. Use keys for security, passwords are outdated."
  - question: "What happens if I lock myself out while changing SSH settings?"
    answer: "Always keep a second SSH session open when changing sshd_config. If your changes break SSH, you still have the active connection to fix it. Test changes with sudo sshd -t before restarting. If you do get locked out, access your server through your hosting provider's console/VNC (DigitalOcean Droplet Console, AWS EC2 Instance Connect, etc.). Boot into recovery mode if you have physical access. As a last resort, mount the disk on another server, fix /etc/ssh/sshd_config, and remount. Prevention is key - always test before disconnecting."
  - question: "Should I change the default SSH port from 22 to something else?"
    answer: "Changing ports is 'security through obscurity' - it doesn't stop determined attackers but reduces log spam from automated bots scanning port 22. Your logs will be cleaner, and you'll see fewer pointless brute-force attempts. However, non-standard ports can be discovered with port scans. It's a mild security improvement that works best combined with real security measures like key authentication, fail2ban, and firewalls. If you change ports, use something above 1024 (non-privileged) and update your firewall rules. Document it or you'll forget your own port."
  - question: "How does fail2ban protect against brute-force attacks?"
    answer: "Fail2ban monitors log files like /var/log/auth.log for failed login attempts. When it detects multiple failures from the same IP (default: 5 failures in 10 minutes), it adds a firewall rule to block that IP for a set time (default: 10 minutes). This stops automated brute-force scripts that try thousands of passwords. Attackers get blocked after a few tries instead of making unlimited attempts. Fail2ban doesn't prevent attacks but makes them impractical by dramatically slowing down the rate attackers can try credentials. Combined with key-based auth, it's nearly unbeatable."
  - question: "What is two-factor authentication for SSH and how do I implement it?"
    answer: "2FA adds a second authentication step beyond your SSH key or password. After entering your key passphrase, you must provide a time-based code from Google Authenticator or similar app. Implement with Google Authenticator PAM module: install libpam-google-authenticator, run google-authenticator to generate QR code, scan it with your phone app, edit /etc/pam.d/sshd to add auth required pam_google_authenticator.so, and enable ChallengeResponseAuthentication in sshd_config. Now logins require your private key AND the 6-digit code from your phone. Even if your key is stolen, attackers can't log in without your phone."
  - question: "Can I allow specific users to login with passwords while enforcing keys for others?"
    answer: "Yes, use Match blocks in sshd_config. For example: at the end of the file add 'Match User admin' then 'PasswordAuthentication yes' to allow passwords only for the admin user. Or use 'Match Group developers' to apply settings to a group. Place Match blocks at the end of sshd_config after global settings. You can mix key-only users (PasswordAuthentication no globally) with password-allowed users (Match overrides). This lets you have key-only security for most users while keeping password access for specific accounts or emergency access. Test thoroughly as Match blocks can be tricky."
---

SSH is the main way you access Linux servers remotely. If SSH gets compromised, attackers own your entire server. Default SSH setups are insecure - they allow password logins, permit root access, and get hammered by brute-force bots trying millions of password combinations.

This guide hardens your SSH server on Ubuntu. You'll disable passwords and use SSH keys, block root login, change the default port, set up fail2ban to stop brute-force attacks, add two-factor authentication, configure firewall rules, and monitor for suspicious activity.

<!--readmore-->

## Why SSH security matters

SSH runs on port 22 by default. Bots constantly scan the internet for port 22, trying username/password combinations. Check your auth logs and you'll see thousands of failed attempts from IPs worldwide.

One weak password means full server access. Attackers install cryptominers, steal data, use your server for DDoS attacks, or hold it for ransom.

Securing SSH stops 99% of automated attacks and makes targeted attacks much harder.

## Check your current SSH security status

Before making changes, see what you're dealing with:

```bash
# Check failed login attempts
sudo grep "Failed password" /var/log/auth.log | tail -20

# See which IPs are trying to brute-force you
sudo grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -10

# Check current SSH config
sudo sshd -T | grep -E "permitrootlogin|passwordauthentication|port"
```

You'll probably see hundreds or thousands of failed attempts. That's normal for any server on the internet.

## Generate SSH key pair (if you don't have one)

On your local machine (not the server), generate keys:

```bash
# Generate Ed25519 key (recommended - more secure, shorter)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Or RSA key for compatibility with older systems
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

Save to default location (`~/.ssh/id_ed25519` or `~/.ssh/id_rsa`). Set a strong passphrase.

This creates two files:
- Private key: `id_ed25519` (keep this secret, never share)
- Public key: `id_ed25519.pub` (safe to share)

## Copy SSH key to server

```bash
# Copy key to server (replace user and IP)
ssh-copy-id user@server-ip

# Or manually if ssh-copy-id isn't available
cat ~/.ssh/id_ed25519.pub | ssh user@server-ip "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

Test the key works:

```bash
ssh user@server-ip
```

You should log in without entering your server password (you'll need your key passphrase if you set one).

## Disable password authentication

Once keys work, disable passwords. Edit SSH config:

```bash
sudo nano /etc/ssh/sshd_config
```

Find and change these lines (uncomment if needed by removing `#`):

```
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
```

Test config before restarting:

```bash
sudo sshd -t
```

No output means success. If there are errors, fix them before continuing.

Restart SSH (keep current session open!):

```bash
sudo systemctl restart sshd
```

Open a NEW terminal and test login:

```bash
ssh user@server-ip
```

If it works, close the new terminal. If it fails, fix it in your still-open original session.

## Disable root login

Never allow direct root SSH access. Attackers always try root login first.

In `/etc/ssh/sshd_config`:

```
PermitRootLogin no
```

Instead, log in as a regular user and use `sudo`:

```bash
ssh user@server-ip
sudo su -  # Switch to root after login if needed
```

Test and restart:

```bash
sudo sshd -t
sudo systemctl restart sshd
```

## Change SSH port (optional but recommended)

Changing from port 22 reduces bot spam. Pick a port above 1024:

```
Port 2222
```

Update firewall before restarting SSH:

```bash
# Allow new SSH port
sudo ufw allow 2222/tcp

# Check it's added
sudo ufw status
```

Restart SSH:

```bash
sudo systemctl restart sshd
```

Connect with new port:

```bash
ssh -p 2222 user@server-ip
```

After confirming it works, remove old port 22 from firewall:

```bash
sudo ufw delete allow 22/tcp
```

Remember your port or you'll lock yourself out. Add to `~/.ssh/config` on your local machine:

```
Host myserver
    HostName server-ip
    Port 2222
    User username
```

Now just use `ssh myserver`.

## Install and configure fail2ban

Fail2ban blocks IPs after repeated failed login attempts.

Install:

```bash
sudo apt update
sudo apt install fail2ban -y
```

Create local config (don't edit `/etc/fail2ban/jail.conf` directly):

```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local
```

Find `[sshd]` section and configure:

```ini
[sshd]
enabled = true
port = 2222  # Change to your SSH port
filter = sshd
logpath = /var/log/auth.log
maxretry = 3  # Ban after 3 failed attempts
findtime = 600  # Within 10 minutes
bantime = 3600  # Ban for 1 hour (3600 seconds)
```

For permanent bans after repeated offenses:

```ini
[sshd]
enabled = true
port = 2222
maxretry = 3
findtime = 600
bantime = 3600
# Ban forever after 3 bans within 1 week
bantime.increment = true
bantime.maxtime = 5w
bantime.factor = 24
```

Start fail2ban:

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

Check status:

```bash
sudo fail2ban-client status sshd
```

View banned IPs:

```bash
sudo fail2ban-client get sshd banned
```

Manually ban/unban:

```bash
# Ban an IP
sudo fail2ban-client set sshd banip 1.2.3.4

# Unban an IP
sudo fail2ban-client set sshd unbanip 1.2.3.4
```

## Set up two-factor authentication

Add 2FA for extra security. You'll need your SSH key AND a code from your phone.

Install Google Authenticator:

```bash
sudo apt install libpam-google-authenticator -y
```

Run setup:

```bash
google-authenticator
```

Answer the prompts:
- Time-based tokens? **Yes**
- Update `.google_authenticator` file? **Yes**
- Disallow multiple uses? **Yes**
- Increase time window? **No** (unless your server clock is off)
- Enable rate-limiting? **Yes**

Scan the QR code with Google Authenticator app on your phone. Save the emergency scratch codes somewhere safe.

Edit PAM config:

```bash
sudo nano /etc/pam.d/sshd
```

Add at the top:

```
auth required pam_google_authenticator.so
```

Comment out this line (add `#` at start):

```
# @include common-auth
```

Edit SSH config:

```bash
sudo nano /etc/ssh/sshd_config
```

Enable challenge-response:

```
ChallengeResponseAuthentication yes
AuthenticationMethods publickey,keyboard-interactive
```

Restart SSH:

```bash
sudo systemctl restart sshd
```

Test in a new terminal. You'll need:
1. Your SSH private key
2. The 6-digit code from Google Authenticator

## Configure firewall rules

Use UFW to limit SSH access.

Enable UFW if not already:

```bash
sudo ufw status
```

If inactive:

```bash
# Allow SSH first (your port)
sudo ufw allow 2222/tcp

# Enable firewall
sudo ufw enable
```

Limit SSH connections (allows max 6 connections per IP in 30 seconds):

```bash
sudo ufw limit 2222/tcp
```

Allow SSH only from specific IPs (if you have a static IP):

```bash
# Delete the general rule first
sudo ufw delete allow 2222/tcp

# Allow only your IP
sudo ufw allow from YOUR_IP_ADDRESS to any port 2222 proto tcp
```

Check rules:

```bash
sudo ufw status numbered
```

## Restrict SSH to specific users or groups

Only allow certain users to SSH:

```bash
sudo nano /etc/ssh/sshd_config
```

Add:

```
AllowUsers user1 user2
```

Or allow by group:

```
AllowGroups sshusers
```

Create the group and add users:

```bash
sudo groupadd sshusers
sudo usermod -aG sshusers username
```

Restart SSH:

```bash
sudo systemctl restart sshd
```

## Set SSH session timeouts

Disconnect idle sessions automatically:

In `/etc/ssh/sshd_config`:

```
ClientAliveInterval 300  # Send keepalive every 5 minutes
ClientAliveCountMax 2    # Disconnect after 2 failed keepalives (10 min total)
```

This disconnects sessions idle for 10 minutes.

## Disable empty passwords

Make sure no accounts have empty passwords:

```
PermitEmptyPasswords no
```

Check for empty passwords:

```bash
sudo awk -F: '($2 == "") {print $1}' /etc/shadow
```

If any users show up, set passwords:

```bash
sudo passwd username
```

## Monitor SSH logs

Watch live authentication attempts:

```bash
sudo tail -f /var/log/auth.log
```

See successful logins:

```bash
sudo grep "Accepted" /var/log/auth.log | tail -20
```

Failed logins:

```bash
sudo grep "Failed" /var/log/auth.log | tail -20
```

See which users logged in:

```bash
last -20
```

Currently logged in users:

```bash
w
```

Set up email alerts for SSH logins (install mailutils first):

```bash
sudo apt install mailutils -y
```

Add to `/etc/ssh/sshd_config`:

```
ForceCommand echo "SSH Login: $(whoami) from $(echo $SSH_CLIENT | awk '{print $1}') at $(date)" | mail -s "SSH Login Alert" your@email.com; bash
```

Or use a script in `/etc/profile.d/ssh-login-alert.sh`:

```bash
#!/bin/bash
if [ -n "$SSH_CLIENT" ]; then
    IP=$(echo $SSH_CLIENT | awk '{print $1}')
    echo "SSH login to $(hostname) as $(whoami) from $IP at $(date)" | mail -s "SSH Login: $(hostname)" your@email.com
fi
```

## Disable unnecessary SSH features

Turn off features you don't need:

```
X11Forwarding no  # Disable GUI forwarding
AllowTcpForwarding no  # Disable port forwarding (breaks SSH tunnels)
PermitTunnel no  # Disable tun device forwarding
```

Only disable `AllowTcpForwarding` if you're sure you don't need SSH tunnels.

## Use SSH key passphrases

Always protect your private key with a passphrase. If someone steals your key file, the passphrase protects it.

Add passphrase to existing key:

```bash
ssh-keygen -p -f ~/.ssh/id_ed25519
```

Use ssh-agent so you only enter the passphrase once per session:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Add to `~/.bashrc` or `~/.zshrc`:

```bash
if [ -z "$SSH_AUTH_SOCK" ]; then
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
fi
```

## Test your SSH security

Try logging in without your key (should fail):

```bash
ssh -o PubkeyAuthentication=no user@server-ip
```

Try as root (should fail):

```bash
ssh root@server-ip
```

Intentionally fail logins 3 times and check fail2ban bans your IP:

```bash
# On server
sudo fail2ban-client status sshd
```

Scan your SSH port with nmap (from another machine):

```bash
nmap -p 2222 server-ip
```

Should show port open with SSH service.

## Backup and recovery

Backup your SSH config:

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
```

If you mess up, restore it:

```bash
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
sudo systemctl restart sshd
```

Keep a copy of your private key in a secure location (encrypted USB drive, password manager).

## Verify your security settings

Check your SSH config to make sure everything is set correctly:

```bash
sudo sshd -T | grep -E "passwordauthentication|permitrootlogin|port|pubkeyauthentication"
```

You should see:

```
passwordauthentication no
permitrootlogin no
port 2222
pubkeyauthentication yes
```

Check fail2ban is running:

```bash
sudo systemctl status fail2ban
sudo fail2ban-client status sshd
```

Verify firewall rules:

```bash
sudo ufw status
```

Your custom SSH port should be allowed, old port 22 should be removed.

## Common mistakes to avoid

Don't disable PasswordAuthentication before testing key authentication. Test keys work first.

Don't close your current SSH session before testing new settings. Keep it open until you confirm login works in a second session.

Don't forget to update firewall rules when changing SSH port. You'll lock yourself out.

Don't lose your private key or forget your passphrase. You'll be locked out permanently.

Don't set fail2ban maxretry too low (like 1 or 2). You might ban yourself with typos.

Don't skip 2FA for root or admin users. They're the highest value targets.

## Wrapping up

SSH security needs multiple layers. Disable passwords and use keys. Block root login. Add fail2ban to stop brute-force attacks. Configure firewall rules to limit access. Add 2FA for critical servers.

Monitor logs for suspicious activity. Test changes carefully before disconnecting. Keep backups of configs and keys.

A hardened SSH server stops automated attacks and makes targeted attacks harder. Use this together with firewall configuration and other security measures.

For more Linux security, check out the firewall configuration guide and systemd service management article.
