# Memory tuning details
check_memory_detail() {
  local swp thp
  swp=$(run_cmd "cat /proc/sys/vm/swappiness 2>/dev/null") || swp=""
  if [[ "$swp" =~ ^[0-9]+$ ]]; then
    add_finding "INFO" "Swappiness" "$swp"
  else
    add_finding "INFO" "Swappiness" "Unknown"
  fi

  thp=$(run_cmd "cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null") || thp=""
  if [[ -n "$thp" ]]; then
    add_finding "INFO" "Transparent Hugepages" "$thp"
  else
    add_finding "INFO" "Transparent Hugepages" "Not available"
  fi
}

register_check "mem_detail" "Swappiness and THP status" check_memory_detail 1
