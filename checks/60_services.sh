# Critical services and time sync
check_services() {
  # cron vs crond mapping (Fedora/RHEL use crond)
  local services=()
  for svc in $CRITICAL_SERVICES; do
    if [[ "$svc" == "cron" ]]; then
      if run_cmd "systemctl list-unit-files | grep -q '^crond\.service'"; then
        services+=("crond")
      else
        services+=("cron")
      fi
    else
      services+=("$svc")
    fi
  done

  local missing=()
  for s in "${services[@]}"; do
    if [[ "$(run_cmd "systemctl is-active "$s" 2>/dev/null" || true)" != "active" ]]; then
      missing+=("$s")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    add_finding "WARN" "Critical Services" "Not running: ${missing[*]}"
  else
    add_finding "OK" "Critical Services" "All OK (${services[*]})"
  fi

  # Time sync
  local synced
  synced=$(run_cmd "timedatectl show -p NTPSynchronized --value 2>/dev/null" || true)
  if [[ "$synced" == "yes" ]]; then
    add_finding "OK" "Time Sync" "NTP synchronized"
  else
    add_finding "INFO" "Time Sync" "Not synchronized (timedatectl or NTP configuration)"
  fi
}

register_check "services" "Critical services and NTP" check_services 1
