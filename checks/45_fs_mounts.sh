# Check all mounts for usage and RO flags
: "${DISK_ALL_THRESHOLD:=85}"

check_fs_mounts() {
  local lines mp fstype opts used warn=0
  # Filter only common local FS types - fix awk quoting
  lines=$(run_cmd "awk '\$3 ~ /(ext[234]|xfs|btrfs|zfs)/ {print \$2" "\$3" "\$4}' /proc/mounts | sort -u") || true
  while read -r mp fstype opts; do
    [[ -z "$mp" ]] && continue
    used=$(run_cmd "df -P \"$mp\" | awk 'END{gsub("%","",\$5); print \$5}'") || used=""
    [[ -z "$used" ]] && continue
    if [[ "$opts" == *",ro,"* || "$opts" == ro,* || "$opts" == *,ro ]]; then
      add_finding "CRIT" "Filesystem Read-Only" "$mp ($fstype) is mounted read-only"
      warn=1
    fi
    if [[ "$used" =~ ^[0-9]+$ && "$used" -ge "$DISK_ALL_THRESHOLD" ]]; then
      add_finding "WARN" "High Disk Usage" "$mp ($fstype) at ${used}% >= ${DISK_ALL_THRESHOLD}%"
      warn=1
    fi
  done <<< "$lines"

  if [[ "$warn" -eq 0 ]]; then
    add_finding "OK" "All Mounts" "No read-only mounts and all below ${DISK_ALL_THRESHOLD}%"
  fi
}

register_check "fs_mounts" "All filesystem mounts usage/flags" check_fs_mounts 1
