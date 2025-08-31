# Memory and swap
check_memory() {
  local mem swap
  mem=$(run_cmd "free | awk '/Mem:/ {printf("%.2f", $3/$2*100)}'") || true
  if is_numeric "$mem" && gt "$mem" "$MEM_THRESHOLD"; then
    add_finding "WARN" "Memory Usage" "Memory ${mem}% > ${MEM_THRESHOLD}%"
  else
    add_finding "OK" "Memory Usage" "Memory ${mem:-unknown}%"
  fi

  swap=$(run_cmd "free | awk '/Swap:/ && $2>0 {printf("%.2f", $3/$2*100)}'") || true
  if [[ -z "$swap" ]]; then
    add_finding "INFO" "Swap Usage" "No swap configured"
  elif is_numeric "$swap" && gt "$swap" "$SWAP_THRESHOLD"; then
    add_finding "WARN" "Swap Usage" "Swap ${swap}% > ${SWAP_THRESHOLD}% (possible memory pressure)"
  else
    add_finding "OK" "Swap Usage" "Swap ${swap}%"
  fi
}

register_check "memory" "Memory and swap" check_memory 1
