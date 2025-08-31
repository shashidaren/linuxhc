# System basics: OS, uptime, load, kernel errors
check_system() {
  local os uptime_s load1 errs
  os=$(run_cmd "cat /etc/os-release 2>/dev/null | awk -F= '/^PRETTY_NAME=/{gsub("\"","",$2); print $2}' || uname -a") || true
  uptime_s=$(run_cmd "uptime -p 2>/dev/null || uptime") || true
  load1=$(run_cmd "uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs") || true

  if is_numeric "$load1" && gt "$load1" "$LOAD_THRESHOLD"; then
    add_finding "WARN" "System Load" "1-min load ${load1} exceeds threshold ${LOAD_THRESHOLD}"
  else
    add_finding "OK" "System Load" "1-min load is ${load1:-unknown}"
  fi

  errs=$(run_cmd "dmesg | grep -i 'error' | tail -n 5 | wc -l") || errs=0
  if is_numeric "$errs" && [[ "$errs" -gt 0 ]]; then
    add_finding "INFO" "Kernel Messages" "Recent kernel errors present (last 5 lines matched): ${errs}"
  else
    add_finding "OK" "Kernel Messages" "No recent kernel errors"
  fi

  add_finding "INFO" "OS" "${os:-unknown}; ${uptime_s:-uptime unknown}"
}

register_check "system" "System basics and load" check_system 1
