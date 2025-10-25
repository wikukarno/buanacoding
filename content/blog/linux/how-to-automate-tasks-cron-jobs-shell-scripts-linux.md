---
title: 'How to Automate Tasks with Cron Jobs and Shell Scripts on Linux'
date: 2025-10-26T14:00:00+07:00
draft: false
url: /2025/10/how-to-automate-tasks-cron-jobs-shell-scripts-linux.html
tags:
- Linux
- Cron
- Automation
- Shell Scripting
- Bash
- DevOps
description: 'Automate Linux tasks with cron jobs and bash shell scripts to save time and reduce errors. Learn crontab syntax and scheduling, create automated backup scripts for files and databases, set up system monitoring, implement log rotation, send email notifications on failures, handle errors properly, and apply production-ready automation best practices.'
keywords: ['cron jobs tutorial','crontab syntax','linux automation','bash scripts','automated backups','cron examples','shell script automation','schedule tasks linux','cron email notifications','linux task scheduler']
featured: false
faq:
  - question: "What is cron and how does crontab syntax work?"
    answer: "Cron is Linux's time-based job scheduler that runs commands automatically on schedules. Crontab syntax has 5 time fields plus the command: minute (0-59), hour (0-23), day of month (1-31), month (1-12), day of week (0-7, where 0 and 7 are Sunday). Asterisk (*) means 'every', so '0 2 * * *' runs at 2 AM daily. Ranges work like '0-5' for 0 through 5, and step values like '*/15' mean every 15 units. Example: '30 3 * * 1' runs Mondays at 3:30 AM. '0 */6 * * *' runs every 6 hours. The crontab file is per-user - edit with 'crontab -e'. System cron jobs go in /etc/crontab or /etc/cron.d/."
  - question: "How do I schedule automated backups with cron?"
    answer: "Create a backup script in /usr/local/bin/ that uses tar to compress files, add timestamps to filenames, and optionally upload to remote storage. Make it executable with chmod +x. Add to crontab with 'crontab -e' using a schedule like '0 2 * * *' for daily 2 AM backups. Include error handling, logging to a file, and rotation to delete old backups (keep last 7 days). Example: tar -czf backup-$(date +%Y%m%d).tar.gz /var/www and find /backups -name 'backup-*.tar.gz' -mtime +7 -delete. Test manually before relying on cron. Add email notifications for failures. For databases, use mysqldump or pg_dump in the script."
  - question: "Why isn't my cron job running and how do I debug it?"
    answer: "Common reasons: Environment variables missing (PATH, USER, HOME aren't set like in your shell), relative paths not working (always use absolute paths like /usr/bin/php instead of just php), cron daemon not running (check with systemctl status cron), syntax errors in crontab (test with crontab -l), permissions issues (script not executable or cron can't read it), or output being lost (redirect to a log file). Debug by checking mail (cron emails errors by default), viewing cron logs with grep CRON /var/log/syslog, testing your script manually, adding logging to your script with echo and >>, and running with bash -x for verbose output. Set MAILTO in crontab to get error emails."
  - question: "What's the difference between user crontab and system cron jobs?"
    answer: "User crontab (edited with crontab -e) runs jobs as that specific user, doesn't need a username field in the syntax, and is stored in /var/spool/cron/crontabs/. System cron (/etc/crontab and /etc/cron.d/) includes a username field before the command, runs as root or specified user, and is for system-wide maintenance. System cron also has directories /etc/cron.hourly/, /etc/cron.daily/, /etc/cron.weekly/, /etc/cron.monthly/ where you just drop executable scripts - no crontab syntax needed. Use user crontab for personal automation, system cron for server maintenance. Never edit /var/spool/cron/crontabs/ directly - always use crontab -e."
  - question: "How do I handle errors and get notifications from cron jobs?"
    answer: "Cron emails stdout/stderr to the user by default if mail is configured. Set MAILTO=your@email.com at the top of crontab. For better error handling, redirect output in your script: exec >> /var/log/myscript.log 2>&1 at the start logs everything. Use 'set -e' to exit on first error. Check command exit codes with if [ $? -ne 0 ]; then and send alerts. For critical jobs, send explicit notifications: curl webhooks on failure, or use mail command to send emails. Log successes and failures with timestamps. Example: command || echo 'Failed' | mail -s 'Job Failed' admin@example.com. Test error handling by intentionally breaking your script."
  - question: "Should I use cron or systemd timers for automation?"
    answer: "Use cron for simple scheduled tasks and user-level automation - it's simpler, has been around forever, and works everywhere. Use systemd timers for system services, anything requiring precise timing, jobs that need to run if missed (Persistent=true), or when you want better logging through journalctl. Timers integrate with systemd's dependency system and resource controls. Cron is easier for one-off tasks like personal backups, while timers are better for production services. You can run both - many servers use cron for traditional tasks and timers for modern service management. If you're already using systemd services, stick with timers. If you just need to run a script daily, cron is faster to set up."
---

Automation separates beginners from experienced system administrators. Instead of manually running backups, monitoring logs, or cleaning temporary files, you write scripts once and let cron run them automatically.

Cron handles time-based scheduling. Shell scripts do the actual work. Combined, they automate everything from database backups to system monitoring, log rotation, security scans, and report generation.

This guide covers cron syntax, writing production-ready shell scripts, automated backups, monitoring, error handling, and notifications for reliable automation.

<!--readmore-->

## What is cron and how it works

Cron is a daemon that runs continuously on Linux systems. It checks crontab files every minute and executes scheduled commands.

Check if cron is running:

```bash
systemctl status cron
```

If not running, start it:

```bash
sudo systemctl enable --now cron
```

Cron reads schedules from several locations:

- **User crontabs**: Each user has a crontab file edited with `crontab -e`
- **System crontab**: `/etc/crontab` for system-wide jobs
- **Cron directories**: Scripts in `/etc/cron.hourly/`, `/etc/cron.daily/`, `/etc/cron.weekly/`, `/etc/cron.monthly/`
- **Cron.d**: Individual job files in `/etc/cron.d/`

Most personal automation uses user crontabs. System maintenance uses system cron.

## Crontab syntax explained

Crontab entries have 5 time fields plus the command:

```
* * * * * command to execute
│ │ │ │ │
│ │ │ │ └─── Day of week (0-7, both 0 and 7 are Sunday)
│ │ │ └───── Month (1-12)
│ │ └─────── Day of month (1-31)
│ └───────── Hour (0-23)
└─────────── Minute (0-59)
```

Examples:

```bash
# Run at 2:30 AM every day
30 2 * * * /usr/local/bin/backup.sh

# Run every hour on the hour
0 * * * * /usr/local/bin/check-status.sh

# Run every 15 minutes
*/15 * * * * /usr/local/bin/monitor.sh

# Run at 5 PM Monday through Friday
0 17 * * 1-5 /usr/local/bin/workday-report.sh

# Run at midnight on the 1st of every month
0 0 1 * * /usr/local/bin/monthly-cleanup.sh

# Run every Sunday at 3 AM
0 3 * * 0 /usr/local/bin/weekly-backup.sh

# Run every 6 hours
0 */6 * * * /usr/local/bin/periodic-check.sh

# Run twice daily at 9 AM and 6 PM
0 9,18 * * * /usr/local/bin/twice-daily.sh

# Run every weekday at 8:30 AM
30 8 * * 1-5 /usr/local/bin/morning-routine.sh

# Run every 30 minutes between 9 AM and 5 PM
*/30 9-17 * * * /usr/local/bin/business-hours-check.sh
```

Special shortcuts:

```bash
@reboot       # Run once at startup
@yearly       # Run once a year (0 0 1 1 *)
@annually     # Same as @yearly
@monthly      # Run once a month (0 0 1 * *)
@weekly       # Run once a week (0 0 * * 0)
@daily        # Run once a day (0 0 * * *)
@midnight     # Same as @daily
@hourly       # Run once an hour (0 * * * *)

# Example: Run backup script at startup
@reboot /usr/local/bin/startup-backup.sh
```

## Manage your crontab

Edit your crontab:

```bash
crontab -e
```

This opens your crontab in the default editor. First time might ask which editor to use (choose nano if unsure).

View current crontab:

```bash
crontab -l
```

Remove all cron jobs:

```bash
crontab -r
```

Edit another user's crontab (requires root):

```bash
sudo crontab -u username -e
```

Your crontab file can include environment variables:

```bash
# Set email for notifications
MAILTO=admin@example.com

# Set shell
SHELL=/bin/bash

# Set PATH
PATH=/usr/local/bin:/usr/bin:/bin

# Jobs
30 2 * * * /usr/local/bin/backup.sh
0 * * * * /usr/local/bin/check-status.sh
```

## Write your first automation script

Let's create a script that backs up a directory daily.

Create the script:

```bash
sudo nano /usr/local/bin/backup.sh
```

Basic backup script:

```bash
#!/bin/bash

# Daily backup script
# Backs up /var/www to /backups

# Variables
BACKUP_SOURCE="/var/www"
BACKUP_DEST="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_${DATE}.tar.gz"
LOG_FILE="/var/log/backup.log"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DEST"

# Log start
echo "[$(date)] Starting backup..." >> "$LOG_FILE"

# Create backup
if tar -czf "${BACKUP_DEST}/${BACKUP_FILE}" "$BACKUP_SOURCE" 2>> "$LOG_FILE"; then
    echo "[$(date)] Backup successful: ${BACKUP_FILE}" >> "$LOG_FILE"

    # Delete backups older than 7 days
    find "$BACKUP_DEST" -name "backup_*.tar.gz" -mtime +7 -delete
    echo "[$(date)] Old backups cleaned" >> "$LOG_FILE"
else
    echo "[$(date)] Backup FAILED!" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Backup completed" >> "$LOG_FILE"
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/backup.sh
```

Test it manually:

```bash
sudo /usr/local/bin/backup.sh
```

Check the log:

```bash
cat /var/log/backup.log
```

Add to crontab to run daily at 2 AM:

```bash
crontab -e
```

Add line:

```
0 2 * * * /usr/local/bin/backup.sh
```

## Database backup automation

MySQL/MariaDB backup script:

```bash
#!/bin/bash

# MySQL backup script

# Configuration
DB_USER="backup_user"
DB_PASS="secure_password"
DB_NAME="mydatabase"
BACKUP_DIR="/backups/mysql"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/mysql_${DB_NAME}_${DATE}.sql.gz"
LOG_FILE="/var/log/mysql-backup.log"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Dump database
echo "[$(date)] Starting MySQL backup..." >> "$LOG_FILE"

if mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" | gzip > "$BACKUP_FILE"; then
    echo "[$(date)] Backup successful: ${BACKUP_FILE}" >> "$LOG_FILE"

    # Delete backups older than 14 days
    find "$BACKUP_DIR" -name "mysql_*.sql.gz" -mtime +14 -delete

    # Get backup size
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "[$(date)] Backup size: ${SIZE}" >> "$LOG_FILE"
else
    echo "[$(date)] Backup FAILED!" >> "$LOG_FILE"
    exit 1
fi
```

PostgreSQL backup:

```bash
#!/bin/bash

# PostgreSQL backup script

DB_NAME="mydatabase"
DB_USER="postgres"
BACKUP_DIR="/backups/postgres"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/postgres_${DB_NAME}_${DATE}.sql.gz"

mkdir -p "$BACKUP_DIR"

# Backup database
pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"

# Clean old backups
find "$BACKUP_DIR" -name "postgres_*.sql.gz" -mtime +14 -delete
```

For PostgreSQL, create `.pgpass` file to avoid password prompts:

```bash
echo "localhost:5432:*:postgres:your_password" > ~/.pgpass
chmod 600 ~/.pgpass
```

## System monitoring automation

Disk space monitoring script:

```bash
#!/bin/bash

# Check disk space and alert if over threshold

THRESHOLD=80
EMAIL="admin@example.com"

# Check each mounted filesystem
df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 " " $6 }' | while read output; do
    USAGE=$(echo $output | awk '{ print $1}' | sed 's/%//g')
    PARTITION=$(echo $output | awk '{ print $2 }')
    MOUNT=$(echo $output | awk '{ print $3 }')

    if [ $USAGE -ge $THRESHOLD ]; then
        echo "Disk space alert: ${PARTITION} mounted on ${MOUNT} is ${USAGE}% full" | \
        mail -s "Disk Space Alert on $(hostname)" "$EMAIL"
    fi
done
```

Run every hour:

```
0 * * * * /usr/local/bin/check-disk.sh
```

Memory monitoring:

```bash
#!/bin/bash

# Monitor memory usage

THRESHOLD=90
EMAIL="admin@example.com"

MEMORY_USAGE=$(free | grep Mem | awk '{print ($3/$2) * 100.0}' | cut -d'.' -f1)

if [ $MEMORY_USAGE -ge $THRESHOLD ]; then
    {
        echo "Memory usage is at ${MEMORY_USAGE}%"
        echo ""
        echo "Top memory-consuming processes:"
        ps aux --sort=-%mem | head -n 10
    } | mail -s "Memory Alert on $(hostname)" "$EMAIL"
fi
```

Service availability check:

```bash
#!/bin/bash

# Check if critical services are running

SERVICES=("nginx" "mysql" "redis")
EMAIL="admin@example.com"
ALERT=""

for SERVICE in "${SERVICES[@]}"; do
    if ! systemctl is-active --quiet "$SERVICE"; then
        ALERT="${ALERT}Service ${SERVICE} is DOWN!\n"

        # Try to restart
        systemctl start "$SERVICE"

        if systemctl is-active --quiet "$SERVICE"; then
            ALERT="${ALERT}Service ${SERVICE} restarted successfully.\n\n"
        else
            ALERT="${ALERT}Service ${SERVICE} FAILED to restart!\n\n"
        fi
    fi
done

if [ -n "$ALERT" ]; then
    echo -e "$ALERT" | mail -s "Service Alert on $(hostname)" "$EMAIL"
fi
```

## Log rotation and cleanup

Clean old logs:

```bash
#!/bin/bash

# Rotate and compress logs

LOG_DIR="/var/log/myapp"
DAYS_TO_KEEP=30

# Compress logs older than 1 day
find "$LOG_DIR" -name "*.log" -mtime +1 -exec gzip {} \;

# Delete compressed logs older than 30 days
find "$LOG_DIR" -name "*.log.gz" -mtime +$DAYS_TO_KEEP -delete

# Truncate current log if larger than 100MB
for LOG in "$LOG_DIR"/*.log; do
    if [ -f "$LOG" ]; then
        SIZE=$(stat -f%z "$LOG" 2>/dev/null || stat -c%s "$LOG" 2>/dev/null)
        if [ $SIZE -gt 104857600 ]; then
            cp "$LOG" "${LOG}.old"
            > "$LOG"
            gzip "${LOG}.old"
        fi
    fi
done
```

Clean temporary files:

```bash
#!/bin/bash

# Clean temporary files and caches

# Clean apt cache (Ubuntu/Debian)
apt-get clean

# Clean old kernels (keep last 2)
apt-get autoremove --purge -y

# Clean systemd journal (keep last 7 days)
journalctl --vacuum-time=7d

# Clean temp directories
find /tmp -type f -atime +7 -delete
find /var/tmp -type f -atime +30 -delete

# Clean old user cache
find /home/*/.cache -type f -atime +30 -delete 2>/dev/null

echo "Cleanup completed on $(date)"
```

Run weekly:

```
0 3 * * 0 /usr/local/bin/cleanup.sh
```

## Error handling and notifications

Script with proper error handling:

```bash
#!/bin/bash

# Backup script with error handling

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# Configuration
SCRIPT_NAME="backup"
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
EMAIL="admin@example.com"
BACKUP_SOURCE="/var/www"
BACKUP_DEST="/backups"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handler
error_exit() {
    log "ERROR: $1"
    echo "Backup failed on $(hostname): $1" | mail -s "Backup Error" "$EMAIL"
    exit 1
}

# Cleanup function (runs on exit)
cleanup() {
    if [ $? -ne 0 ]; then
        log "Script exited with error"
    fi
}
trap cleanup EXIT

# Main script
log "Starting backup"

# Check if source exists
[ -d "$BACKUP_SOURCE" ] || error_exit "Backup source $BACKUP_SOURCE not found"

# Check if destination is writable
[ -w "$BACKUP_DEST" ] || error_exit "Cannot write to $BACKUP_DEST"

# Check available disk space (need at least 10GB)
AVAILABLE=$(df "$BACKUP_DEST" | tail -1 | awk '{print $4}')
[ $AVAILABLE -gt 10485760 ] || error_exit "Not enough disk space"

# Create backup
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DEST}/backup_${DATE}.tar.gz"

if tar -czf "$BACKUP_FILE" "$BACKUP_SOURCE" 2>> "$LOG_FILE"; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "Backup successful: ${BACKUP_FILE} (${SIZE})"

    # Verify backup integrity
    if tar -tzf "$BACKUP_FILE" > /dev/null 2>&1; then
        log "Backup integrity verified"
    else
        error_exit "Backup verification failed"
    fi

    # Cleanup old backups
    DELETED=$(find "$BACKUP_DEST" -name "backup_*.tar.gz" -mtime +7 -delete -print | wc -l)
    log "Deleted $DELETED old backups"

    # Send success notification
    echo "Backup completed successfully: ${SIZE}" | mail -s "Backup Success" "$EMAIL"
else
    error_exit "Backup creation failed"
fi

log "Backup completed successfully"
```

Key error handling techniques:

**Set strict mode:**
```bash
set -e  # Exit on any error
set -u  # Exit on undefined variable
set -o pipefail  # Exit if any pipe command fails
```

**Check prerequisites:**
```bash
# Check if command exists
command -v mysql >/dev/null 2>&1 || { echo "mysql not found"; exit 1; }

# Check if file exists
[ -f /path/to/file ] || { echo "File not found"; exit 1; }

# Check if directory is writable
[ -w /path/to/dir ] || { echo "Directory not writable"; exit 1; }
```

**Capture command exit status:**
```bash
if ! mysqldump database > backup.sql; then
    echo "Mysqldump failed"
    exit 1
fi

# Or check $? after command
mysqldump database > backup.sql
if [ $? -ne 0 ]; then
    echo "Mysqldump failed"
    exit 1
fi
```

**Use trap for cleanup:**
```bash
cleanup() {
    rm -f /tmp/tempfile
    echo "Cleaned up"
}
trap cleanup EXIT
```

## Send email notifications

Install mail utilities:

```bash
# Ubuntu/Debian
sudo apt install mailutils

# Configure mail server or use external SMTP
```

Send simple email from script:

```bash
echo "This is the message body" | mail -s "Subject Line" user@example.com
```

Send file as attachment:

```bash
echo "See attached log" | mail -s "Daily Report" -A /var/log/report.log user@example.com
```

HTML email:

```bash
{
    echo "To: admin@example.com"
    echo "Subject: Server Report"
    echo "Content-Type: text/html"
    echo ""
    echo "<html><body>"
    echo "<h1>Server Status Report</h1>"
    echo "<p>Disk usage: $(df -h / | tail -1 | awk '{print $5}')</p>"
    echo "</body></html>"
} | sendmail -t
```

Send to multiple recipients:

```bash
echo "Alert message" | mail -s "Alert" user1@example.com,user2@example.com
```

## Advanced cron techniques

**Run job every X minutes:**
```bash
# Every 5 minutes
*/5 * * * * /path/to/script.sh

# Every 30 minutes
*/30 * * * * /path/to/script.sh

# Every 2 hours
0 */2 * * * /path/to/script.sh
```

**Run during specific hours:**
```bash
# Every 15 minutes from 9 AM to 5 PM
*/15 9-17 * * * /path/to/script.sh

# Every hour from 9 PM to 6 AM
0 21-23,0-6 * * * /path/to/script.sh
```

**Run on specific days:**
```bash
# Weekdays only (Monday-Friday)
0 9 * * 1-5 /path/to/script.sh

# Weekends only
0 10 * * 6,7 /path/to/script.sh

# First day of month
0 2 1 * * /path/to/script.sh

# Last day of month (runs on 28th-31st, script checks if tomorrow is next month)
0 2 28-31 * * [ $(date -d tomorrow +\%d) -eq 1 ] && /path/to/script.sh
```

**Prevent overlapping jobs:**

Create a lock file:

```bash
#!/bin/bash

LOCKFILE=/var/lock/myscript.lock

# Check if already running
if [ -f "$LOCKFILE" ]; then
    echo "Script already running"
    exit 1
fi

# Create lock file
touch "$LOCKFILE"

# Remove lock on exit
trap "rm -f $LOCKFILE" EXIT

# Your script here
sleep 60
echo "Job completed"
```

**Random delays:**

Avoid all servers hitting an API at the exact same time:

```bash
# Sleep random time between 0-300 seconds (5 minutes)
sleep $((RANDOM % 300))
# Then run the actual command
```

**Redirect output:**

```bash
# Discard all output
* * * * * /path/to/script.sh > /dev/null 2>&1

# Save output to log
* * * * * /path/to/script.sh >> /var/log/cron.log 2>&1

# Email only errors (stdout discarded, stderr emailed)
* * * * * /path/to/script.sh > /dev/null
```

## System cron directories

Instead of crontab syntax, drop executable scripts in these directories:

```bash
/etc/cron.hourly/   # Runs every hour
/etc/cron.daily/    # Runs daily
/etc/cron.weekly/   # Runs weekly
/etc/cron.monthly/  # Runs monthly
```

Example daily backup script:

```bash
sudo nano /etc/cron.daily/backup
```

```bash
#!/bin/bash
tar -czf /backups/daily-$(date +%Y%m%d).tar.gz /var/www
```

Make executable:

```bash
sudo chmod +x /etc/cron.daily/backup
```

Scripts in these directories run at times defined in `/etc/crontab`.

## Debugging cron jobs

**Check cron logs:**

```bash
# Ubuntu/Debian
grep CRON /var/log/syslog

# RHEL/CentOS
grep CRON /var/log/cron

# See only today's cron activity
grep CRON /var/log/syslog | grep "$(date '+%b %e')"
```

**Check mail:**

Cron emails output to the user. Check mail:

```bash
mail
```

**Test the command:**

Run the exact command from crontab manually:

```bash
/usr/local/bin/backup.sh
```

**Add debugging:**

Add to script:

```bash
#!/bin/bash
set -x  # Print each command before executing

# Or redirect to debug log
exec 2>/tmp/script-debug.log
set -x
```

**Check environment:**

Cron runs with minimal environment. Print variables:

```bash
* * * * * env > /tmp/cron-env.txt
```

Compare with your shell environment:

```bash
env > /tmp/shell-env.txt
diff /tmp/cron-env.txt /tmp/shell-env.txt
```

**Common issues:**

Path problems - use absolute paths:
```bash
# Wrong
* * * * * backup.sh

# Correct
* * * * * /usr/local/bin/backup.sh
```

Missing environment - set in crontab:
```bash
PATH=/usr/local/bin:/usr/bin:/bin
SHELL=/bin/bash
```

Permissions - make script executable:
```bash
chmod +x /path/to/script.sh
```

## Tips for production automation

**Always log:**
```bash
exec >> /var/log/myscript.log 2>&1
echo "[$(date)] Script started"
```

**Handle errors:**
```bash
set -euo pipefail
```

**Use absolute paths:**
```bash
/usr/bin/mysql instead of mysql
/var/www/app instead of ../app
```

**Test before scheduling:**
Run manually multiple times before adding to cron.

**Add monitoring:**
Send notifications on failure.

**Prevent overlaps:**
Use lock files for long-running jobs.

**Clean up after yourself:**
Delete temporary files, close connections.

**Document your cron jobs:**
Add comments explaining what each job does:

```bash
# Database backup - runs at 2 AM daily
0 2 * * * /usr/local/bin/backup-mysql.sh

# Disk space check - every hour
0 * * * * /usr/local/bin/check-disk.sh
```

**Rotate and limit logs:**
Don't let log files grow forever.

**Version control:**
Keep scripts in git, deploy to `/usr/local/bin/`.

**Use configuration files:**
Don't hardcode credentials in scripts:

```bash
# Load config
source /etc/myapp/config.sh

# Use variables from config
mysql -u "$DB_USER" -p"$DB_PASS"
```

## Command reference

**Crontab commands:**
```bash
crontab -e      # Edit crontab
crontab -l      # List cron jobs
crontab -r      # Remove all jobs
crontab -u user -e  # Edit user's crontab
```

**Common schedules:**
```bash
@reboot         # At startup
@hourly         # Every hour
@daily          # Every day at midnight
@weekly         # Every Sunday at midnight
@monthly        # First day of month at midnight

*/5 * * * *     # Every 5 minutes
0 * * * *       # Every hour
0 0 * * *       # Every day at midnight
0 2 * * *       # Every day at 2 AM
0 0 * * 0       # Every Sunday at midnight
0 0 1 * *       # First of every month
```

**Script template:**
```bash
#!/bin/bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/${SCRIPT_NAME}.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Script started"

# Your code here

log "Script completed"
```

## Wrapping up

Automation saves time and reduces errors. Cron schedules tasks, shell scripts do the work. Write scripts that handle errors, log activity, and send notifications.

Start with simple tasks like backups and monitoring. Test thoroughly before adding to cron. Use absolute paths, check exit codes, and always log what happens.

For critical automation, consider systemd timers as an alternative to cron. They offer better logging, dependency management, and recovery from missed runs.

Automate routine tasks and focus your time on actual problems instead of repetitive maintenance. Good automation runs quietly until something breaks, then your logs and alerts tell you what happened.

For more Linux automation, check out the systemd service management guide and firewall configuration article.
