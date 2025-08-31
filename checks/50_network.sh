# Basic network connectivity and ports
check_network() {
  if run_cmd "ping -c 2 -W 2 8.8.8.8 >/dev/null"; then
    add_finding "OK" "Network Connectivity" "Ping to 8.8.8.8 OK"
  else
    add_finding "WARN" "Network Connectivity" "Ping to 8.8.8.8 failed"
  fi

  local open
  open=$(run_cmd "ss -tuln 2>/dev/null | wc -l || netstat -tuln 2>/dev/null | wc -l") || open="0"
  add_finding "INFO" "Open Listening Sockets" "$open entries (ss/netstat)"
}

register_check "network" "Network connectivity and ports" check_network 1
