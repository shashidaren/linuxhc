#!/bin/bash

# System Diagnostic Report Generator
# Usage: ./system_diagnostic_report.sh [hostname] [username]
# Can be run locally or remotely via SSH

VERSION="1.0"
SCRIPT_NAME="System Diagnostic Report"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Configuration
REMOTE_HOST="$1"
REMOTE_USER="$2"
REPORT_DIR="/tmp/diagnostic_reports"
REPORT_FILE="system_report_${REMOTE_HOST:-localhost}_${TIMESTAMP}.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to run command with error handling
safe_run() {
    local cmd="$1"
    local description="$2"

    echo -e "\n--- $description ---"
    if eval "$cmd" 2>/dev/null; then
        echo "✓ Command executed successfully"
    else
        echo "⚠ Command failed or not available: $cmd"
    fi
}

# Function to execute commands (local or remote)
execute_cmd() {
    local cmd="$1"
    if [[ -n "$REMOTE_HOST" && -n "$REMOTE_USER" ]]; then
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "$cmd"
    else
        eval "$cmd"
    fi
}

# Main diagnostic function
run_diagnostics() {
    local output_file="$1"

    {
        echo "$SCRIPT_NAME v$VERSION"
        echo "Generated: $(date)"
        echo "Target: ${REMOTE_HOST:-localhost}"
        echo "User: ${REMOTE_USER:-$(whoami)}"
        echo "Report ID: $TIMESTAMP"

        print_section "SYSTEM OVERVIEW"
        safe_run "hostname && uptime" "System Identity & Uptime"
        safe_run "uname -a" "Kernel Information"
        safe_run "cat /etc/os-release 2>/dev/null || cat /etc/redhat-release 2>/dev/null" "OS Version"
        safe_run "who" "Current Users"
        safe_run "last | head -10" "Recent Logins"

        print_section "RESOURCE UTILIZATION SNAPSHOT"
        safe_run "free -h" "Memory Usage"
        safe_run "df -h" "Disk Usage"
        safe_run "lscpu | grep -E '(CPU|Socket|Core|Thread)'" "CPU Information"
        safe_run "cat /proc/loadavg" "Load Average"

        print_section "TOP RESOURCE CONSUMERS"
        safe_run "ps aux --sort=-%cpu | head -15" "Top CPU Consumers"
        safe_run "ps aux --sort=-%mem | head -15" "Top Memory Consumers"
        safe_run "ps aux | wc -l && echo 'Total Processes'" "Process Count"

        print_section "MEMORY ANALYSIS"
        safe_run "cat /proc/meminfo | grep -E '(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Dirty|Slab)'" "Detailed Memory Info"
        if command_exists vmstat; then
            safe_run "vmstat 1 5" "Memory/Swap Activity (5 samples)"
        fi
        if command_exists slabtop; then
            safe_run "slabtop -o | head -15" "Kernel Memory Usage"
        fi

        print_section "I/O ANALYSIS"
        safe_run "iostat -x 1 3 2>/dev/null || echo 'iostat not available'" "Disk I/O Statistics"
        if command_exists iotop; then
            safe_run "timeout 10 iotop -ao -n 1 2>/dev/null | head -20" "I/O by Process"
        fi
        safe_run "lsof 2>/dev/null | awk '{print \$1}' | sort | uniq -c | sort -nr | head -10" "Open Files by Process"

        print_section "NETWORK STATUS"
        safe_run "ss -tuln | grep LISTEN | head -20" "Listening Services"
        safe_run "ss -i | grep -E '(retrans|lost)' | head -10" "Network Issues"
        safe_run "netstat -i" "Network Interface Statistics"

        print_section "SYSTEM SERVICES"
        safe_run "systemctl list-units --failed" "Failed Services"
        safe_run "systemctl list-units --type=service --state=running | head -20" "Running Services"

        print_section "RECENT SYSTEM EVENTS"
        safe_run "dmesg | tail -20" "Recent Kernel Messages"
        safe_run "journalctl --since '2 hours ago' -p err --no-pager | tail -20" "Recent Errors (2h)"
        safe_run "journalctl --since '1 hour ago' -p warning --no-pager | tail -15" "Recent Warnings (1h)"

        print_section "SYSTEM CHANGES"
        if command_exists rpm; then
            safe_run "rpm -qa --last | head -10" "Recent Package Changes (RPM)"
        elif command_exists dpkg; then
            safe_run "grep 'install\\|upgrade' /var/log/dpkg.log | tail -10" "Recent Package Changes (DEB)"
        fi
        safe_run "find /etc -name '*.conf' -mtime -1 2>/dev/null | head -10" "Recent Config Changes"

        print_section "APPLICATION SPECIFIC CHECKS"
        # Java applications
        safe_run "ps aux | grep java | grep -v grep" "Java Processes"
        safe_run "ps aux | grep java | grep -o '\\-Xmx[0-9]*[mg]' | sort | uniq -c" "Java Heap Settings"

        # Database processes
        safe_run "ps aux | grep -E '(mysql|postgres|oracle|mongo)' | grep -v grep" "Database Processes"

        # Web servers
        safe_run "ps aux | grep -E '(httpd|nginx|apache)' | grep -v grep" "Web Server Processes"

        print_section "PERFORMANCE TRENDING"
        if command_exists sar; then
            safe_run "sar -u 1 5" "CPU Usage Trend"
            safe_run "sar -r 1 5" "Memory Usage Trend"
            safe_run "sar -W 1 5" "Swap Activity Trend"
        fi

        print_section "SECURITY & ACCESS"
        safe_run "w" "Current User Activity"
        safe_run "tail -20 /var/log/secure 2>/dev/null || tail -20 /var/log/auth.log 2>/dev/null" "Recent Authentication Events"

        print_section "INHOUSE APPLICATION LOG ANALYSIS"
        # Discover application logs dynamically
        safe_run "find /var/log /opt/*/logs /home/*/logs /usr/local/*/logs -name '*.log' -type f -size +1M 2>/dev/null | head -20" "Large Log Files (>1MB)"
        safe_run "find /var/log /opt/*/logs /home/*/logs /usr/local/*/logs -name '*.log' -type f -mmin -60 2>/dev/null | head -15" "Recently Modified Logs (1h)"
        
        # Application log error analysis
        echo "--- Recent Application Errors (Last 2 hours) ---"
        find /var/log /opt/*/logs /home/*/logs /usr/local/*/logs -name "*.log" -type f -mmin -120 2>/dev/null | while read logfile; do
            if [[ -r "$logfile" ]]; then
                errors=$(grep -i -E "(error|exception|fatal|critical|fail)" "$logfile" 2>/dev/null | tail -5)
                if [[ -n "$errors" ]]; then
                    echo "=== $logfile ==="
                    echo "$errors"
                    echo ""
                fi
            fi
        done
        
        # Memory/OOM related log entries
        echo "--- Memory Related Log Entries ---"
        find /var/log /opt/*/logs /home/*/logs /usr/local/*/logs -name "*.log" -type f 2>/dev/null | while read logfile; do
            if [[ -r "$logfile" ]]; then
                oom_entries=$(grep -i -E "(out of memory|oom|memory leak|heap|gc)" "$logfile" 2>/dev/null | tail -3)
                if [[ -n "$oom_entries" ]]; then
                    echo "=== $logfile ==="
                    echo "$oom_entries"
                    echo ""
                fi
            fi
        done
        
        # High-level application process analysis
        safe_run "ps aux | awk 'NR>1 && \$11 !~ /^\\[/ && \$11 !~ /(systemd|kernel|kthread|migration|rcu_|watchdog|ksoftirq)/ {print \$11}' | sort | uniq -c | sort -nr | head -15" "Non-System Process Types"

        print_section "DIAGNOSTIC SUMMARY"
        echo "Report completed at: $(date)"
        echo "Total sections: 12"
        echo "Commands executed: ~50+"
        echo ""
        echo "QUICK ANALYSIS HINTS:"
        echo "- Check 'TOP RESOURCE CONSUMERS' for obvious culprits"
        echo "- Look at 'MEMORY ANALYSIS' for swap usage patterns"
        echo "- Review 'RECENT SYSTEM EVENTS' for errors/warnings"
        echo "- Examine 'I/O ANALYSIS' if load is high but CPU is low"
        echo "- Check 'SYSTEM CHANGES' for recent modifications"

    } > "$output_file" 2>&1
}

# Main execution
main() {
    echo -e "${GREEN}Starting $SCRIPT_NAME v$VERSION${NC}"

    # Create report directory
    mkdir -p "$REPORT_DIR"

    # Set full path for report
    FULL_REPORT_PATH="$REPORT_DIR/$REPORT_FILE"

    if [[ -n "$REMOTE_HOST" ]]; then
        echo -e "${YELLOW}Running diagnostics on remote host: $REMOTE_HOST${NC}"
        if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "echo 'Connection test'" >/dev/null 2>&1; then
            echo -e "${RED}Error: Cannot connect to $REMOTE_HOST${NC}"
            exit 1
        fi

        # Run diagnostics remotely and capture output
        execute_cmd "$(declare -f print_section safe_run command_exists; cat << 'EOF'
run_diagnostics() {
    local output_file="$1"

    {
        echo "System Diagnostic Report v1.0"
        echo "Generated: $(date)"
        echo "Target: $(hostname)"
        echo "User: $(whoami)"

        print_section "SYSTEM OVERVIEW"
        safe_run "hostname && uptime" "System Identity & Uptime"
        safe_run "uname -a" "Kernel Information"
        safe_run "cat /etc/os-release 2>/dev/null || cat /etc/redhat-release 2>/dev/null" "OS Version"
        safe_run "who" "Current Users"
        safe_run "last | head -10" "Recent Logins"

        print_section "RESOURCE UTILIZATION SNAPSHOT"
        safe_run "free -h" "Memory Usage"
        safe_run "df -h" "Disk Usage"
        safe_run "lscpu | grep -E '(CPU|Socket|Core|Thread)'" "CPU Information"
        safe_run "cat /proc/loadavg" "Load Average"

        print_section "TOP RESOURCE CONSUMERS"
        safe_run "ps aux --sort=-%cpu | head -15" "Top CPU Consumers"
        safe_run "ps aux --sort=-%mem | head -15" "Top Memory Consumers"
        safe_run "ps aux | wc -l && echo 'Total Processes'" "Process Count"

        print_section "MEMORY ANALYSIS"
        safe_run "cat /proc/meminfo | grep -E '(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Dirty|Slab)'" "Detailed Memory Info"
        if command_exists vmstat; then
            safe_run "vmstat 1 5" "Memory/Swap Activity (5 samples)"
        fi
        if command_exists slabtop; then
            safe_run "slabtop -o | head -15" "Kernel Memory Usage"
        fi

        print_section "I/O ANALYSIS"
        safe_run "iostat -x 1 3 2>/dev/null || echo 'iostat not available'" "Disk I/O Statistics"
        if command_exists iotop; then
            safe_run "timeout 10 iotop -ao -n 1 2>/dev/null | head -20" "I/O by Process"
        fi
        safe_run "lsof 2>/dev/null | awk '{print \$1}' | sort | uniq -c | sort -nr | head -10" "Open Files by Process"

        print_section "NETWORK STATUS"
        safe_run "ss -tuln | grep LISTEN | head -20" "Listening Services"
        safe_run "ss -i | grep -E '(retrans|lost)' | head -10" "Network Issues"
        safe_run "netstat -i" "Network Interface Statistics"

        print_section "SYSTEM SERVICES"
        safe_run "systemctl list-units --failed" "Failed Services"
        safe_run "systemctl list-units --type=service --state=running | head -20" "Running Services"

        print_section "RECENT SYSTEM EVENTS"
        safe_run "dmesg | tail -20" "Recent Kernel Messages"
        safe_run "journalctl --since '2 hours ago' -p err --no-pager | tail -20" "Recent Errors (2h)"
        safe_run "journalctl --since '1 hour ago' -p warning --no-pager | tail -15" "Recent Warnings (1h)"

        print_section "SYSTEM CHANGES"
        if command_exists rpm; then
            safe_run "rpm -qa --last | head -10" "Recent Package Changes (RPM)"
        elif command_exists dpkg; then
            safe_run "grep 'install\\|upgrade' /var/log/dpkg.log | tail -10" "Recent Package Changes (DEB)"
        fi
        safe_run "find /etc -name '*.conf' -mtime -1 2>/dev/null | head -10" "Recent Config Changes"

        print_section "APPLICATION SPECIFIC CHECKS"
        safe_run "ps aux | grep java | grep -v grep" "Java Processes"
        safe_run "ps aux | grep java | grep -o '\\-Xmx[0-9]*[mg]' | sort | uniq -c" "Java Heap Settings"
        safe_run "ps aux | grep -E '(mysql|postgres|oracle|mongo)' | grep -v grep" "Database Processes"
        safe_run "ps aux | grep -E '(httpd|nginx|apache)' | grep -v grep" "Web Server Processes"

        print_section "PERFORMANCE TRENDING"
        if command_exists sar; then
            safe_run "sar -u 1 5" "CPU Usage Trend"
            safe_run "sar -r 1 5" "Memory Usage Trend"
            safe_run "sar -W 1 5" "Swap Activity Trend"
        fi

        print_section "SECURITY & ACCESS"
        safe_run "w" "Current User Activity"
        safe_run "tail -20 /var/log/secure 2>/dev/null || tail -20 /var/log/auth.log 2>/dev/null" "Recent Authentication Events"

        print_section "DIAGNOSTIC SUMMARY"
        echo "Report completed at: $(date)"
        echo "Total sections: 12"
        echo "Commands executed: ~50+"
        echo ""
        echo "QUICK ANALYSIS HINTS:"
        echo "- Check 'TOP RESOURCE CONSUMERS' for obvious culprits"
        echo "- Look at 'MEMORY ANALYSIS' for swap usage patterns"
        echo "- Review 'RECENT SYSTEM EVENTS' for errors/warnings"
        echo "- Examine 'I/O ANALYSIS' if load is high but CPU is low"
        echo "- Check 'SYSTEM CHANGES' for recent modifications"

    }
}

run_diagnostics
EOF
)" > "$FULL_REPORT_PATH"
    else
        echo -e "${YELLOW}Running diagnostics on local host${NC}"
        run_diagnostics "$FULL_REPORT_PATH"
    fi

    echo -e "${GREEN}Diagnostic report completed!${NC}"
    echo -e "${BLUE}Report saved to: $FULL_REPORT_PATH${NC}"
    echo -e "${YELLOW}Report size: $(du -h "$FULL_REPORT_PATH" | cut -f1)${NC}"

    # Quick summary
    echo -e "\n${GREEN}Quick Summary:${NC}"
    if [[ -n "$REMOTE_HOST" ]]; then
        echo "Target: $REMOTE_HOST"
    else
        echo "Target: localhost"
    fi
    echo "Timestamp: $TIMESTAMP"
    echo "Report ID: $REPORT_FILE"
}

# Usage information
usage() {
    echo "Usage: $0 [hostname] [username]"
    echo ""
    echo "Examples:"
    echo "  $0                           # Run on local machine"
    echo "  $0 server01 admin           # Run on remote server"
    echo "  $0 192.168.1.100 root       # Run on remote IP"
    echo ""
    echo "Requirements:"
    echo "  - SSH key-based authentication for remote execution"
    echo "  - Standard Linux utilities (ps, free, df, etc.)"
    echo "  - Optional: sysstat package for sar/iostat"
    echo ""
}

# Check arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

# Run main function
main "$@"
