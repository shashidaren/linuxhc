# Disk and inode usage on root; read-only fs check
check_disk() {
  local du iu
  du=$(run_cmd "df -P / | awk 'END{gsub("%","",$5); print $5}'") || true
  if is_numeric "$du" && [[ "$du" -gt "$DISK_THRESHOLD" ]]; then
    add_finding "WARN" "Disk Usage (/)" "/ usage ${du}% > ${DISK_THRESHOLD}%"
  else
    add_finding "OK" "Disk Usage (/)" "/ usage ${du:-unknown}%"
  fi

  iu=$(run_cmd "df -Pi / | awk 'END{gsub("%","",$5); print $5}'") || true
  if is_numeric "$iu" && [[ "$iu" -gt "$INODE_THRESHOLD" ]]; then
    add_finding "WARN" "Inode Usage (/)" "Inodes ${iu}% > ${INODE_THRESHOLD}%"
  else
    add_finding "OK" "Inode Usage (/)" "Inodes ${iu:-unknown}%"
  fi

  # Read-only check
  if run_cmd "touch /tmp/hc_ro_test && rm -f /tmp/hc_ro_test"; then
    add_finding "OK" "Filesystem Read/Write" "Writable"
  else
    add_finding "CRIT" "Filesystem Read/Write" "Appears read-only (touch failed)"
  fi
}

register_check "disk" "Disk and inode usage" check_disk 1
