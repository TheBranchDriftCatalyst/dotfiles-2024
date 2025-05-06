#!/usr/bin/env bash
set -euo pipefail

# Load the export utilities to test
. "$(dirname "$0")/export_utils.sh"

# Cleanup temporary JSON files created during tests
cleanup() {
  rm -f "$__env_json_file" "$__env_json_file.tmp"
}
trap cleanup EXIT

test_begin_env() {
  begin_env
  if [[ "$(cat "$__env_json_file")" != "[]" ]]; then
    echo "FAIL: begin_env did not initialize JSON file to []"
    exit 1
  fi
}

test_export_var() {
  begin_env
  export_var TESTVAR "testvalue" "unittest"
  if [[ "${TESTVAR:-}" != "testvalue" ]]; then
    echo "FAIL: TESTVAR not exported correctly"
    exit 1
  fi

  count=$("$JSON_TOOL" -r --arg name "TESTVAR" 'map(select(.name == $name)) | length' "$__env_json_file")
  if [[ "$count" -ne 1 ]]; then
    echo "FAIL: Expected 1 JSON entry for TESTVAR, got $count"
    exit 1
  fi
}

test_export_dir() {
  begin_env
  # Test with a non-existent directory.
  if export_dir MISSING_DIR "/non/existent/path" "unittest"; then
    echo "FAIL: export_dir should return non-zero for missing directory"
    exit 1
  fi

  status=$("$JSON_TOOL" -r --arg name "MISSING_DIR" 'map(select(.name == $name))[0].status' "$__env_json_file")
  if [[ "$status" != "❌ MISSING" ]]; then
    echo "FAIL: export_dir did not mark missing directory correctly"
    exit 1
  fi

  # Test with an existent directory.
  begin_env
  if ! export_dir PWD_TEST "$PWD" "unittest"; then
    echo "FAIL: export_dir failed for valid directory"
    exit 1
  fi

  rec_value=$("$JSON_TOOL" -r --arg name "PWD_TEST" 'map(select(.name == $name))[0].value' "$__env_json_file")
  if [[ "$rec_value" != "$PWD" ]]; then
    echo "FAIL: export_dir did not record the current directory correctly"
    exit 1
  fi
}

test_end_env() {
  begin_env
  export_var TEST1 "value1" "unittest"
  export_var TEST2 "prod" "unittest"  # should mark with prod indicator

  output=$(end_env)
  if [[ -z "$output" ]]; then
    echo "FAIL: end_env did not produce any output"
    exit 1
  fi

  # Check that output contains exported variable names.
  if ! echo "$output" | grep -q "TEST1"; then
    echo "FAIL: end_env output missing TEST1"
    exit 1
  fi
  if ! echo "$output" | grep -q "TEST2"; then
    echo "FAIL: end_env output missing TEST2"
    exit 1
  fi
}

# Run tests sequentially.
test_begin_env
echo "test_begin_env passed"
test_export_var
echo "test_export_var passed"
test_export_dir
echo "test_export_dir passed"
test_end_env
echo "test_end_env passed"

exit 0