# ANSI
RESET="\e[0m"
GREEN="\e[32m"
RED="\e[31m"
BOLD="\e[1m"

# Use a temp file to accumulate output — no arrays, no traps
# This is a workaround for the fact that direnv is loading
# snapshots of the env after this is run, and applying it
# to the parent shell env.  So we cant pass 'channel' like
# objects.  This is needed so direnv can unload a env
__env_table_log_file="/tmp/direnv_env_table_$$.log"

echo "Catalyst direnv export_utils loaded"
echo "Temp env table log file: $__env_table_log_file"

begin_env() {
  echo -e "ENV_VAR\tVALUE\tSTATUS" > "$__env_table_log_file"
}

begin_env

export_var() {
  local name=$1 value=$2


  # if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
  #   log_error "Invalid variable name: $name"
  #   echo -e "$name\t$value\tINVALID NAME" >> "$__env_table_log_file"
  #   return 1
  # fi

  export "$name=$value"

  # Check if the value contains "prod" or "production"
  if [[ "$value" =~ prod|production ]]; then
    # SHow a small little flag if it looks like a prod value
    echo -e "$name\t$value\t⚠️  PROD" >> "$__env_table_log_file"
  elif [[ -n $(printenv "$name") ]]; then
    # Normal success case
    echo -e "$name\t$value\t${GREEN}✅${RESET}" >> "$__env_table_log_file"
  else
    # Failure case
    echo -e "$name\t$value\t${RED}❌${RESET}" >> "$__env_table_log_file"
  fi
}

export_var_dir() {
  local name=$1 dir=$2
  if [[ ! -d "$dir" ]]; then
    echo -e "$name\t$dir\t${RED}❌ MISSING${RESET}" >> "$__env_table_log_file"
    return 1
  fi

  export_var "$name" "$dir"
}

export_dir = export_var_dir

end_env() {
  # Maybe we also sort the table???
  # Sort by the first column (name)
  sort -k1,1 "$__env_table_log_file" > "$__env_table_log_file.sorted"
  echo
  column -t -s $'\t' "$__env_table_log_file.sorted"
  echo
  rm -f "$__env_table_log_file.sorted"
}

# Also trap doesnt work here, because this is a subshell
# and the trap will not be inherited by the parent shell
# So we need to call this manually
# trap 'end_env' EXIT