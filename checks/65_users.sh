# Users and auth
check_users_auth() {
  local sessions fails=0
  sessions=$(run_cmd "who | wc -l") || sessions=0
  add_finding "INFO" "Active Sessions" "$sessions"

  if run_cmd "command -v lastb >/dev/null"; then
    fails=$(run_cmd "lastb -n 50 2>/dev/null | wc -l") || fails=0
  else
    # journal fallback
    fails=$(run_cmd "journalctl -S -24h -g 'Failed password' --no-pager 2>/dev/null | wc -l") || fails=0
  fi

  if [[ "$fails" =~ ^[0-9]+$ && "$fails" -gt 0 ]]; then
    add_finding "INFO" "Failed Logins (24h)" "$fails"
  else
    add_finding "OK" "Failed Logins (24h)" "None"
  fi
}

register_check "users" "Sessions and failed login attempts" check_users_auth 1
