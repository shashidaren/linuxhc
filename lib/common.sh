#!/usr/bin/env bash
# Common helpers and check registry

# Registry arrays
declare -a CHECK_IDS=()
declare -a CHECK_TITLES=()
declare -a CHECK_FUNCS=()
declare -a CHECK_ENABLED=()   # "1" or "0"

# Findings store (per server)
FINDINGS_STATUS=()
FINDINGS_TITLE=()
FINDINGS_MESSAGE=()

# Defaults/thresholds (may be overridden in config)
: "${CPU_THRESHOLD:=80}"
: "${MEM_THRESHOLD:=80}"
: "${SWAP_THRESHOLD:=50}"
: "${DISK_THRESHOLD:=80}"
: "${INODE_THRESHOLD:=90}"
: "${LOAD_THRESHOLD:=5}"
: "${CRITICAL_SERVICES:=sshd cron docker}"
: "${ENABLED_CHECKS:=}"   # space-separated IDs; empty means "all discovered checks"

# Helpers

# Register a check (called by each check file upon sourcing)
# args: id title func_name [default_enabled(1/0)]
register_check() {
  local id="$1" title="$2" func="$3" default_enabled="${4:-1}"
  CHECK_IDS+=("$id")
  CHECK_TITLES+=("$title")
  CHECK_FUNCS+=("$func")
  CHECK_ENABLED+=("$default_enabled")
}

# After all checks loaded, resolve ENABLED_CHECKS filter if provided
resolve_enabled_checks() {
  if [[ -z "$ENABLED_CHECKS" ]]; then
    return
  fi
  # Build a set of enabled ids
  for i in "${!CHECK_IDS[@]}"; do
    CHECK_ENABLED[$i]=0
  done
  for want in $ENABLED_CHECKS; do
    for i in "${!CHECK_IDS[@]}"; do
      if [[ "$want" == "${CHECK_IDS[$i]}" ]]; then
        CHECK_ENABLED[$i]=1
      fi
    done
  done
}

# Reset findings between servers
reset_findings() {
  FINDINGS_STATUS=()
  FINDINGS_TITLE=()
  FINDINGS_MESSAGE=()
}

# Add a finding (status: OK|INFO|WARN|CRIT)
add_finding() {
  local status="$1" title="$2" message="$3"
  FINDINGS_STATUS+=("$status")
  FINDINGS_TITLE+=("$title")
  FINDINGS_MESSAGE+=("$message")
}

# Numeric helpers
is_numeric() { [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; }
# returns 0 (true) if a>b, using awk for portability
gt() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>b)}'; }

# Safe remote/local command runner
# Use global $TARGET
run_cmd() {
  local cmd="$*"
  local out rc
  if [[ "${TARGET:-localhost}" == "localhost" ]]; then
    out=$(bash -lc "$cmd" 2>/dev/null); rc=$?
  else
    out=$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$TARGET" "bash -lc '$cmd'" 2>/dev/null); rc=$?
  fi
  if [[ $rc -ne 0 ]]; then
    # Print error to stderr but do not pollute variable values
    echo "run_cmd error on ${TARGET:-localhost}: $cmd" >&2
    return $rc
  fi
  printf "%s" "$out"
}

# Output helpers
severity_rank() {
  case "$1" in
    CRIT) echo 3 ;;
    WARN) echo 2 ;;
    INFO) echo 1 ;;
    OK|*) echo 0 ;;
  esac
}

summary_line() {
  local ok=0 info=0 warn=0 crit=0
  for s in "${FINDINGS_STATUS[@]}"; do
    case "$s" in
      CRIT) ((crit++)) ;;
      WARN) ((warn++)) ;;
      INFO) ((info++)) ;;
      OK)   ((ok++)) ;;
    esac
  done
  echo "OK=$ok INFO=$info WARN=$warn CRIT=$crit"
}

overall_status() {
  local max=0 r
  for s in "${FINDINGS_STATUS[@]}"; do
    r=$(severity_rank "$s")
    (( r > max )) && max=$r
  done
  case "$max" in
    3) echo "CRIT" ;;
    2) echo "WARN" ;;
    1) echo "INFO" ;;
    0) echo "OK" ;;
  esac
}

print_findings_text() {
  if [[ ${#FINDINGS_STATUS[@]} -eq 0 ]]; then
    echo "No findings (OK)."
    return
  fi
  for i in "${!FINDINGS_STATUS[@]}"; do
    printf "- [%s] %s: %s
" "${FINDINGS_STATUS[$i]}" "${FINDINGS_TITLE[$i]}" "${FINDINGS_MESSAGE[$i]}"
  done
}

json_escape() {
  python3 - <<'PY' "$1"
import json,sys
print(json.dumps(sys.argv[1]))
PY
}

findings_to_json() {
  local host="$1"
  local items=""
  for i in "${!FINDINGS_STATUS[@]}"; do
    local s="${FINDINGS_STATUS[$i]}"
    local t="${FINDINGS_TITLE[$i]}"
    local m="${FINDINGS_MESSAGE[$i]}"
    # Escape via Python (present on most systems); if not, you can swap to jq -R
    local te me
    te=$(json_escape "$t")
    me=$(json_escape "$m")
    local item="{"status":"$s","title":${te},"message":${me}}"
    if [[ -n "$items" ]]; then items+=",";
    fi
    items+="$item"
  done
  local status
  status=$(overall_status)
  echo "{"host":"$host","overall":"$status","summary":"$(summary_line)","findings":[${items}]}"
}

# Load all checks in a directory
load_checks_from_dir() {
  local d="$1"
  shopt -s nullglob
  for f in "$d"/*.sh; do
    # shellcheck disable=SC1090
    source "$f"
  done
  shopt -u nullglob
}
