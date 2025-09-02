# Hardware/Storage health overview
check_hardware() {
  # RAID (md)
  if run_cmd "test -f /proc/mdstat"; then
    local md
    md=$(run_cmd "grep -E '^(md|unused devices:)' /proc/mdstat | sed 's/^/mdstat: '") || md=""
    if [[ -n "$md" && "$md" != "mdstat: unused devices: <none>" ]]; then
      add_finding "INFO" "MD RAID" "$md"
    else
      add_finding "OK" "MD RAID" "No arrays or all clean"
    fi
  fi

  # LVM
  if run_cmd "command -v lvs >/dev/null"; then
    local lvh
    lvh=$(run_cmd "lvs --noheadings -o lv_name,lv_attr,lv_health_status 2>/dev/null | sed 's/^/  '") || lvh=""
    if [[ -n "$lvh" ]]; then
      add_finding "INFO" "LVM" $'Detected LVs:\n'"$lvh"
    else
      add_finding "OK" "LVM" "No LVs detected"
    fi
  fi

  # SMART quick health (requires smartctl) - fix for RHEL/Fedora
  if run_cmd "command -v smartctl >/dev/null"; then
    local disks out bad=0
    # Separate lsblk options for RHEL compatibility
    disks=$(run_cmd "lsblk -n -d -o NAME,TYPE | awk '\$2=="disk"{print \$1}'") || disks=""
    while read -r d; do
      [[ -z "$d" ]] && continue
      # Fix awk quoting for SMART check
      out=$(run_cmd "smartctl -H /dev/$d 2>/dev/null | awk -F: '/SMART overall-health self-assessment test result/ {print \$2}' | xargs") || out=""
      if [[ "$out" =~ (PASSED|OK) ]]; then :; else bad=$((bad+1)); fi
    done <<< "$disks"
    if [[ "$bad" -gt 0 ]]; then
      add_finding "WARN" "SMART Health" "$bad disk(s) reported non-OK"
    else
      add_finding "OK" "SMART Health" "All detected disks OK or SMART unavailable"
    fi
  else
    add_finding "INFO" "SMART" "smartctl not installed"
  fi
}

register_check "hardware" "RAID/LVM/SMART summary" check_hardware 1
