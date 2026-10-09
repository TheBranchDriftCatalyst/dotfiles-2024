#!/usr/bin/env bash
# Reconcile ~/.claude/settings.json with the copy in this repo.
#
# WHY THIS EXISTS: every other path home/claude.nix manages (CLAUDE.md, agents/,
# commands/, hooks/) is an out-of-store symlink the app writes THROUGH, so edits
# land in the repo for free. settings.json is the exception, and not by choice:
# Claude Code rewrites it atomically — write a temp file, rename() over the
# target — and a rename REPLACES the symlink with a regular file. So the moment
# the app records a permission, a plugin enable, or a plugin option, the live
# link is gone and the repo stops seeing changes.
#
# That is why the file carries `force = true` in home/claude.nix: a switch must
# be able to re-establish the link without tripping over the regular file, and
# without home-manager's backup dance (a stale settings.json.hm-bak from
# 2026-09-06 is exactly what blocked the switch on 2026-10-09).
#
# force = true means the next switch OVERWRITES whatever the app wrote. This
# script is the other half of that bargain: it makes the loss impossible to
# suffer silently. Run it before switching — `just switch` does, in --check
# mode — and anything the app learned is either absorbed into the repo or
# reported as a conflict that a human resolves.
#
#   claude-settings-sync.sh            absorb app-side additions into the repo
#   claude-settings-sync.sh --check    report only, non-zero if action is needed
set -euo pipefail

# Overridable so the behaviour can be exercised against fixtures instead of the
# live config — this script's whole job is preventing data loss, so it has to be
# testable without risking the thing it protects.
LIVE="${CLAUDE_SETTINGS_LIVE:-$HOME/.claude/settings.json}"
REPO_FILE="${CLAUDE_SETTINGS_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/dotfiles/claude/settings.json}"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

if [ ! -e "$LIVE" ]; then
  echo "claude-settings: no live settings.json — nothing to reconcile"
  exit 0
fi

# A symlink means the app has not clobbered it since the last switch, so the
# live file IS the repo file and there is by definition nothing to absorb.
if [ -L "$LIVE" ]; then
  echo "claude-settings: live file is still a symlink — in sync"
  exit 0
fi

if ! jq -e . "$LIVE" >/dev/null 2>&1; then
  echo "claude-settings: ✖ live settings.json is not valid JSON — refusing to touch it" >&2
  exit 1
fi

# Leaf-by-leaf comparison, not a whole-file diff: the app reorders keys freely
# (it rewrote the whole document on 2026-10-09 and moved autoMode), so a textual
# diff reports churn that does not matter. Only scalar leaves are compared.
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
  echo "  The app and the repo disagree. Pick a winner by hand — this script will" >&2
  echo "  not guess, because a switch (force = true) would destroy the live value." >&2
  exit 1
fi

if [ "$n_added" -eq 0 ]; then
  echo "claude-settings: live file was clobbered to a regular file, but carries nothing new — a switch will relink it safely"
  exit 0
fi

echo "claude-settings: $n_added app-side addition(s) not yet in the repo:"
printf '%s' "$report" | jq -r '.added[] | "    " + .'

if [ "$CHECK" -eq 1 ]; then
  echo '  Run `just claude-sync` to absorb them, review the diff, and commit.' >&2
  echo "  Switching first would overwrite them (force = true)." >&2
  exit 1
fi

# repo is the base so repo-only keys survive; live wins on shared leaves, which
# are equal anyway (conflicts already refused above).
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
jq -s '.[0] * .[1]' "$REPO_FILE" "$LIVE" >"$tmp"
jq -e . "$tmp" >/dev/null
cat "$tmp" >"$REPO_FILE"
echo "claude-settings: absorbed into $REPO_FILE — review the diff and commit it"
