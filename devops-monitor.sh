#!/bin/bash

# ==========================================
# DevOps System Health Monitor
# ==========================================

set -Eeuo pipefail

# Configuration
LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/health.log"
DISK_THRESHOLD=80
MEMORY_THRESHOLD=80

# Create log directory
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handler
trap 'log "ERROR: Script failed at line $LINENO"' ERR

# Check dependencies
for cmd in df free uptime; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log "ERROR: Required command '$cmd' is missing."
        exit 1
    fi
done

log "========== SYSTEM HEALTH CHECK STARTED =========="

# 1. System uptime
UPTIME_INFO=$(uptime -p)
log "System Uptime: $UPTIME_INFO"

# 2. CPU load
LOAD_AVERAGE=$(awk '{print $1, $2, $3}' /proc/loadavg)
log "CPU Load Average (1, 5, 15 min): $LOAD_AVERAGE"

# 3. Memory usage
MEMORY_USAGE=$(free | awk '/Mem:/ {printf "%.0f", ($3/$2)*100}')

log "Memory Usage: ${MEMORY_USAGE}%"

if (( MEMORY_USAGE >= MEMORY_THRESHOLD )); then
    log "WARNING: Memory usage is above ${MEMORY_THRESHOLD}%!"
fi

# 4. Disk usage
while read -r filesystem size used available percentage mountpoint; do

    # Skip filesystems that do not report a numeric percentage
    [[ "$percentage" =~ ^[0-9]+%$ ]] || continue

    usage=${percentage%\%}

    log "Disk: $mountpoint | Usage: ${usage}%"

    if (( usage >= DISK_THRESHOLD )); then
        log "WARNING: Disk usage on $mountpoint is above ${DISK_THRESHOLD}%!"
    fi

done < <(df -P -x tmpfs -x devtmpfs | tail -n +2)

# 5. Check services
SERVICES=("ssh" "cron")

for service in "${SERVICES[@]}"; do

    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet "$service"; then
            log "Service $service: RUNNING"
        else
            log "WARNING: Service $service is NOT RUNNING"
        fi
    else
        log "Skipping service check: systemctl is unavailable."
        break
    fi

done

log "========== SYSTEM HEALTH CHECK COMPLETED =========="
