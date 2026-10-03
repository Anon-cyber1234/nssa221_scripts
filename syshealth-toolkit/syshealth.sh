#!/usr/bin/env bash
# ===============================================
# syshealth.sh - System Health & Log Analysis Toolkit
# Lab 3 - Refactoring into Functions
# Author: Yarin Tellez
# Date: 2026-10-03
# ===============================================

# --- Thresholds (global, used by multiple functions) ---
CPU_THRESHOLD=75
MEM_THRESHOLD=85
DISK_THRESHOLD=85

# --- Color-coded status helper function ---
print_status() {
    local status="$1"
    local message="$2"

    if [ "$status" = "OK" ]; then
        echo -e "\e[32m OK: $message\e[0m"
    elif [ "$status" = "CHECK" ]; then
        echo -e "\e[33m CHECK: $message\e[0m"
    else
        echo -e "\e[31m ALERT: $message\e[0m"
    fi
}

# --- Check disk usage ---
check_disk_usage() {
    local mount="$1"
    local pct threshold

    threshold="$DISK_THRESHOLD"

    if ! mountpoint -q "$mount" 2>/dev/null && [ "$mount" != "/" ]; then
        print_status "OK" "Mount point $mount does not exist or is not a mountpoint on this system"
        return 0
    fi

    pct=$(df "$mount" | tail -1 | awk '{gsub("%",""); print $5}')

    if (( pct > threshold )); then
        print_status "ALERT" "Disk usage on $mount is ${pct}% (threshold ${threshold}%)"
        return 1
    else
        print_status "OK" "Disk usage on $mount is ${pct}%"
        return 0
    fi
}

# --- Check memory usage ---
check_memory_usage() {
    local pct threshold

    threshold="$MEM_THRESHOLD"
    pct=$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}')

    if (( pct > threshold )); then
        print_status "ALERT" "Memory usage is ${pct}% (threshold ${threshold}%)"
        return 1
    else
        print_status "OK" "Memory usage is ${pct}%"
        return 0
    fi
}

# --- Check CPU usage ---
check_cpu_usage() {
    local pct threshold

    threshold="$CPU_THRESHOLD"
    pct=$(top -bn1 | grep '^%Cpu' | awk '{print 100 - $8}' | cut -d. -f1)

    if (( pct > threshold )); then
        print_status "ALERT" "CPU usage is ${pct}% (threshold ${threshold}%)"
        return 1
    else
        print_status "OK" "CPU usage is ${pct}%"
        return 0
    fi
}

# --- Run all health checks ---
run_health_checks() {
    local overall_status=0
    local mount

    print_status "CHECK" "Running system health analysis..."

    # Disk checks
    for mount in / /home /var; do
        if ! check_disk_usage "$mount"; then
            overall_status=1
        fi
    done

    # Memory check
    if ! check_memory_usage; then
        overall_status=1
    fi

    # CPU check
    if ! check_cpu_usage; then
        overall_status=1
    fi

    HEALTH_STATUS="$overall_status"

    return "$overall_status"
}

# --- Parse command-line arguments ---
parse_arguments() {
    OUTPUT_FILE="${1:-}"
}

# --- Generate system health report ---
generate_report() {
    local CURRENT_DATE HOSTNAME UPTIME DISK_USAGE MEMORY_USAGE PROCESS_COUNT

    CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    HOSTNAME=$(hostname)
    UPTIME=$(uptime -p)
    DISK_USAGE=$(df -h / | tail -1)
    MEMORY_USAGE=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
    PROCESS_COUNT=$(ps -e | wc -l)

    printf "========================================\n"
    printf "System Health Report - %s\n" "$CURRENT_DATE"
    printf "Hostname : %s\n" "$HOSTNAME"
    printf "Uptime : %s\n" "$UPTIME"
    printf "Disk / : %s\n" "$DISK_USAGE"
    printf "Memory used : %s\n" "$MEMORY_USAGE"
    printf "Total processes : %s\n" "$PROCESS_COUNT"

    if [ "${HEALTH_STATUS:-0}" -eq 0 ]; then
        printf "Health status : HEALTHY\n"
    else
        printf "Health status : UNHEALTHY - see alerts above\n"
    fi

    printf "========================================\n"
}

# --- Main function ---
main() {
    parse_arguments "$@"

    run_health_checks

    if [ -n "$OUTPUT_FILE" ]; then
        generate_report > "$OUTPUT_FILE"
        echo "Report written to $OUTPUT_FILE"
    else
        generate_report
    fi

    exit "${HEALTH_STATUS:-0}"
}

# Start the script
main "$@"