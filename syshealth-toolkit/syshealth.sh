#!/usr/bin/env bash
# ===============================================
# syshealth.sh - System Health & Log Analysis Toolkit
# Lab 6 - CLI Interface and Automation
# Author: Yarin Tellez
# Date: 2026-11-09
# ===============================================

set -euo pipefail

trap 'log_message "ERROR" "Script exited unexpectedly with code $?"' ERR
trap 'log_message "INFO" "Script finished normally with code $?"' EXIT

# --- Thresholds (global, used by multiple functions) ---
CPU_THRESHOLD=75
MEM_THRESHOLD=85
DISK_THRESHOLD=85

log_message()
{
	local level="$1"
	local message="$2"
	local log_file="$HOME/.syshealth.log"
	local timestamp

	timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	mkdir -p "$(dirname "$log_file")"
	echo "$timestamp [$level] $message" >> "$log_file"
}

generate_report()
{
	local CURRENT_DATE HOSTNAME UPTIME DISK_USAGE MEMORY_USAGE PROCESS_COUNT

	CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
	HOSTNAME=$(hostname)
	UPTIME=$(uptime -p)
	DISK_USAGE=$(df -h / | tail -1) 
	MEMORY_USAGE=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
	PROCESS_COUNT=$(ps -e | wc -l)

	local -a report_metrics
	report_metrics=(
		"Hostname: $HOSTNAME"
		"Uptime: $UPTIME"
		"Disk /: $DISK_USAGE"
		"Memory used: $MEMORY_USAGE"
		"Total Processes: $PROCESS_COUNT"
		"Health status: $([ "${HEALTH_STATUS:-0}" -eq 0 ] && echo "HEALTHY" || echo "UNHEALTHY")"
	)
	printf "==============================\n"
	printf "System Health Report - %s\n" "$CURRENT_DATE"
	printf " ============================================\n"
	
	for metric in "${report_metrics[@]}"; do
		printf "%s\n" "$metric"
	done
	printf "========================\n"
	
	printf "\n ========================================\n"
	printf "LOG ANALYSIS SUMMARY\n"
	printf "\n======================================\n"
	analyze_logs

	cat << EOF 

--- End of Report ---
Script: syshealth.sh (Lab 5 - Error Handling & Professional Reports)
Generated: $CURRENT_DATE
Exit status: ${HEALTH_STATUS:-0} ($( [ "${HEALTH_STATUS:-0}" -eq 0 ] && echo "HEALTHY" || echo "UNHEALTHY"))
Log file: $HOME/.syshealth.log
===================================
EOF
	log_message "INFO" "Report generated successfully (exit code ${HEALTH_STATUS:-0})"
}

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
            log_message "ERROR" "Health check alert detected"
	fi
    done

    # Memory check
    if ! check_memory_usage; then
        overall_status=1
        log_message "ERROR" "Health check alert detected"
    fi

    # CPU check
    if ! check_cpu_usage; then
        overall_status=1
	log_message "ERROR" "Health check alert deteced"
    fi

    HEALTH_STATUS="$overall_status"

    return "$overall_status"
}

analyze_logs() {
    local log_file="${1:-/var/log/messages}"
    local errors=0
    local warnings=0
    local failed_logins=0
    local top_issues

    # Gracefully handle missing or unreadable log files without crashing

    if [ ! -r "$log_file" ]; then
        printf "\nLog Analysis Summary (%s):\n" "$(basename "$log_file")"
        printf " Log file not readable or does not exist on this system.\n"
        printf " (This is normal in some containers or minimal installs.)\n"
        log_message "INFO" "Log analysis completed - $log_file unavailable"
        return 0
    fi

    # Count issues
    errors=$(grep -E -i 'ERROR|Error|error' "$log_file" 2>/dev/null | wc -l)
    warnings=$(grep -E -i 'WARNING|Warning|warning' "$log_file" 2>/dev/null | wc -l)
    failed_logins=$(grep -E -i 'Failed password|authentication failure|Failed login' "$log_file" 2>/dev/null | wc -l)

    printf "\nTop 5 recurring issues:\n"

    top_issues=$(grep -E -i 'ERROR|Error|error|WARNING|Warning|warning|Failed password|authentication failure|Failed login' "$log_file" 2>/dev/null \
        | sed 's/.*\]: //' \
        | sort \
        | uniq -c \
        | sort -nr \
        | head -5)

    printf "%s\n" "$top_issues"

    # Summary
    printf "\nLog Analysis Summary (%s):\n" "$(basename "$log_file")"
    printf " Errors            : %d\n" "$errors"
    printf " Warnings          : %d\n" "$warnings"
    printf " Failed logins     : %d\n" "$failed_logins"
    log_message "INFO" "Log analysis completed"
}

# --- Parse command-line arguments ---
parse_arguments() {
    OUTPUT_FILE="${1:-}"
}
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTION] [OUTPUT_FILE]

System Health & Log Analysis Toolkit (Capstone - Lab 6)

Options:
  -m, --monitor    Run health checks only (CPU, memory, disk) with colored alerts
  -a, --analyze    Run log analysis only (default: /var/log/messages)
  -r, --report     Generate full timestamped report (metrics + alerts + logs)
  -h, --help       Show this help message and exit
  -v, --version    Show version information and exit

Positional argument (backward compatible):
  OUTPUT_FILE      Optional filename to write the report to

Examples:
  $(basename "$0") --monitor
  $(basename "$0") --report daily_$(date +%F).txt
  $(basename "$0") -a /var/log/secure

Report bugs to your instructor.
EOF

    exit 0
}

version() {
    echo "syshealth.sh version 1.0 (NSSA221 Scripting Series - Capstone)"
    echo "Built as final project - $(date '+%Y')"
    echo "Features: Health checks, log analysis, strict mode, persistent logging, CLI modes"
    exit 0
} 




# --- Main function ---
main() {
    parse_arguments "$@"

    log_message "INFO" "syshealth.sh started (Lab 5)"

    run_health_checks

    if [ -n "$OUTPUT_FILE" ]; then
        generate_report > "$OUTPUT_FILE"
        echo "Report written to $OUTPUT_FILE"
	log_message "INFO" "Report written to $OUTPUT_FILE"
    else
        generate_report
    fi

    exit "${HEALTH_STATUS:-0}"
}

# Start the script
main "$@"

