# Firewall and MAC (SELinux/AppArmor) status
check_sec_stack() {
  local fw="none" fw_state="unknown" sel="none" sel_state="unknown"

  if run_cmd "command -v ufw >/dev/null"; then
    fw="ufw"
    fw_state=$(run_cmd "ufw status 2>/dev/null | awk 'NR==1{print $2}'") || fw_state="unknown"
  elif run_cmd "command -v firewall-cmd >/dev/null"; then
    fw="firewalld"
    fw_state=$(run_cmd "firewall-cmd --state 2>/dev/null") || fw_state="unknown"
  elif run_cmd "command -v nft >/dev/null"; then
    fw="nftables"
    fw_state=$(run_cmd "nft list ruleset 2>/dev/null | wc -l") || fw_state="0"
  elif run_cmd "command -v iptables >/dev/null"; then
    fw="iptables"
    fw_state=$(run_cmd "iptables -S 2>/dev/null | wc -l") || fw_state="0"
  fi

  if run_cmd "command -v getenforce >/dev/null"; then
    sel="SELinux"; sel_state=$(run_cmd "getenforce 2>/dev/null") || sel_state="unknown"
  elif run_cmd "command -v sestatus >/dev/null"; then
    sel="SELinux"; sel_state=$(run_cmd "sestatus 2>/dev/null | awk -F: '/status:/ {gsub(/ /,""); print $2}'") || sel_state="unknown"
  elif run_cmd "command -v aa-status >/dev/null"; then
    sel="AppArmor"; sel_state=$(run_cmd "aa-status --enabled >/dev/null && echo enabled || echo disabled") || sel_state="unknown"
  fi

  # Firewall finding
  case "$fw" in
    ufw) [[ "$fw_state" == "active" ]] && add_finding "OK" "Firewall (ufw)" "active" || add_finding "INFO" "Firewall (ufw)" "inactive";;
    firewalld) [[ "$fw_state" == "running" ]] && add_finding "OK" "Firewall (firewalld)" "running" || add_finding "INFO" "Firewall (firewalld)" "not running";;
    nftables|iptables) [[ "$fw_state" =~ ^[0-9]+$ && "$fw_state" -gt 0 ]] && add_finding "INFO" "Firewall ($fw)" "$fw_state rules present" || add_finding "INFO" "Firewall ($fw)" "no rules";;
    *) add_finding "INFO" "Firewall" "No firewall tool detected";;
  esac

  # SELinux/AppArmor finding
  if [[ "$sel" == "SELinux" ]]; then
    case "$sel_state" in
      Enforcing|enforcing) add_finding "OK" "SELinux" "Enforcing";;
      Permissive|permissive) add_finding "INFO" "SELinux" "Permissive";;
      Disabled|disabled) add_finding "INFO" "SELinux" "Disabled";;
      *) add_finding "INFO" "SELinux" "$sel_state";;
    esac
  elif [[ "$sel" == "AppArmor" ]]; then
    [[ "$sel_state" == "enabled" ]] && add_finding "OK" "AppArmor" "Enabled" || add_finding "INFO" "AppArmor" "Disabled"
  else
    add_finding "INFO" "MAC" "No SELinux/AppArmor detected"
  fi
}

register_check "sec_stack" "Firewall and SELinux/AppArmor" check_sec_stack 1
