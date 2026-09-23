#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# test/direnv/run.sh — exercise home/direnv/lib/onepassword.sh through the REAL
# direnv binary, with only the `op` CLI stubbed out.
#
# Nothing is mocked except the vault: direnv parses the .envrc, sources
# lib/*.sh, renders the cache and diffs the environment exactly as it does on
# a laptop. That is the point — the bugs this file exists to catch (a cache
# that never hits, a strict_env abort, a value mangled by quoting) all live in
# that integration, not in the functions read in isolation.
#
#   ./test/direnv/run.sh [path/to/onepassword.sh]
#
# Defaults to the in-repo copy; pass ~/.config/direnv/lib/onepassword.sh to
# test what home-manager actually installed.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="${1:-$REPO_ROOT/home/direnv/lib/onepassword.sh}"
STUB="$REPO_ROOT/test/direnv/op-stub.sh"

[[ -f $LIB ]] || {
  echo "no such lib: $LIB" >&2
  exit 1
}
command -v direnv >/dev/null || {
  echo "direnv not on PATH" >&2
  exit 1
}

# ── assertions ───────────────────────────────────────────────────────────────
fails=0
ok() { printf '  \033[0;32m✔\033[0m %s\n' "$1"; }
bad() {
  printf '  \033[0;31m✖\033[0m %s\n' "$1"
  fails=$((fails + 1))
  [[ $# -gt 1 ]] && printf '%s\n' "$2" | sed 's/^/        /'
  return 0
}
assert_eq() { # <desc> <expected> <actual>
  if [[ $2 == "$3" ]]; then ok "$1"; else bad "$1" "expected: [$2]
  actual: [$3]"; fi
}
assert_contains() { # <desc> <needle> <haystack>
  case "$3" in
  *"$2"*) ok "$1" ;;
  *) bad "$1" "expected to contain: $2
  actual: $3" ;;
  esac
}
assert_not_contains() { # <desc> <needle> <haystack>
  case "$3" in
  *"$2"*) bad "$1" "should NOT contain: $2
  actual: $3" ;;
  *) ok "$1" ;;
  esac
}

# ── sandbox ──────────────────────────────────────────────────────────────────
# A direnv inherited from the caller's shell would leak DIRENV_* state into
# every `direnv exec` below and silently skip re-evaluation.
for v in $(env | sed -n 's/^\(DIRENV_[A-Z_]*\)=.*/\1/p'); do unset "$v"; done
unset OP_ENV_CACHE_TTL_MINUTES direnv_layout_dir

# pwd -P, not the raw mktemp output: on macOS $TMPDIR ends in a slash and is
# itself a symlink, and direnv keys its allow-list on the CANONICAL path — an
# un-normalised ROOT makes every `direnv allow` here silently miss.
ROOT="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/direnv-op-test.XXXXXX")" && pwd -P)"
trap 'rm -rf "$ROOT"' EXIT

export XDG_CONFIG_HOME="$ROOT/config"
export XDG_DATA_HOME="$ROOT/data"
export XDG_CACHE_HOME="$ROOT/cache"
mkdir -p "$XDG_CONFIG_HOME/direnv/lib" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$ROOT/bin"
cp "$LIB" "$XDG_CONFIG_HOME/direnv/lib/onepassword.sh"
cp "$STUB" "$ROOT/bin/op"
chmod +x "$ROOT/bin/op"

export OP_CALL_LOG="$ROOT/op-calls.log"
: >"$OP_CALL_LOG"
PATH_WITH_OP="$ROOT/bin:$PATH"

# The "op is missing" cases need a PATH with genuinely no op on it — and the
# machine running these tests almost certainly HAS one installed, so simply
# dropping $ROOT/bin proves nothing. Build a shim directory holding just the
# tools a .envrc evaluation needs, and use that alone.
mkdir -p "$ROOT/shim"
for t in bash sh env direnv sed grep egrep mktemp mkdir chmod mv rm cat date wc \
  head tail ls find tr cut sleep dirname basename touch uname awk stat cp ln test; do
  src="$(command -v "$t" 2>/dev/null)" && ln -sf "$src" "$ROOT/shim/$t"
done
PATH_WITHOUT_OP="$ROOT/shim"
if PATH="$PATH_WITHOUT_OP" command -v op >/dev/null 2>&1; then
  echo "FATAL: op leaked into the op-less PATH" >&2
  exit 1
fi
PATH="$PATH_WITHOUT_OP" command -v direnv >/dev/null || {
  echo "FATAL: direnv missing from the shim PATH" >&2
  exit 1
}

PROJ=""   # current project dir
STDOUT="" # last run's stdout (the resulting environment)
STDERR="" # last run's stderr (direnv's log lines)

new_project() { # new_project <name> [envrc-body]
  PROJ="$ROOT/$1"
  mkdir -p "$PROJ"
  cat >"$PROJ/.env.tpl" <<'TPL'
API_TOKEN=op://dev/api/token
DB_URL=op://dev/db/url
WITH_SPACES=op://dev/misc/phrase
PLAIN=not-a-secret
TPL
  printf '%s\n' "${2:-use_onepassword}" >"$PROJ/.envrc"
  direnv allow "$PROJ" >/dev/null || {
    echo "FATAL: direnv allow failed for $PROJ" >&2
    exit 1
  }
}

# run <PATH-to-use> [op-stub-mode] — evaluate the project's .envrc and publish
# the result in $STDOUT / $STDERR. Deliberately NOT a command substitution:
# $( ) forks, and a fork cannot hand $STDERR back to the assertions.
run() {
  local use_path="$1" mode="${2:-ok}"
  PATH="$use_path" OP_STUB_MODE="$mode" \
    direnv exec "$PROJ" env >"$ROOT/stdout.txt" 2>"$ROOT/stderr.txt"
  STDOUT="$(cat "$ROOT/stdout.txt")"
  STDERR="$(cat "$ROOT/stderr.txt")"
}

op_calls() { # how many times the stub was invoked since the last reset
  local n
  n="$(wc -l <"$OP_CALL_LOG" 2>/dev/null)" || n=0
  echo "${n// /}"
}
reset_calls() { : >"$OP_CALL_LOG"; }
cache_of() { echo "$PROJ/.direnv/op-env.cache"; }
perms_of() { # stat(1) is BSD/GNU-divergent; ask ls and normalise
  # shellcheck disable=SC2012  # every path here is ours, all alphanumeric
  ls -l "$1" 2>/dev/null | cut -c1-10
}
ls_glob() { # ls_glob <glob…> — matching paths, space-separated, empty if none
  local f out=""
  for f in "$@"; do [[ -e $f ]] && out+="${out:+ }$f"; done
  printf '%s' "$out"
}

echo "══ lib under test: $LIB ══"

echo "══ 1. cold render ══"
new_project cold
run "$PATH_WITH_OP"
assert_contains "API_TOKEN exported" "API_TOKEN=s3cr3t" "$STDOUT"
assert_contains "non-secret line survives" "PLAIN=not-a-secret" "$STDOUT"
assert_eq "op invoked exactly once" "1" "$(op_calls)"
assert_contains "logs the render" "loaded 4 secret(s) from .env.tpl" "$STDERR"
assert_eq "cache is 0600" "-rw-------" "$(perms_of "$(cache_of)")"
assert_contains "cache carries a versioned header" "# op-env v1 keys=4 ts=" "$(head -1 "$(cache_of)")"
assert_contains "header records the source template" "tpl=.env.tpl" "$(head -1 "$(cache_of)")"
assert_not_contains "cache holds no unrendered op:// refs" "op://" "$(cat "$(cache_of)")"

echo "══ 2. warm cache — the whole point ══"
reset_calls
run "$PATH_WITH_OP"
assert_eq "op NOT invoked again" "0" "$(op_calls)"
assert_contains "vars still exported" "API_TOKEN=s3cr3t" "$STDOUT"
assert_contains "logs a cache hit" "from cache (no prompt)" "$STDERR"

echo "══ 3. idempotence: a cache hit rewrites nothing ══"
before="$(cat "$(cache_of)")"
run "$PATH_WITH_OP"
assert_eq "cache byte-identical after re-entry" "$before" "$(cat "$(cache_of)")"
assert_eq "only the cache lives in .direnv" "$(cache_of)" "$(ls_glob "$PROJ"/.direnv/op-env*)"

echo "══ 4. template edit busts the cache ══"
reset_calls
sleep 1 # mtime granularity: -nt needs a strictly newer template
echo 'EXTRA=op://dev/api/extra' >>"$PROJ/.env.tpl"
run "$PATH_WITH_OP"
assert_eq "op re-invoked" "1" "$(op_calls)"
assert_contains "new key present" "EXTRA=s3cr3t" "$STDOUT"
assert_contains "count updated" "loaded 5 secret(s)" "$STDERR"

echo "══ 5. TTL ══"
new_project ttl-zero 'export OP_ENV_CACHE_TTL_MINUTES=0
use_onepassword'
reset_calls
run "$PATH_WITH_OP"
run "$PATH_WITH_OP"
assert_eq "TTL=0 disables the cache (op each time)" "2" "$(op_calls)"

new_project ttl-lapsed
run "$PATH_WITH_OP"
sed -i.bak '1s/ts=[0-9]*/ts=1/' "$(cache_of)" && rm -f "$(cache_of).bak" # age it past the TTL
reset_calls
run "$PATH_WITH_OP"
assert_eq "expired cache re-renders" "1" "$(op_calls)"

new_project ttl-garbage 'export OP_ENV_CACHE_TTL_MINUTES=eight-hours
use_onepassword'
run "$PATH_WITH_OP"
assert_contains "non-numeric TTL is rejected, not arithmetic-eval'd" "is not a whole number" "$STDERR"
assert_contains "and secrets still load" "API_TOKEN=s3cr3t" "$STDOUT"

echo "══ 6. degradation — a broken vault must never break the shell ══"
new_project no-op-no-cache
run "$PATH_WITHOUT_OP"
assert_contains "missing op warns" "op CLI not on PATH" "$STDERR"
assert_not_contains "and exports nothing" "API_TOKEN=" "$STDOUT"
assert_contains "shell env is otherwise intact" "PATH=" "$STDOUT"

# expire_cache — age the current project's cache past any TTL. The stale-cache
# paths below are only reachable once the cache has lapsed; with a fresh one
# the lib (correctly) never consults op at all.
expire_cache() { sed -i.bak '1s/ts=[0-9]*/ts=1/' "$(cache_of)" && rm -f "$(cache_of).bak"; }

new_project no-op-with-cache
run "$PATH_WITH_OP"
expire_cache
run "$PATH_WITHOUT_OP"
assert_contains "stale cache beats an empty env" "API_TOKEN=s3cr3t" "$STDOUT"
assert_contains "and says so loudly" "using STALE cache (4 secret(s))" "$STDERR"

new_project op-fails
run "$PATH_WITH_OP"
expire_cache
run "$PATH_WITH_OP" fail
assert_contains "locked vault falls back to cache" "API_TOKEN=s3cr3t" "$STDOUT"
assert_contains "and surfaces op's own message" "authorization prompt dismissed" "$STDERR"

new_project op-fails-cold
reset_calls
run "$PATH_WITH_OP" fail
assert_contains "cold failure is soft" "secrets NOT loaded" "$STDERR"
assert_not_contains "nothing exported" "API_TOKEN=" "$STDOUT"
assert_eq "no cache or debris written on failure" "" "$(ls_glob "$PROJ"/.direnv/op-env*)"

new_project no-template 'use_onepassword .env.missing'
run "$PATH_WITH_OP"
assert_contains "absent template warns and continues" "no .env.missing in" "$STDERR"
assert_contains "shell survives" "PATH=" "$STDOUT"

echo "══ 7. a foreign/corrupt cache is never sourced ══"
new_project corrupt
run "$PATH_WITH_OP"
printf 'export PWNED=1\n' >"$(cache_of)"
reset_calls
run "$PATH_WITH_OP"
assert_eq "unrecognised header forces a re-render" "1" "$(op_calls)"
assert_not_contains "payload never evaluated" "PWNED=1" "$STDOUT"

echo "══ 7b. one cache file, two templates ══"
# Both calls resolve to the same <layout>/op-env.cache. Without the tpl= guard
# the second silently inherits the first one's environment.
new_project two-templates 'use_onepassword .env.a
use_onepassword .env.b'
printf 'FROM_A=op://dev/a/x\n' >"$PROJ/.env.a"
printf 'FROM_B=op://dev/b/x\n' >"$PROJ/.env.b"
reset_calls
run "$PATH_WITH_OP"
assert_contains "first template's key present" "FROM_A=s3cr3t" "$STDOUT"
assert_contains "second template's key present" "FROM_B=s3cr3t" "$STDOUT"
assert_eq "each template rendered on its own" "2" "$(op_calls)"

echo "══ 8. value fidelity through the dotenv round-trip ══"
new_project quoting
cat >"$PROJ/.env.tpl" <<'TPL'
SPACED="hello world"
APOSTROPHE="it's fine"
DOLLAR='$HOME-literal'
EQUALS=a=b=c
HASHY="trailing # not a comment"
TPL
sleep 1
run "$PATH_WITH_OP"
assert_contains "spaces survive" "SPACED=hello world" "$STDOUT"
assert_contains "apostrophes survive" "APOSTROPHE=it's fine" "$STDOUT"
# shellcheck disable=SC2016  # the literal '$HOME' is exactly what we assert on
assert_contains 'no premature $ expansion' 'DOLLAR=$HOME-literal' "$STDOUT"
assert_contains "embedded = survives" "EQUALS=a=b=c" "$STDOUT"
assert_contains "# inside a quoted value is not a comment" "HASHY=trailing # not a comment" "$STDOUT"
run "$PATH_WITH_OP"
assert_contains "and identically from cache" "APOSTROPHE=it's fine" "$STDOUT"

# dotenv rejects a bare value containing spaces. The lib must report that as a
# render failure rather than eval'ing direnv's error text.
new_project unparseable
printf 'BROKEN=no quotes here\n' >"$PROJ/.env.tpl"
sleep 1
run "$PATH_WITH_OP"
assert_contains "an unparseable render fails soft" "parse of rendered .env.tpl failed" "$STDERR"
assert_eq "and writes no cache" "" "$(ls_glob "$PROJ"/.direnv/op-env*)"
assert_contains "shell survives" "PATH=" "$STDOUT"

echo "══ 9. strict_env (errexit/nounset/pipefail) ══"
new_project strict 'strict_env
use_onepassword'
run "$PATH_WITH_OP"
assert_contains "renders under strict_env" "API_TOKEN=s3cr3t" "$STDOUT"
run "$PATH_WITH_OP"
assert_contains "cache hit under strict_env" "API_TOKEN=s3cr3t" "$STDOUT"
expire_cache
run "$PATH_WITHOUT_OP"
assert_contains "stale path under strict_env" "API_TOKEN=s3cr3t" "$STDOUT"
assert_contains "and logs the staleness" "using STALE cache" "$STDERR"

new_project strict-cold 'strict_env
use_onepassword'
run "$PATH_WITHOUT_OP"
assert_contains "cold soft-fail under strict_env" "op CLI not on PATH" "$STDERR"
assert_contains "shell survives" "PATH=" "$STDOUT"

new_project strict-missing-tpl 'strict_env
use_onepassword .env.missing'
run "$PATH_WITH_OP"
assert_contains "missing template under strict_env" "no .env.missing in" "$STDERR"
assert_contains "shell survives" "PATH=" "$STDOUT"

echo "══ 10. direnv_layout_dir override is honoured ══"
new_project layout "export direnv_layout_dir=\"$ROOT/layout-elsewhere\"
use_onepassword"
run "$PATH_WITH_OP"
assert_eq "cache follows the layout dir" "-rw-------" "$(perms_of "$ROOT/layout-elsewhere/op-env.cache")"
assert_eq "and not .direnv/" "" "$(ls_glob "$PROJ"/.direnv/op-env*)"

echo "══ 11. use_onepassword_file ══"
new_project files 'use_onepassword_file op://dev/connect/credentials.json secrets/connect.json'
reset_calls
run "$PATH_WITH_OP"
assert_contains "file materialized" "BEGIN FAKE KEY" "$(cat "$PROJ/secrets/connect.json" 2>/dev/null)"
assert_eq "file is 0600" "-rw-------" "$(perms_of "$PROJ/secrets/connect.json")"
assert_eq "op invoked once" "1" "$(op_calls)"
reset_calls
run "$PATH_WITH_OP"
assert_eq "existing file is a cache hit" "0" "$(op_calls)"

: >"$PROJ/secrets/connect.json"
reset_calls
run "$PATH_WITH_OP"
assert_eq "a 0-byte file is NOT a cache hit" "1" "$(op_calls)"
assert_contains "and is refilled" "BEGIN FAKE KEY" "$(cat "$PROJ/secrets/connect.json")"

new_project files-fail 'use_onepassword_file op://dev/connect/credentials.json secrets/connect.json'
run "$PATH_WITH_OP" fail
assert_eq "failed read leaves NO partial file" "" "$(ls_glob "$PROJ"/secrets/connect.json)"
assert_contains "and reports why" "op read failed" "$STDERR"
assert_eq "no temp debris in the dest dir" "" "$(ls_glob "$PROJ"/secrets/.op-file.*)"

new_project files-empty 'use_onepassword_file op://dev/connect/credentials.json secrets/connect.json'
run "$PATH_WITH_OP" empty
assert_eq "a 0-byte render is treated as failure" "" "$(ls_glob "$PROJ"/secrets/connect.json)"
assert_contains "and is named as such, not as a read error" "read back empty" "$STDERR"

new_project files-bare 'use_onepassword_file op://dev/connect/credentials.json connect.json'
run "$PATH_WITH_OP"
assert_contains "a dest with no directory works" "BEGIN FAKE KEY" "$(cat "$PROJ/connect.json" 2>/dev/null)"

new_project files-badargs 'use_onepassword_file op://dev/connect/credentials.json'
run "$PATH_WITH_OP"
assert_contains "missing dest is a usage error, not a crash" "usage: use_onepassword_file" "$STDERR"
assert_contains "shell survives" "PATH=" "$STDOUT"

new_project files-no-op 'use_onepassword_file op://dev/connect/credentials.json secrets/connect.json'
run "$PATH_WITHOUT_OP"
assert_contains "missing op warns" "op CLI not on PATH" "$STDERR"
assert_contains "shell survives" "PATH=" "$STDOUT"

echo "══ 12. concurrency: parallel entries never source a half-written cache ══"
new_project concurrent
reset_calls
racer_pids=()
for _ in 1 2 3 4 5; do
  # shellcheck disable=SC2016  # $API_TOKEN must expand in the child, not here
  PATH="$PATH_WITH_OP" direnv exec "$PROJ" sh -c 'test -n "$API_TOKEN"' 2>/dev/null &
  racer_pids+=($!)
done
racers_failed=0
for pid in "${racer_pids[@]}"; do wait "$pid" || racers_failed=$((racers_failed + 1)); done
assert_eq "5 concurrent evaluations all resolved API_TOKEN" "0" "$racers_failed"
assert_eq "exactly one op-env artifact remains" "$(cache_of)" "$(ls_glob "$PROJ"/.direnv/op-env*)"

echo
if [[ $fails -eq 0 ]]; then
  printf '\033[0;32m══ ALL DIRENV TESTS PASSED ══\033[0m\n'
else
  printf '\033[0;31m══ %d DIRENV TEST(S) FAILED ══\033[0m\n' "$fails"
fi
exit "$fails"
