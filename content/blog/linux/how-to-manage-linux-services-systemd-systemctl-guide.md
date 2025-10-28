---
title: 'How to Manage Linux Services with Systemd - Complete SystemCTL Guide'
date: 2025-10-26T09:00:00+07:00
draft: false
url: /2025/10/how-to-manage-linux-services-systemd-systemctl-guide.html
tags:
- Linux
- Systemd
- SystemCTL
- Server Management
- DevOps
- Services
description: 'Master Linux service management with systemd and systemctl commands. Learn how to start, stop, restart, and enable services at boot, create custom systemd service units for your applications, replace cron with systemd timers, troubleshoot failed services, and analyze logs with journalctl for efficient server administration.'
keywords: ['systemd tutorial','systemctl commands','linux service management','create systemd service','systemd timer units','journalctl logs','systemctl enable disable','systemd troubleshooting','linux server administration','systemctl status']
featured: false
faq:
  - question: "What is systemd and why did Linux distributions switch to it?"
    answer: "Systemd is the init system and service manager that replaced older systems like SysVinit and Upstart. It starts as PID 1 when your system boots and manages all other processes. Linux distros switched because systemd boots faster through parallel service startup (old systems started services sequentially), has better dependency management, includes journal logging built-in, provides timer units as a cron alternative, and uses socket activation to start services on-demand. It handles service crashes better with automatic restart policies. Despite controversy over complexity and scope creep, systemd is now the standard on Ubuntu, Debian, RHEL, CentOS, Fedora, Arch, and most major distributions."
  - question: "What's the difference between systemctl start, enable, and restart?"
    answer: "Start launches a service immediately but it won't run after reboot. Enable creates symlinks so the service starts automatically at boot, but doesn't start it right now. Restart stops then starts a service, reloading its configuration - use this after editing config files. Most times you want both: systemctl enable --now nginx starts immediately AND enables at boot. Reload sends a signal to refresh config without stopping the service, but not all services support it. Stop halts the service immediately. Disable removes boot startup but doesn't stop the currently running service. Use status to check if a service is running and enabled."
  - question: "How do I create a custom systemd service for my application?"
    answer: "Create a .service file in /etc/systemd/system/ with this structure: [Unit] section describes the service and dependencies, [Service] section defines how to run it (ExecStart command, working directory, user, restart policy), and [Install] section sets when it starts (usually WantedBy=multi-user.target). For a Node.js app: create /etc/systemd/system/myapp.service with ExecStart=/usr/bin/node /var/www/myapp/server.js, set WorkingDirectory, User, and Restart=always. Run systemctl daemon-reload to load it, then systemctl enable --now myapp. Check logs with journalctl -u myapp. This beats cron or screen sessions - systemd handles crashes, logging, and startup automatically."
  - question: "What are systemd timer units and should I use them instead of cron?"
    answer: "Timer units are systemd's alternative to cron jobs. They trigger service units on schedules or events. Advantages over cron: better logging through journalctl, can run missed jobs if system was off (Persistent=true), more precise timing options, easier to manage with systemctl, and they integrate with service dependencies. Create a .timer file and matching .service file. The timer activates the service. For example, backup.timer triggers backup.service every day at 2 AM. Use OnCalendar for cron-like schedules or OnBootSec for 'X minutes after boot'. Timers are better for system maintenance, but cron is simpler for quick user tasks. For production services, prefer timers."
  - question: "How do I troubleshoot a failed systemd service?"
    answer: "Follow this debugging sequence: First, systemctl status servicename shows current state and recent logs. Look for 'Active: failed' and the error message. Second, journalctl -u servicename -n 50 shows the last 50 log lines - check for startup errors. Third, journalctl -u servicename --since today shows all logs from today. Fourth, systemctl cat servicename displays the unit file - verify ExecStart path is correct, working directory exists, and user has permissions. Fifth, try running the ExecStart command manually as the specified user to see actual errors. Common issues: wrong file paths, permission denied, missing dependencies, port already in use, or syntax errors in the service file. Fix the problem, run systemctl daemon-reload, then restart."
  - question: "Can I limit resources like CPU and memory for a systemd service?"
    answer: "Yes, systemd has built-in resource controls using cgroups. Add these to the [Service] section: CPUQuota=50% limits to 50% of one CPU core, MemoryLimit=1G caps RAM at 1GB (service killed if exceeded), MemoryHigh=800M triggers swapping at 800MB, TasksMax=100 limits number of processes/threads. For I/O: IOReadBandwidthMax=/dev/sda 10M limits disk reads. Example for a web app that shouldn't hog resources: CPUQuota=25%, MemoryHigh=512M, MemoryMax=768M. After editing the unit file, run systemctl daemon-reload and systemctl restart. Check current usage with systemd-cgtop. This prevents runaway services from crashing your server. Way better than nice/renice or manual ulimit settings."
---

Managing services is fundamental to Linux server administration. Every web server, database, application, or background process runs as a service that needs to start, stop, restart, and recover from failures.

Systemd replaced older init systems and is now the standard on virtually all major Linux distributions. If you work with Linux servers, you need to know systemd and systemctl inside out.

This guide covers everything from basic service management to creating custom services, using timer units instead of cron, troubleshooting failures, and analyzing logs with journalctl.

<!--readmore-->

## What is systemd and why it matters

Systemd is the init system that starts as the first process (PID 1) when Linux boots. It manages all other processes on your system.

Before systemd, most distributions used SysVinit, which started services sequentially using shell scripts. Systemd starts services in parallel, handling dependencies automatically. Your system boots faster and services are more reliable.

Systemd isn't just an init system. It includes:
- Service management (systemctl)
- Log management (journalctl)
- Timer units (cron replacement)
- Socket activation
- Resource limiting (cgroups)
- Network management (systemd-networkd)
- Login management (systemd-logind)

Check your systemd version:

```bash
systemd --version
```

You'll see something like `systemd 249 (249.11-ubuntu3)`. Different versions support different features, but core functionality is consistent.

## Basic systemctl commands

Systemctl is your main tool for managing services. Here are the essential commands you'll use constantly:

```bash
# Start a service (runs immediately, won't persist after reboot)
sudo systemctl start nginx

# Stop a service
sudo systemctl stop nginx

# Restart a service (stop then start)
sudo systemctl restart nginx

# Reload service configuration without stopping
sudo systemctl reload nginx

# Enable service to start at boot
sudo systemctl enable nginx

# Disable service from starting at boot
sudo systemctl disable nginx

# Enable and start in one command
sudo systemctl enable --now nginx

# Disable and stop in one command
sudo systemctl disable --now nginx

# Check if service is running
systemctl status nginx

# Check if service is enabled at boot
systemctl is-enabled nginx

# Check if service is currently active
systemctl is-active nginx
```

The `--now` flag is useful because you often want to both enable at boot AND start immediately.

## Understanding service status

The status command shows detailed service information:

```bash
systemctl status nginx
```

Output looks like:

```
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2025-10-23 09:15:32 UTC; 2 days ago
       Docs: man:nginx(8)
   Main PID: 1234 (nginx)
      Tasks: 5 (limit: 4915)
     Memory: 12.3M
        CPU: 1.234s
     CGroup: /system.slice/nginx.service
             ├─1234 nginx: master process /usr/sbin/nginx -g daemon off;
             └─1235 nginx: worker process

Oct 23 09:15:32 server systemd[1]: Starting nginx.service...
Oct 23 09:15:32 server systemd[1]: Started nginx.service.
```

Key information:
- **Loaded**: Where unit file is located and if it's enabled
- **Active**: Current state - active (running), inactive (dead), or failed
- **Main PID**: Process ID of the main service process
- **Tasks**: Number of processes/threads
- **Memory/CPU**: Resource usage
- **CGroup**: Process hierarchy
- **Recent logs**: Last few log entries

Active states you'll see:
- `active (running)`: Service is running
- `active (exited)`: Service completed successfully (one-shot services)
- `active (waiting)`: Service is waiting for an event
- `inactive (dead)`: Service is stopped
- `failed`: Service crashed or failed to start
- `activating`: Service is starting up
- `deactivating`: Service is shutting down

## List all services

See all services on your system:

```bash
# List all loaded services
systemctl list-units --type=service

# List all services including inactive ones
systemctl list-units --type=service --all

# Show only running services
systemctl list-units --type=service --state=running

# Show failed services
systemctl list-units --type=service --state=failed

# List enabled services
systemctl list-unit-files --type=service --state=enabled

# List disabled services
systemctl list-unit-files --type=service --state=disabled
```

Filter output with grep:

```bash
# Find all running web servers
systemctl list-units --type=service --state=running | grep -E 'nginx|apache|httpd'

# Find database services
systemctl list-units --type=service | grep -E 'mysql|postgres|mongo|redis'
```

## View and analyze service logs

Systemd includes journald for centralized logging. Use journalctl to view logs:

```bash
# View logs for a specific service
journalctl -u nginx

# View only today's logs
journalctl -u nginx --since today

# Last 50 lines
journalctl -u nginx -n 50

# Follow logs in real-time (like tail -f)
journalctl -u nginx -f

# Logs from the last hour
journalctl -u nginx --since "1 hour ago"

# Logs between specific times
journalctl -u nginx --since "2025-10-26 09:00:00" --until "2025-10-26 10:00:00"

# Show logs with priority level (error and above)
journalctl -u nginx -p err

# Show kernel messages
journalctl -k

# Show logs from current boot
journalctl -b

# Show logs from previous boot
journalctl -b -1

# Show logs in reverse (newest first)
journalctl -u nginx -r

# Export logs to file
journalctl -u nginx > nginx-logs.txt
```

Priority levels from highest to lowest:
- 0: emerg (system unusable)
- 1: alert (action must be taken)
- 2: crit (critical conditions)
- 3: err (error conditions)
- 4: warning
- 5: notice
- 6: info
- 7: debug

Check journal disk usage:

```bash
journalctl --disk-usage
```

Clean old logs:

```bash
# Keep only last 2 days
sudo journalctl --vacuum-time=2d

# Keep only 500MB
sudo journalctl --vacuum-size=500M

# Keep only last 1000 entries per journal
sudo journalctl --vacuum-files=10
```

## Create a custom systemd service

Let's create a service for a Node.js application. This same pattern works for Python, Go, or any application.

First, create your app. Example Node.js server:

```bash
sudo mkdir -p /var/www/myapp
sudo nano /var/www/myapp/server.js
```

Simple server:

```javascript
const http = require('http');

const server = http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('Hello from systemd service!\n');
});

server.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

Create a systemd service file:

```bash
sudo nano /etc/systemd/system/myapp.service
```

Basic service file:

```ini
[Unit]
Description=My Node.js Application
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/myapp
ExecStart=/usr/bin/node /var/www/myapp/server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=myapp

[Install]
WantedBy=multi-user.target
```

Explanation:

**[Unit] section:**
- `Description`: Human-readable description
- `After`: Start after network is available
- `Requires`: Hard dependency (service fails if dependency fails)
- `Wants`: Soft dependency (service starts even if dependency fails)

**[Service] section:**
- `Type=simple`: Process doesn't fork (default)
- `Type=forking`: Process forks to background (old daemons)
- `Type=oneshot`: Process exits after completion
- `User`: Run as this user (not root for security)
- `WorkingDirectory`: Current directory for the process
- `ExecStart`: Command to start service
- `ExecStop`: Command to stop (optional, systemd sends SIGTERM by default)
- `Restart=always`: Restart if crashes
- `Restart=on-failure`: Restart only on failure
- `RestartSec`: Wait before restarting
- `StandardOutput=journal`: Send stdout to journal
- `StandardError=journal`: Send stderr to journal

**[Install] section:**
- `WantedBy=multi-user.target`: Enable at normal multi-user boot

Set permissions:

```bash
sudo chown -R www-data:www-data /var/www/myapp
```

Load and start the service:

```bash
# Reload systemd to recognize new service
sudo systemctl daemon-reload

# Start service
sudo systemctl start myapp

# Check status
sudo systemctl status myapp

# Enable at boot
sudo systemctl enable myapp

# View logs
journalctl -u myapp -f
```

Test the service:

```bash
curl http://localhost:3000
```

Should return "Hello from systemd service!".

Test automatic restart by killing the process:

```bash
# Find PID
systemctl status myapp

# Kill it
sudo kill -9 [PID]

# Check status - should restart automatically
systemctl status myapp
```

## Advanced service file options

Add resource limits and security:

```ini
[Unit]
Description=My Node.js Application
After=network.target
Wants=redis.service
After=redis.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/myapp

Environment="NODE_ENV=production"
Environment="PORT=3000"
EnvironmentFile=/etc/myapp/config

ExecStart=/usr/bin/node /var/www/myapp/server.js
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID

Restart=always
RestartSec=10
StartLimitInterval=100
StartLimitBurst=5

# Resource limits
CPUQuota=50%
MemoryLimit=1G
MemoryHigh=800M
TasksMax=100

# Security
PrivateTmp=true
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/www/myapp/uploads

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=myapp

[Install]
WantedBy=multi-user.target
```

New options explained:

**Dependencies:**
- `Wants=redis.service`: Start after Redis if available
- Multiple `After=` lines define order

**Environment:**
- `Environment`: Set environment variables inline
- `EnvironmentFile`: Load variables from file

**Lifecycle:**
- `ExecReload`: Command for reload action
- `ExecStop`: Custom stop command
- `$MAINPID`: Variable containing main process PID

**Restart limits:**
- `StartLimitInterval`: Time window for restart limit
- `StartLimitBurst`: Max restarts in that window

**Resource controls:**
- `CPUQuota=50%`: Limit to 50% of one CPU core
- `MemoryLimit=1G`: Hard limit (kills process if exceeded)
- `MemoryHigh=800M`: Soft limit (triggers swapping)
- `TasksMax=100`: Limit processes/threads

**Security:**
- `PrivateTmp=true`: Service gets private /tmp
- `NoNewPrivileges=true`: Can't gain new privileges
- `ProtectSystem=strict`: Makes most of filesystem read-only
- `ProtectHome=true`: Makes /home inaccessible
- `ReadWritePaths`: Exceptions to read-only filesystem

Create environment file:

```bash
sudo mkdir /etc/myapp
sudo nano /etc/myapp/config
```

Add variables:

```
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://user:pass@localhost/mydb
REDIS_URL=redis://localhost:6379
```

After editing service file:

```bash
sudo systemctl daemon-reload
sudo systemctl restart myapp
```

## Create systemd timer units

Timer units replace cron jobs. They're more reliable, easier to debug, and integrate better with systemd.

Example: Backup script that runs daily at 2 AM.

Create the service that does the work:

```bash
sudo nano /etc/systemd/system/backup.service
```

```ini
[Unit]
Description=Daily backup job
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=backup
ExecStart=/usr/local/bin/backup.sh
StandardOutput=journal
StandardError=journal
```

Create the timer that triggers it:

```bash
sudo nano /etc/systemd/system/backup.timer
```

```ini
[Unit]
Description=Run backup daily at 2 AM
Requires=backup.service

[Timer]
OnCalendar=daily
OnCalendar=*-*-* 02:00:00
Persistent=true
Unit=backup.service

[Install]
WantedBy=timers.target
```

Timer options:

**OnCalendar examples:**
```ini
# Every minute
OnCalendar=*:*:00

# Every 5 minutes
OnCalendar=*:0/5

# Every hour
OnCalendar=hourly
OnCalendar=*:00:00

# Every day at 3:30 AM
OnCalendar=daily
OnCalendar=*-*-* 03:30:00

# Every Monday at 9 AM
OnCalendar=Mon *-*-* 09:00:00

# First day of month at midnight
OnCalendar=*-*-01 00:00:00

# Weekdays at 6 PM
OnCalendar=Mon..Fri *-*-* 18:00:00
```

**Other timer options:**
- `OnBootSec=15min`: Run 15 minutes after boot
- `OnUnitActiveSec=1h`: Run 1 hour after service last ran
- `OnUnitInactiveSec=30min`: Run 30 min after service became inactive
- `Persistent=true`: Run missed jobs after system was off
- `AccuracySec=1min`: Allow up to 1 minute timing variation (saves power)

Enable and start timer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable backup.timer
sudo systemctl start backup.timer
```

Check timer status:

```bash
# See timer status
systemctl status backup.timer

# List all active timers
systemctl list-timers

# List all timers including inactive
systemctl list-timers --all

# Show detailed timer info
systemctl show backup.timer
```

View when timer last ran and next run:

```bash
systemctl list-timers backup.timer
```

Output shows:

```
NEXT                         LEFT        LAST                         PASSED  UNIT           ACTIVATES
Thu 2025-10-26 02:00:00 UTC  4h 23min    Wed 2025-10-25 02:00:00 UTC  19h ago backup.timer   backup.service
```

Test timer manually:

```bash
# Trigger service immediately
sudo systemctl start backup.service

# Check logs
journalctl -u backup.service -n 20
```

## Service dependencies and ordering

Control how services start relative to each other.

Example: Web app requires database and Redis:

```ini
[Unit]
Description=Web Application
After=network.target postgresql.service redis.service
Requires=postgresql.service
Wants=redis.service

[Service]
Type=simple
ExecStart=/usr/bin/myapp

[Install]
WantedBy=multi-user.target
```

Dependency types:

**Requires:**
- Hard dependency
- If postgresql.service fails, webapp fails too
- If you stop postgresql, webapp stops

**Wants:**
- Soft dependency
- Webapp starts even if redis fails
- Stopping redis doesn't stop webapp
- Use this for optional dependencies

**Requisite:**
- Like Requires but checks immediately
- Fails instantly if dependency isn't already running

**BindsTo:**
- Stronger than Requires
- Service stops when dependency stops

**PartOf:**
- Stopping/restarting dependency affects this service
- Used for multi-part services

**Ordering (After/Before):**
- `After=redis.service`: Start after Redis
- `Before=nginx.service`: Start before nginx
- Doesn't create dependency, just ordering

Example multi-tier application:

```ini
# Database (starts first)
[Unit]
Description=PostgreSQL Database
Before=webapp.service

# Redis cache (starts before webapp)
[Unit]
Description=Redis Cache
Before=webapp.service

# Web application (starts after database and Redis)
[Unit]
Description=Web Application
After=postgresql.service redis.service
Requires=postgresql.service
Wants=redis.service
Before=nginx.service

# Nginx (starts last)
[Unit]
Description=Nginx Reverse Proxy
After=webapp.service
Wants=webapp.service
```

This ensures proper startup order: PostgreSQL -> Redis -> Webapp -> Nginx.

## Troubleshoot failed services

When a service fails, follow this debugging process:

**Step 1: Check status**

```bash
systemctl status servicename
```

Look for error messages in the output.

**Step 2: View recent logs**

```bash
journalctl -u servicename -n 50
```

Check the last 50 log entries for errors.

**Step 3: View all logs from latest attempt**

```bash
journalctl -u servicename --since "5 minutes ago"
```

**Step 4: Examine the unit file**

```bash
systemctl cat servicename
```

Verify:
- ExecStart path is correct
- WorkingDirectory exists
- User has permissions
- Dependencies are correct

**Step 5: Test the command manually**

Run the ExecStart command as the specified user:

```bash
# Switch to service user
sudo -u www-data bash

# Run the command
/usr/bin/node /var/www/myapp/server.js
```

See actual error messages.

**Step 6: Check file permissions**

```bash
ls -la /var/www/myapp
```

Service user needs read/execute on files and directories.

**Step 7: Verify dependencies**

```bash
systemctl list-dependencies servicename
```

Check if required services are running.

**Common failure causes:**

**Permission denied:**
```bash
# Fix ownership
sudo chown -R www-data:www-data /var/www/myapp

# Fix permissions
sudo chmod 755 /var/www/myapp
sudo chmod 644 /var/www/myapp/server.js
```

**Port already in use:**
```bash
# Find what's using the port
sudo lsof -i :3000
sudo netstat -tulpn | grep 3000

# Kill the process or change your app's port
```

**Wrong file path:**
```bash
# Verify file exists
ls -la /usr/bin/node
which node

# Update ExecStart with correct path
```

**Missing dependencies:**
```bash
# For Node.js apps
cd /var/www/myapp
npm install

# For Python apps
pip install -r requirements.txt
```

**Service starts then immediately exits:**

Add to service file:

```ini
[Service]
RemainAfterExit=yes
```

Or check why process exits (look at logs).

**Enable debug logging:**

```ini
[Service]
Environment="DEBUG=*"
Environment="LOG_LEVEL=debug"
```

**Analyze core dumps if service crashed:**

```bash
# Enable core dumps
sudo systemctl edit servicename
```

Add:

```ini
[Service]
LimitCORE=infinity
```

After crash:

```bash
coredumpctl list
coredumpctl info
coredumpctl dump > core.dump
```

## Reload systemd and reset failed services

After editing unit files:

```bash
# Reload systemd configuration
sudo systemctl daemon-reload
```

Always run this after creating or editing .service or .timer files.

Reset failed state:

```bash
# Reset one service
sudo systemctl reset-failed servicename

# Reset all failed services
sudo systemctl reset-failed
```

This clears the "failed" state so you can restart the service.

## Override default service settings

Don't edit system unit files directly. Use overrides:

```bash
sudo systemctl edit nginx
```

This creates `/etc/systemd/system/nginx.service.d/override.conf`.

Add your changes:

```ini
[Service]
Restart=always
RestartSec=10
CPUQuota=50%
```

Save and exit. Changes apply automatically.

To edit the full unit file:

```bash
sudo systemctl edit --full nginx
```

This copies the unit file to `/etc/systemd/system/nginx.service` where you can edit it.

View active configuration with overrides applied:

```bash
systemctl cat nginx
```

Remove overrides:

```bash
sudo systemctl revert nginx
```

## Mask and unmask services

Masking prevents a service from starting:

```bash
# Mask service (can't be started manually or automatically)
sudo systemctl mask servicename

# Unmask to allow starting again
sudo systemctl unmask servicename
```

Masked services show as:

```
Loaded: masked (Reason: Unit servicename.service is masked.)
```

Use masking to prevent services from starting after package updates.

## System targets (runlevels)

Targets group services that should run together. Like old runlevels.

Common targets:

```bash
# List all targets
systemctl list-units --type=target

# Check default target
systemctl get-default

# Set default target
sudo systemctl set-default multi-user.target
```

Main targets:
- `poweroff.target`: Shutdown system
- `rescue.target`: Single user mode
- `multi-user.target`: Multi-user, no GUI
- `graphical.target`: Multi-user with GUI
- `reboot.target`: Reboot system

Boot to different target:

```bash
# Boot to rescue mode (like single user mode)
sudo systemctl isolate rescue.target

# Boot to multi-user (text mode)
sudo systemctl isolate multi-user.target

# Boot to graphical mode
sudo systemctl isolate graphical.target
```

Set default boot target:

```bash
# Text mode by default
sudo systemctl set-default multi-user.target

# GUI by default
sudo systemctl set-default graphical.target
```

## Monitor resource usage

See current resource usage per service:

```bash
# Top-like view of services
systemd-cgtop

# Resource usage for specific service
systemctl status servicename
```

systemd-cgtop shows:
- CPU usage
- Memory usage
- I/O operations
- Tasks (processes/threads)

Press:
- `c` to sort by CPU
- `m` to sort by memory
- `t` to sort by tasks
- `q` to quit

Set resource limits in unit files (covered earlier):

```ini
[Service]
CPUQuota=25%
MemoryMax=512M
TasksMax=50
IOWeight=500
```

Check current limits:

```bash
systemctl show servicename -p CPUQuota -p MemoryMax -p TasksMax
```

## Command reference

```bash
# Service management
systemctl start service
systemctl stop service
systemctl restart service
systemctl reload service
systemctl enable service
systemctl disable service
systemctl enable --now service
systemctl status service
systemctl is-enabled service
systemctl is-active service

# Logs
journalctl -u service
journalctl -u service -f
journalctl -u service --since today
journalctl -u service -n 50
journalctl -b
journalctl -p err

# List services
systemctl list-units --type=service
systemctl list-units --type=service --state=failed
systemctl list-timers

# Configuration
systemctl daemon-reload
systemctl edit service
systemctl cat service
systemctl show service

# Troubleshooting
systemctl reset-failed
systemctl list-dependencies service
systemd-cgtop
systemctl status -l service

# System control
systemctl reboot
systemctl poweroff
systemctl suspend
systemctl hibernate
systemctl get-default
systemctl set-default multi-user.target
```

## Wrapping up

Systemd manages all services on modern Linux systems. Use systemctl to start, stop, enable, and monitor services. View logs with journalctl for troubleshooting.

Create custom services by writing .service files in /etc/systemd/system/. Define how to start the service, which user runs it, restart policies, and resource limits.

Replace cron jobs with timer units for better logging and reliability. Timers trigger services on schedules.

Debug failed services by checking status, viewing logs, examining unit files, and testing commands manually. Common issues are permissions, wrong paths, and port conflicts.

Systemd gives you complete control over services, logging, and resource management in one consistent interface. Master these commands and you can manage any Linux server.

For more server management, check out the SSH security guide, firewall configuration, and cron automation articles.
