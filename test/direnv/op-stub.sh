#!/usr/bin/env bash
# Stand-in for the `op` CLI. Every invocation is appended to $OP_CALL_LOG so
# tests can assert on the CACHE (op must not be called twice). Behaviour is
# driven by $OP_STUB_MODE:
#   ok      render/read succeed (default)
#   fail    exit 1 with a diagnostic on stderr, like a locked vault
#   empty   succeed but write nothing — the 0-byte-output trap
set -uo pipefail

printf '%s\n' "$*" >>"${OP_CALL_LOG:?op stub: OP_CALL_LOG unset}"

if [[ ${OP_STUB_MODE:-ok} == fail ]]; then
  echo "[ERROR] 2026/01/01 00:00:00 authorization prompt dismissed, please try again" >&2
  exit 1
fi

cmd="${1:-}"
shift || true

in_file="" out_file=""
while (($#)); do
  case "$1" in
  -i | --in-file)
    in_file="$2"
    shift 2
    ;;
  -o | --out-file)
    out_file="$2"
    shift 2
    ;;
  -f | --force | -n | --no-newline) shift ;;
  op://*)
    in_file="$1"
    shift
    ;;
  *) shift ;;
  esac
done

case "$cmd" in
inject)
  [[ -n $in_file && -n $out_file ]] || {
    echo "stub: inject needs -i and -o" >&2
    exit 2
  }
  if [[ ${OP_STUB_MODE:-ok} == empty ]]; then : >"$out_file"; else
    # op:// refs become a deterministic fake value; everything else passes through.
    sed -E 's#op://[^[:space:]"'"'"']+#s3cr3t#g' "$in_file" >"$out_file"
  fi
  # the real op echoes the output path on stdout
  printf '%s\n' "$out_file"
  ;;
read)
  [[ -n $out_file ]] || {
    echo "stub: read needs --out-file" >&2
    exit 2
  }
  if [[ ${OP_STUB_MODE:-ok} == empty ]]; then : >"$out_file"; else
    printf -- '-----BEGIN FAKE KEY-----\n%s\n' "$in_file" >"$out_file"
  fi
  ;;
*)
  echo "stub: unsupported op subcommand '$cmd'" >&2
  exit 2
  ;;
esac
