# CPU utilization
check_cpu() {
  local cpu_load=""

  # Prefer mpstat if available
  if run_cmd "command -v mpstat >/dev/null"; then
    cpu_load=$(run_cmd "mpstat 1 1 | awk '/all/ {print 100-\$NF}' | tail -n1") || true
  else
    # Use separate options for top and better awk quoting for RHEL/Fedora
    cpu_load=$(run_cmd "top -b -n 1 | awk -F'[, ]+' '/Cpu\(s\)/{for(i=1;i<=NF;i++) if(\$i=="id") {print 100-\$(i-1); break}}'") || true
    # Fallback simple parse with separated options
    [[ -z "$cpu_load" ]] && cpu_load=$(run_cmd "top -b -n 1 | grep 'Cpu(s)' | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{print 100-\$1}'") || true
  fi

  if is_numeric "$cpu_load" && gt "$cpu_load" "$CPU_THRESHOLD"; then
    add_finding "WARN" "CPU Usage" "CPU ${cpu_load}% > ${CPU_THRESHOLD}%"
  else
    add_finding "OK" "CPU Usage" "CPU ${cpu_load:-unknown}%"
  fi
}

register_check "cpu" "CPU usage" check_cpu 1
