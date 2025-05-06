#!/usr/bin/env bash
set -euo pipefail

DEBUG_ENV_UTILS=${DEBUG_ENV_UTILS:-0}
ENABLE_COLORS=${ENABLE_COLORS:-1}
MEASURE_ENV_UTILS_PERF=${MEASURE_ENV_UTILS_PERF:-0}

if ! JSON_TOOL=$(command -v jq); then
  echo "jq is required" >&2
  exit 1
fi

# ANSI colors
if [[ "$ENABLE_COLORS" == "1" ]]; then
  RESET="\033[0m"; GREEN="\033[32m"; RED="\033[31m"; BOLD="\033[1m"; YELLOW="\033[33m"
else
  RESET=""; GREEN=""; RED=""; BOLD=""; YELLOW=""
fi

debug_log() {
  if [[ "$DEBUG_ENV_UTILS" == "1" ]]; then
    printf "%b\n" "${BOLD}[debug]${RESET} $*" 1>&2
  fi
}

measure() {
  local label=$1
  shift

  if [[ "${MEASURE_ENV_UTILS_PERF:-0}" == "1" ]]; then
    local start end duration

    start=$(perl -MTime::HiRes=time -e 'printf("%.0f\n", time * 1000)')
    "$@"
    local result=$?
    end=$(perl -MTime::HiRes=time -e 'printf("%.0f\n", time * 1000)')
    duration=$((end - start))

    printf "%b\n" "${YELLOW}[perf]${RESET} ${label}: ${duration}ms" >&2
    return $result
  else
    "$@"
  fi
}


__env_json_file="/tmp/direnv_env_table_$$.json"
debug_log "Catalyst direnv export_utils loaded"
debug_log "Temp JSON env file: $__env_json_file"

begin_env() {
  debug_log "Initializing JSON env table"
  printf '[]' > "$__env_json_file"
}

begin_env

write_json() {
  local jq_filter=$1
  shift
  measure "write_json" "$JSON_TOOL" "$jq_filter" "$@" > "$__env_json_file.tmp" \
    && mv "$__env_json_file.tmp" "$__env_json_file"
}

export_var() {
  local name=$1 value=$2 origin=${3:-envrc}
  debug_log "Exporting var: $name=$value (origin=$origin)"
  export "$name=$value"

  local status="✅"
  [[ "$value" =~ prod|production ]] && status="⚠️ PROD"

  measure "export_var.mark:$name" write_json --arg nm "$name" \
    'map(if .name == $nm then . + {overwritten: true} else . end)' "$__env_json_file"

  measure "export_var.add:$name" write_json -c --arg orig "$origin" --arg nm "$name" --arg val "$value" --arg st "$status" \
    '. += [{origin: $orig, name: $nm, value: $val, status: $st, overwritten: false}]' "$__env_json_file"
}

export_dir() {
  local name=$1 dir=$2 origin=${3:-envrc}
  debug_log "Checking directory: $dir"

  if [[ ! -d "$dir" ]]; then
    export_var "$name" "$dir" "$origin"
    measure "export_dir.status:$name" write_json -c --arg nm "$name" \
      '(.[] | select(.name == $nm)) |= . + {status: "❌ MISSING"}' "$__env_json_file"
    return 1
  fi

  export_var "$name" "$dir" "$origin"
}

end_env() {
  debug_log "Finalizing env table from JSON"
  echo

  # Step 1: Build clean tabular output with overwrite flag
  local rows
  rows=$(
    "$JSON_TOOL" -r '
      sort_by(.name, .overwritten)[] |
      [.status, .origin, .name, .value, (if .overwritten then "1" else "0" end)] |
      @tsv
    ' "$__env_json_file"
  )

  # Step 2: Pipe to column and post-process
  echo "$rows" | column -t -s $'\t' | while IFS= read -r line; do
    if [[ "$line" =~ [[:space:]]1$ ]]; then
      # Remove the '1' marker and dim the full line
      printf "\033[2m%s\033[0m\n" "${line% 1}"
    else
      # Remove the '0' marker and print normally
      echo "${line% 0}"
    fi
  done

  rm -f "$__env_json_file"
  echo
}

# -----------------------------------------------------------------------------
# Function: dotenv_if_exists
#
# Description:
#   Checks for the presence of a dotenv file and, if found, exports its defined
#   environment variables into the current shell session.
#
# Usage:
#   dotenv_if_exists [path_to_dotenv]
#
# Parameters:
#   path_to_dotenv (optional):
#     The file path to the dotenv file. If not provided, a default ".env" file
#     in the current directory is assumed.
#
# Returns:
#   The function exports environment variables if the specified dotenv file exists.
# -----------------------------------------------------------------------------
dotenv_if_exists() {
  local path="${1:-$PWD/.env}"
  [[ -d "$path" ]] && path="$path/.env"

  debug_log "Looking for dotenv at: $path"
  watch_file "$path"
  [[ -f "$path" ]] || return 0

  local exports
  exports="$("$direnv" dotenv bash "$@")" || return 1

  local IFS=';'
  for segment in $exports; do
    segment="${segment#"${segment%%[![:space:]]*}"}"
    segment="${segment%"${segment##*[![:space:]]}"}"
    [[ $segment == export* ]] && segment=${segment#export }

    if [[ $segment =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      local name="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"
      [[ $value =~ ^\$\'(.*)\'$ ]] && value="${BASH_REMATCH[1]}"
      export_var "$name" "$value" "dotenv"
    fi
  done
  unset IFS

  eval "$exports"
}
