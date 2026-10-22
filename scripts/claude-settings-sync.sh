#!/usr/bin/env bash
# Keep the repo's copy of ~/.claude/settings.json in step with the live one.
#
# OWNERSHIP: the app owns the live file. Not a preference — a consequence.
# Claude Code rewrites settings.json atomically (temp file, then rename over the
# target), and rename(2) replaces whatever sits at that path, symlink included.
# So the out-of-store symlink every other managed path uses (CLAUDE.md, agents/,
# commands/, hooks/ — all still live links) cannot survive here: it dies the
# first time the app records a permission, a plugin enable, or a plugin option.
#
# That was tried. home-manager then found a regular file where its link belonged
# and aborted a whole darwin switch at checkLinkTargets, blocked by a stale
# settings.json.hm-bak. Propping it up took force = true, a switch preflight and
# a relink step — four mechanisms defending a premise that was simply false.
#
# So nix no longer plants a link here. It SEEDS the file when absent (fresh
# machine) and otherwise leaves it alone, and this script carries the two
# directions explicitly:
#
#   sync            absorb app-side additions into the repo (default)
#   sync --quiet    same, silent unless it actually absorbed something;
#                   this is the Stop-hook form, and it is what keeps the repo
#                   from drifting behind the app between commits
#   sync --check    report only, non-zero if there is anything to absorb
#   sync --push     repo -> live, refusing while the live file has anything
#                   unabsorbed (the rare direction: hand-edited repo copy)
set -euo pipefail

# Overridable so the behaviour can be exercised against fixtures instead of the
# live config — this script's whole job is preventing data loss, so it has to be
# testable without risking the thing it protects.
# TODO: hate this fuckign file lets remove it withotu regressing back to the issue? 
LIVE="${CLAUDE_SETTINGS_LIVE:-$HOME/.claude/settings.json}"
REPO_FILE="${CLAUDE_SETTINGS_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/dotfiles/claude/settings.json}"

MODE=absorb
case "${1:-}" in
--check) MODE=check ;;
--quiet) MODE=quiet ;;
--push) MODE=push ;;
"") ;;
*)
  echo "claude-settings: unknown argument '$1'" >&2
  exit 2
  ;;
esac

say() { [ "$MODE" = quiet ] || echo "$@"; }

if [ ! -r "$REPO_FILE" ]; then
  echo "claude-settings: ✖ no repo copy at $REPO_FILE" >&2
  exit 1
fi

# ── repo -> live ───────────────────────────────────────────────────────────
if [ "$MODE" = push ]; then
  if [ -e "$LIVE" ] && [ -r "$LIVE" ] && jq -e . "$LIVE" >/dev/null 2>&1; then
    outstanding=$(jq -n --slurpfile l "$LIVE" --slurpfile r "$REPO_FILE" '
      ($l[0]) as $live | ($r[0]) as $repo |
      [ $live | paths(scalars) ] as $paths |
      [ $paths[] | . as $p | select( ($repo | getpath($p)) != ($live | getpath($p)) ) ] | length')
    if [ "$outstanding" -gt 0 ]; then
      echo "claude-settings: ✖ refusing to push — the live file has $outstanding value(s) the repo does not." >&2
      echo "  Run it without --push first to absorb them, or resolve by hand." >&2
      exit 1
    fi
  fi
  install -m 600 "$REPO_FILE" "$LIVE"
  say "claude-settings: pushed repo -> $LIVE"
  exit 0
fi

# ── live -> repo ───────────────────────────────────────────────────────────
if [ ! -e "$LIVE" ]; then
  say "claude-settings: no live settings.json — nothing to absorb"
  exit 0
fi

if ! jq -e . "$LIVE" >/dev/null 2>&1; then
  echo "claude-settings: ✖ live settings.json is not valid JSON — refusing to touch it" >&2
  exit 1
fi

# Leaf-by-leaf, not a whole-file diff: the app reorders keys freely (it rewrote
# the entire document on 2026-10-09 and moved autoMode), so a textual diff
# reports churn that means nothing. Only scalar leaves are compared.
report=$(jq -n --slurpfile l "$LIVE" --slurpfile r "$REPO_FILE" '
  ($l[0]) as $live | ($r[0]) as $repo |
  [ $live | paths(scalars) ] as $paths |
  {
    added:    [ $paths[] | . as $p | select( ($repo | getpath($p)) == null )
                | $p | join(".") ],
    conflict: [ $paths[] | . as $p | select( ($repo | getpath($p)) != null
                                   and ($repo | getpath($p)) != ($live | getpath($p)) )
                | $p | join(".") ]
  }')

n_added=$(printf '%s' "$report" | jq -r '.added | length')
n_conflict=$(printf '%s' "$report" | jq -r '.conflict | length')

if [ "$n_conflict" -gt 0 ]; then
  echo "claude-settings: ✖ $n_conflict setting(s) differ between the live file and the repo:" >&2
  printf '%s' "$report" | jq -r '.conflict[] | "    " + .' >&2
  echo "  Pick a winner by hand — this script will not guess which side is right." >&2
  exit 1
fi

if [ "$n_added" -eq 0 ]; then
  say "claude-settings: repo is in step with the live file"
  exit 0
fi

if [ "$MODE" = check ]; then
  echo "claude-settings: $n_added app-side addition(s) not yet in the repo:"
  printf '%s' "$report" | jq -r '.added[] | "    " + .'
  exit 1
fi

# repo is the base so repo-only keys survive; live wins on shared leaves, which
# are equal anyway (conflicts were refused above).
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
jq -s '.[0] * .[1]' "$REPO_FILE" "$LIVE" >"$tmp"
jq -e . "$tmp" >/dev/null
cat "$tmp" >"$REPO_FILE"
# Always printed, even under --quiet: a hook that silently edits a tracked file
# would be worse than noisy.
echo "claude-settings: absorbed $n_added app-side addition(s) into $REPO_FILE"
printf '%s' "$report" | jq -r '.added[] | "    " + .'
