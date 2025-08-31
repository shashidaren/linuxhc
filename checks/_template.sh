# Template: copy to NN_mycheck.sh and implement check_mycheck()
check_mycheck() {
  # Use run_cmd "..." to run commands on $TARGET (local or SSH).
  # Add findings with one of: OK, INFO, WARN, CRIT
  # Example:
  local val
  val=$(run_cmd "echo 100") || true

  if is_numeric "$val" && gt "$val" "123"; then
    add_finding "WARN" "My Check Title" "Value $val exceeds 123"
  else
    add_finding "OK" "My Check Title" "Value is ${val:-unknown}"
  fi
}

register_check "mycheck" "Short description of my check" check_mycheck 0
