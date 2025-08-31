# Logs: recent errors and failed units
: "${LOG_ERR_THRESHOLD:=10}"

check_logs() {
  local errc=0
  # Last hour journal errors
  if run_cmd "command -v journalctl >/dev/null"; then
    errc=$(run_cmd "journalctl -p err -S -1h --no-pager 2>/dev/null | wc -l") || errc=0
  else
    # Fallback to syslog/messages
    if run_cmd "test -f /var/log/syslog"; then
      errc=$(run_cmd "grep -i 'error' /var/log/syslog | tail -n 500 | wc -l") || errc=0
    elif run_cmd "test -f /var/log/messages"; then
      errc=$(run_cmd "grep -i 'error' /var/log/messages | tail -n 500 | wc -l") || errc=0
    fi
  fi

  if [[ "$errc" =~ ^[0-9]+$ && "$errc" -ge "$LOG_ERR_THRESHOLD" ]]; then
    add_finding "WARN" "Recent Log Errors" "$errc errors in last hour (>= $LOG_ERR_THRESHOLD)"
  else
    add_finding "OK" "Recent Log Errors" "$errc errors in last hour"
  fi

  # OOM killer
  local ooms
  ooms=$(run_cmd "dmesg | grep -Ei 'Out of memory|oom-killer' | wc -l") || ooms=0
  if [[ "$ooms" =~ ^[0-9]+$ && "$ooms" -gt 0 ]]; then
    add_finding "WARN" "OOM Events" "$ooms OOM-related messages in dmesg"
  else
    add_finding "OK" "OOM Events" "No OOM messages"
  fi

  # Failed units count
  local failed
  failed=$(run_cmd "systemctl --failed --no-legend 2>/dev/null | wc -l") || failed=0
  if [[ "$failed" =~ ^[0-9]+$ && "$failed" -gt 0 ]]; then
    add_finding "WARN" "Failed Services" "$failed failed unit(s)"
  else
    add_finding "OK" "Failed Services" "None"
  fi
}

register_check "logs" "Log errors and failed units" check_logs 1
