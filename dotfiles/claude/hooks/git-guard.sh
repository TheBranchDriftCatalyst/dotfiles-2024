#!/usr/bin/env bash
# Git safety guard — blocks destructive git commands and enforces commit policy.
# Reads PreToolUse JSON from stdin (matcher: Bash). exit 2 = blocked, 0 = allowed.
#
# DESIGN: parse, don't substring-match.
#
# The previous version grepped the raw command string for literals like
# "git reset --hard" and "git clean -fd". An audit (2026-10-22) found a dozen
# bypasses, all of which came from the same root cause — a substring needs its
# bytes adjacent and spelled exactly one way, while git accepts flags in any
# order, clustered, abbreviated, and after positionals:
#
#   git push -f …                 no "--force" substring
#   git clean -df …               "-fd" reversed
#   git branch foo -D             flag after the name
#   git checkout -- .             "--" between verb and "."
#   git reset --har               an unambiguous abbreviation
#   git push --force-with-lease --force    decoy matched the safe branch first
#
# So this version tokenizes the command into segments, finds each git
# invocation, resolves the subcommand past global options, and then asks
# flag-shaped questions of the argument list. Adding a destructive verb is now
# a line in a case statement rather than a new set of string spellings.
#
# It also FAILS CLOSED. The old hook exited 0 when jq could not parse stdin,
# which silently waived every check on malformed input; unparseable input is
# now blocked. See test/git-guard/run.sh — every bypass above is a case there.
set -uo pipefail

JQ=$(command -v jq 2>/dev/null || true)
[ -n "$JQ" ] || JQ=/usr/bin/jq

block() {
  echo "BLOCKED: $1 Ask the user for explicit confirmation before running this command." >&2
  exit 2
}

INPUT=$(cat)

# ── fail closed ─────────────────────────────────────────────────────────────
# Anything we cannot read is refused, not waved through.
if [ -z "${INPUT//[[:space:]]/}" ]; then
  block "git-guard received empty input and cannot verify this command is safe."
fi
if [ ! -x "$JQ" ]; then
  block "git-guard cannot find jq and cannot verify this command is safe."
fi
if ! COMMAND=$(printf '%s' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null); then
  block "git-guard could not parse the tool input and cannot verify this command is safe."
fi

# A well-formed envelope with no command is not an error — the Bash matcher
# also sees calls that carry no command string.
[ -n "$COMMAND" ] || exit 0

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ── destructive-operation scan ──────────────────────────────────────────────
# Split into segments on every shell construct that can start a new command,
# so `a && git reset --hard`, `$(git clean -fd)` and `x; git …` are each seen.
SEGMENTS=$(printf '%s' "$COMMAND" |
  sed -E 's/\$\(/\n/g; s/`/\n/g; s/&&/\n/g; s/\|\|/\n/g; s/\|/\n/g; s/;/\n/g; s/\)/\n/g; s/\{/\n/g; s/\}/\n/g')

ARGS=()
POS=()

# A short cluster carrying $1, e.g. -f in `-xdf`. Double-dash args are skipped.
has_short() {
  local want="$1" a rest
  for a in ${ARGS[@]+"${ARGS[@]}"}; do
    case "$a" in
    --*) continue ;;
    -*)
      rest="${a#-}"
      case "$rest" in *"$want"*) return 0 ;; esac
      ;;
    esac
  done
  return 1
}

# A long option for $1, accepting git's unambiguous abbreviations (--har for
# --hard). $2.. are safe spellings that must NOT count (--force-with-lease).
has_long() {
  local canon="$1" a base skip ex matched=""
  shift
  for a in ${ARGS[@]+"${ARGS[@]}"}; do
    case "$a" in --*) ;; *) continue ;; esac
    base="${a%%=*}"
    skip=0
    for ex in "$@"; do
      # A safe spelling wins only when the arg is at least as long as the
      # dangerous flag, so `--force` itself can never be excused by them.
      if [ "${#base}" -gt "${#canon}" ] && [ "${ex:0:${#base}}" = "$base" ]; then
        skip=1
      fi
    done
    [ "$skip" -eq 1 ] && continue
    # >=3 chars means at least --X; git itself rejects a truly ambiguous prefix,
    # and blocking one it would have rejected anyway costs nothing.
    if [ "${#base}" -ge 3 ] && [ "${canon:0:${#base}}" = "$base" ]; then
      matched=1
    fi
  done
  [ -n "$matched" ]
}

# Positional arguments only: flags dropped, everything after `--` kept.
positionals() {
  local a seen_ddash=0
  POS=()
  for a in ${ARGS[@]+"${ARGS[@]}"}; do
    if [ "$seen_ddash" -eq 0 ] && [ "$a" = "--" ]; then
      seen_ddash=1
      continue
    fi
    if [ "$seen_ddash" -eq 0 ]; then
      case "$a" in -*) continue ;; esac
    fi
    POS+=("$a")
  done
}

has_positional() {
  local want="$1" p
  positionals
  for p in ${POS[@]+"${POS[@]}"}; do
    [ "$p" = "$want" ] && return 0
  done
  return 1
}

while IFS= read -r segment; do
  [ -n "${segment//[[:space:]]/}" ] || continue
  read -ra TOKS <<<"$segment"
  [ "${#TOKS[@]}" -gt 0 ] || continue

  # Peel wrappers and env assignments off the front: `sudo git …`,
  # `GIT_DIR=x git …`, `env -i git …`, `time git …`.
  while [ "${#TOKS[@]}" -gt 0 ]; do
    case "${TOKS[0]}" in
    *=*) TOKS=("${TOKS[@]:1}") ;;
    sudo | doas | env | time | nice | nohup | command | builtin | exec | xargs | then | do | else | if)
      TOKS=("${TOKS[@]:1}")
      ;;
    -*) TOKS=("${TOKS[@]:1}") ;;
    *) break ;;
    esac
  done
  [ "${#TOKS[@]}" -gt 0 ] || continue

  prog=$(lower "${TOKS[0]##*/}")

  # `rm -rf .git` destroys the repository without involving git at all.
  if [ "$prog" = "rm" ]; then
    ARGS=("${TOKS[@]:1}")
    if has_short r && has_short f; then
      positionals
      for p in ${POS[@]+"${POS[@]}"}; do
        case "$p" in
        .git | ./.git | .git/* | */.git) block "Removing the git repository ('rm -rf $p')." ;;
        esac
      done
    fi
    continue
  fi

  [ "$prog" = "git" ] || continue

  # Resolve the subcommand past git's global options, some of which take a
  # separate argument (`git -C dir reset --hard`, `git -c k=v reset --hard`).
  i=1
  while [ "$i" -lt "${#TOKS[@]}" ]; do
    case "${TOKS[i]}" in
    -C | -c | --git-dir | --work-tree | --namespace | --exec-path | --config-env)
      i=$((i + 2))
      ;;
    -*) i=$((i + 1)) ;;
    *) break ;;
    esac
  done
  sub=$(lower "${TOKS[i]:-}")
  [ -n "$sub" ] || continue
  ARGS=("${TOKS[@]:i+1}")

  case "$sub" in
  reset)
    has_long --hard && block "Destructive git command ('reset --hard' discards uncommitted work)."
    ;;
  push)
    # --force-with-lease / --force-if-includes are the safe forms and must not
    # excuse a bare --force appearing alongside them.
    if has_short f || has_long --force --force-with-lease --force-if-includes; then
      block "Destructive git command ('force push' can overwrite remote history)."
    fi
    has_long --delete && block "Destructive git command ('push --delete' removes a remote branch)."
    for a in ${ARGS[@]+"${ARGS[@]}"}; do
      case "$a" in
      +*) block "Destructive git command (a '+' refspec forces the push)." ;;
      :?*) block "Destructive git command (a ':ref' refspec deletes a remote branch)." ;;
      esac
    done
    ;;
  clean)
    if has_short f || has_long --force; then
      block "Destructive git command ('clean -f' deletes untracked files)."
    fi
    ;;
  branch)
    if has_short D; then
      block "Destructive git command ('branch -D' force-deletes a branch)."
    fi
    if (has_short d || has_long --delete) && has_long --force; then
      block "Destructive git command ('branch --delete --force')."
    fi
    ;;
  checkout | restore)
    if has_positional . || has_positional ./ || has_positional '*'; then
      block "Destructive git command ('$sub .' discards all uncommitted changes)."
    fi
    ;;
  stash)
    case "$(lower "${ARGS[0]:-}")" in
    drop) block "Destructive git command ('stash drop' deletes a stash entry)." ;;
    clear) block "Destructive git command ('stash clear' deletes every stash entry)." ;;
    esac
    ;;
  reflog)
    case "$(lower "${ARGS[0]:-}")" in
    expire) block "Destructive git command ('reflog expire' destroys recovery history)." ;;
    delete) block "Destructive git command ('reflog delete' destroys recovery history)." ;;
    esac
    ;;
  gc)
    has_long --prune && block "Destructive git command ('gc --prune' can drop unreachable objects permanently)."
    ;;
  tag)
    if has_short d || has_long --delete; then
      block "Destructive git command ('tag --delete' removes a tag)."
    fi
    ;;
  update-ref)
    has_short d && block "Destructive git command ('update-ref -d' deletes a ref)."
    ;;
  worktree)
    if [ "$(lower "${ARGS[0]:-}")" = "remove" ] && { has_short f || has_long --force; }; then
      block "Destructive git command ('worktree remove --force' discards worktree changes)."
    fi
    ;;
  filter-branch | filter-repo)
    block "Destructive git command ('$sub' rewrites history irreversibly)."
    ;;
  esac
done <<<"$SEGMENTS"

# ── commit message policy ───────────────────────────────────────────────────
if printf '%s' "$COMMAND" | grep -qE '(^|[[:space:]])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'; then
  COMMIT_MSG=""

  # -F/--file: read the real message out of the file. Doing this FIRST (and
  # never falling back to the command line when it succeeds) is what keeps a
  # scratchpad path like /tmp/claude-501/msg.txt from being mistaken for the
  # message itself.
  MSG_FILE=$(printf '%s' "$COMMAND" |
    grep -oE -- '(-F|--file)[[:space:]]*=?[[:space:]]*[^[:space:]]+' |
    head -1 |
    sed -E 's/^(-F|--file)[[:space:]]*=?[[:space:]]*//' |
    tr -d '"'\''')
  if [ -n "$MSG_FILE" ] && [ -r "$MSG_FILE" ]; then
    COMMIT_MSG=$(cat "$MSG_FILE")
  fi

  # Otherwise inspect the command line. Path-shaped tokens are dropped before
  # the word check: prose attribution never hides inside a path, and a commit
  # touching home/claude.nix was previously refused for naming its own files.
  # Scanning the whole command (rather than a regex-extracted -m argument) is
  # what catches a multi-line body — the old extraction stopped at the first
  # quote and so missed a trailing Co-Authored-By entirely.
  if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="$COMMAND"
  fi

  # Reduce the message to PROSE before the word check. This repo manages Claude
  # Code itself, so its paths and commit scopes name it constantly and none of
  # that is attribution. Dropped, in order:
  #   - a conventional-commit header, so `feat(claude):` survives (f8d974b)
  #   - path-shaped tokens        dotfiles/claude/settings.json
  #   - dotfile/dotdir tokens     .claude
  #   - bare filenames            claude.nix
  # What remains is sentence text, which is the only place attribution lives.
  PROSE=$(printf '%s' "$COMMIT_MSG" |
    sed -E 's/(^|[[:space:]])[^[:alnum:][:space:]]*[a-zA-Z]+\([^)]*\)!?:/\1/g' |
    tr '[:space:]' '\n' |
    grep -v '/' |
    grep -v '^\.' |
    grep -viE '\.(nix|sh|bash|zsh|lua|c|h|py|js|ts|json|ya?ml|toml|md|txt|tpl|patch)$' |
    tr '\n' ' ')

  if printf '%s' "$COMMIT_MSG" | grep -qi 'co-authored-by'; then
    echo "BLOCKED: Do not add Co-Authored-By lines to commit messages." >&2
    exit 2
  fi
  # Vendor domains and the generated-with footer are checked against the RAW
  # message, because they are slash-shaped and the prose filter drops them —
  # that is the gap "fix via claude.ai/opus" walked through.
  if printf '%s' "$COMMIT_MSG" | grep -qiE 'claude\.ai|anthropic\.com|generated with'; then
    echo "BLOCKED: Do not mention Claude, Anthropic, or AI in commit messages." >&2
    exit 2
  fi
  if printf '%s' "$PROSE" | grep -qiE '(^|[^[:alnum:]])(claude|anthropic|ai.generated|ai.assisted)([^[:alnum:]]|$)'; then
    echo "BLOCKED: Do not mention Claude, Anthropic, or AI in commit messages." >&2
    exit 2
  fi
  echo "COMMIT POLICY: Write commit messages as if the developer wrote them. No AI attribution, no Co-Authored-By."
fi

exit 0
