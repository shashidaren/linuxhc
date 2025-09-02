#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${BASE_DIR}/config/healthcheck.conf"
CHECKS_DIR="${BASE_DIR}/checks"
LIB_DIR="${BASE_DIR}/lib"

# Defaults (can be overridden by config)
OUTPUT_FORMAT="text"   # text|json
SERVER_LIST=()

# Load common library
source "${LIB_DIR}/common.sh"

# Load config if present
if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
fi

usage() {
  cat <<EOF
Usage: $0 [-s server] [-f server_file] [-o text|json] [-h]
  -s server        Single server to check (default: localhost)
  -f server_file   File with newline-separated list of servers
  -o format        Output format: text or json (default: text)
  -h               Show this help
EOF
  exit 1
}

# Parse args
while getopts ":s:f:o:h" opt; do
  case ${opt} in
    s) SERVER_LIST+=("$OPTARG") ;;
    f)
      [[ -f "$OPTARG" ]] || { echo "Server file not found: $OPTARG" >&2; exit 1; }
      while IFS= read -r host; do
        [[ -n "$host" ]] && SERVER_LIST+=("$host")
      done < "$OPTARG"
      ;;
    o) OUTPUT_FORMAT="$OPTARG" ;;
    h) usage ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
    :)  echo "Option -$OPTARG requires an argument." >&2; usage ;;
  esac
done

# Default localhost if none provided
if [[ ${#SERVER_LIST[@]} -eq 0 ]]; then
  SERVER_LIST=("localhost")
fi

# Discover and load checks (each check registers itself)
load_checks_from_dir "${CHECKS_DIR}"

# Validate enabled checks list, if provided
resolve_enabled_checks

echo "Starting healthchecks for: ${SERVER_LIST[*]}"

# Run per-server
ALL_REPORTS_JSON="["  # for json output assembly

for TARGET in "${SERVER_LIST[@]}"; do
  reset_findings

  # Run each enabled check
  for idx in "${!CHECK_IDS[@]}"; do
    check_id="${CHECK_IDS[$idx]}"
    check_title="${CHECK_TITLES[$idx]}"
    check_func="${CHECK_FUNCS[$idx]}"
    enabled="${CHECK_ENABLED[$idx]}"

    if [[ "$enabled" != "1" ]]; then
      continue
    fi

    # Run one check safely
    if declare -F "$check_func" >/dev/null 2>&1; then
      # Expose TARGET to checks and call
      if ! "$check_func"; then
        add_finding "WARN" "$check_id: $check_title" "Check function returned non-zero (continuing)."
      fi
    else
      add_finding "WARN" "$check_id: $check_title" "Check function not found."
    fi
  done

  # Emit per-server output
  case "$OUTPUT_FORMAT" in
    json)
      SERVER_JSON=$(findings_to_json "$TARGET")
      # Append to array
      if [[ "$ALL_REPORTS_JSON" != "[" ]]; then
        ALL_REPORTS_JSON+=",";
      fi
      ALL_REPORTS_JSON+="$SERVER_JSON"
      ;;
    text|*)
      echo ""
      echo "=== Report for $TARGET ==="
      print_findings_text
      echo "Summary: $(summary_line)"
      ;;
  esac

done

# Finalize JSON
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  ALL_REPORTS_JSON+="]"
  echo "$ALL_REPORTS_JSON"
fi
