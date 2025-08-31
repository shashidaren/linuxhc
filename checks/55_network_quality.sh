# Network quality indicators
: "${NET_ERR_THRESHOLD:=10}"

check_network_quality() {
  # Default route
  if run_cmd "ip route | grep -q '^default'"; then
    add_finding "OK" "Default Route" "Present"
  else
    add_finding "CRIT" "Default Route" "Missing"
  fi

  # DNS resolution
  if run_cmd "getent hosts google.com >/dev/null"; then
    add_finding "OK" "DNS Resolution" "google.com resolves"
  else
    add_finding "WARN" "DNS Resolution" "google.com failed to resolve"
  fi

  # RX/TX errors (non-loopback)
  local sumerr=0
  local errs
  errs=$(run_cmd "ip -s link | awk '/^[0-9]+: /{iface=$2; gsub(":","",iface)} /RX:/{getline; rxerr=$3} /TX:/{getline; txerr=$3; if (iface!="lo") print rxerr+txerr}'") || errs=""
  if [[ -n "$errs" ]]; then
    while read -r n; do
      [[ "$n" =~ ^[0-9]+$ ]] && ((sumerr+=n))
    done <<< "$errs"
  fi
  if [[ "$sumerr" -gt 0 ]]; then
    local sev="INFO"
    [[ "$sumerr" -ge "$NET_ERR_THRESHOLD" ]] && sev="WARN"
    add_finding "$sev" "Interface Errors" "Aggregate RX/TX errors: $sumerr"
  else
    add_finding "OK" "Interface Errors" "No RX/TX errors"
  fi
}

register_check "net_quality" "Network quality and DNS" check_network_quality 1
