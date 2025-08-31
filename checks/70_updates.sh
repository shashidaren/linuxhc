# Package update availability
check_updates() {
  local pm count=""
  if run_cmd "command -v apt >/dev/null"; then
    pm="apt"
    count=$(run_cmd "apt list --upgradable 2>/dev/null | grep -v '^Listing' | wc -l") || count=""
  elif run_cmd "command -v dnf >/dev/null"; then
    pm="dnf"
    count=$(run_cmd "dnf -q check-update | awk 'NF && $1 !~ /^(Last|Obsoleting)/ {c++} END{print c+0}'") || count=""
  elif run_cmd "command -v yum >/dev/null"; then
    pm="yum"
    count=$(run_cmd "yum -q check-update | awk 'NF && $1 !~ /^(Loaded|Obsoleting)/ {c++} END{print c+0}'") || count=""
  elif run_cmd "command -v zypper >/dev/null"; then
    pm="zypper"
    count=$(run_cmd "zypper -q lu | sed '1,2d' | wc -l") || count=""
  elif run_cmd "command -v pacman >/dev/null"; then
    pm="pacman"
    if run_cmd "command -v checkupdates >/dev/null"; then
      count=$(run_cmd "checkupdates 2>/dev/null | wc -l") || count=""
    else
      count=$(run_cmd "pacman -Sup 2>/dev/null | grep -cE '^http'") || count=""
    fi
  fi

  if [[ -z "$pm" ]]; then
    add_finding "INFO" "Updates" "Package manager not detected"
  elif [[ -n "$count" && "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]]; then
    add_finding "INFO" "Updates ($pm)" "$count updates available"
  else
    add_finding "OK" "Updates ($pm)" "No updates available or unable to enumerate"
  fi
}

register_check "updates" "OS updates available" check_updates 1
