#!/usr/bin/env bash
# git-guard.sh — the PreToolUse gate that blocks destructive git operations.
#
# WHY THIS SUITE EXISTS
#   git-guard is the only automated thing standing between an agent and
#   `git reset --hard`. An audit (2026-10-22) found it was bypassable a dozen
#   ways — short flags, reordered flags, the `--` disambiguator, a decoy
#   --force-with-lease — and that it FAILED OPEN on any jq parse error. Every
#   bypass found then is a case below.
#
#   The guard's contract, in one line: exit 2 = blocked, exit 0 = allowed, and
#   anything it cannot parse is blocked, not waved through.
#
# USAGE
#   ./test/git-guard/run.sh [path-to-git-guard.sh]
# Defaults to the repo copy; pass the installed path to test what is live.
set -uo pipefail

GUARD="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/dotfiles/claude/hooks/git-guard.sh}"

if [ ! -x "$GUARD" ]; then
  printf '\033[0;31m✖ no executable guard at %s\033[0m\n' "$GUARD" >&2
  exit 1
fi

fails=0
ok() { printf '  \033[0;32m✔\033[0m %s\n' "$1"; }
bad() {
  printf '  \033[0;31m✖\033[0m %s\n' "$1"
  fails=$((fails + 1))
}

# Build the PreToolUse envelope the way Claude Code does, via jq so that
# quotes/backslashes in the command under test cannot break the JSON.
envelope() { jq -n --arg c "$1" '{tool_name:"Bash", tool_input:{command:$c}}'; }

ERRFILE=$(mktemp)
GUARD_ERR=""

# status <json> -> echoes the guard's exit status; stderr lands in $GUARD_ERR
status() {
  printf '%s' "$1" | "$GUARD" >/dev/null 2>"$ERRFILE"
  local st=$?
  GUARD_ERR=$(cat "$ERRFILE")
  printf '%s' "$st"
}

# blocked <desc> <command>  — expects exit 2
blocked() {
  local desc="$1" cmd="$2" st
  st=$(status "$(envelope "$cmd")")
  if [ "$st" = "2" ]; then
    ok "$desc"
  else
    bad "$desc — expected exit 2, got $st  [$cmd]"
  fi
}

# allowed <desc> <command>  — expects exit 0
allowed() {
  local desc="$1" cmd="$2" st
  st=$(status "$(envelope "$cmd")")
  if [ "$st" = "0" ]; then
    ok "$desc"
  else
    bad "$desc — expected exit 0, got $st  [$cmd]  stderr: $GUARD_ERR"
  fi
}

# raw_blocked <desc> <stdin>  — malformed input, bypassing the envelope builder
raw_blocked() {
  local desc="$1" st
  printf '%s' "$2" | "$GUARD" >/dev/null 2>&1
  st=$?
  if [ "$st" = "2" ]; then
    ok "$desc"
  else
    bad "$desc — expected exit 2, got $st"
  fi
}

echo "══ guard under test: $GUARD ══"

echo "══ 1. reset --hard, including abbreviated long flags ══"
blocked "git reset --hard" 'git reset --hard'
blocked "git reset --hard HEAD~1" 'git reset --hard HEAD~1'
blocked "abbreviated --har" 'git reset --har'
blocked "abbreviated --ha" 'git reset --ha'
allowed "--soft is not destructive" 'git reset --soft HEAD~1'
allowed "bare reset (mixed) keeps the worktree" 'git reset HEAD~1'

echo "══ 2. force push — short flags, decoys, and force refspecs ══"
blocked "--force" 'git push --force'
blocked "-f short flag" 'git push -f origin main'
blocked "--force-with-lease decoy alongside a real --force" 'git push --force-with-lease --force origin main'
blocked "force refspec (+)" 'git push origin +main:main'
allowed "--force-with-lease alone is the safe form" 'git push --force-with-lease origin main'
allowed "--force-with-lease=ref" 'git push --force-with-lease=main origin main'
allowed "--force-if-includes" 'git push --force-if-includes origin main'
allowed "plain push" 'git push origin main'

echo "══ 3. clean — flag clusters in any order, and the long form ══"
blocked "clean -fd" 'git clean -fd'
blocked "clean -df (reordered)" 'git clean -df'
blocked "clean -xdf (cluster)" 'git clean -xdf'
blocked "clean --force -d (long form)" 'git clean --force -d'
blocked "clean -f" 'git clean -f'
allowed "clean -n is a dry run" 'git clean -n'
allowed "clean --dry-run" 'git clean --dry-run'

echo "══ 4. branch deletion — flag after the name, and long equivalents ══"
blocked "branch -D foo" 'git branch -D foo'
blocked "branch foo -D (flag after name)" 'git branch foo -D'
blocked "branch --delete --force foo" 'git branch --delete --force foo'
blocked "branch -d --force foo" 'git branch -d --force foo'
allowed "branch -d alone refuses unmerged work" 'git branch -d merged-branch'
allowed "plain branch listing" 'git branch'

echo "══ 5. checkout/restore . — the -- disambiguator must not defeat it ══"
blocked "checkout ." 'git checkout .'
blocked "checkout -- . (disambiguated)" 'git checkout -- .'
blocked "restore ." 'git restore .'
blocked "restore -- . (disambiguated)" 'git restore -- .'
allowed "checkout a branch" 'git checkout main'
allowed "checkout -b" 'git checkout -b feature/x'
allowed "restore one named file" 'git restore --staged README.md'

echo "══ 6. stash drop/clear ══"
blocked "stash drop" 'git stash drop'
blocked "stash clear" 'git stash clear'
allowed "stash list" 'git stash list'
allowed "stash push" 'git stash push -u'

echo "══ 7. history/ref destruction the old guard never attempted ══"
blocked "reflog expire" 'git reflog expire --all --expire=now'
blocked "gc --prune=now" 'git gc --prune=now'
blocked "tag -d" 'git tag -d v1.0.0'
blocked "tag --delete" 'git tag --delete v1.0.0'
blocked "filter-branch" 'git filter-branch --tree-filter cleanup HEAD'
blocked "filter-repo" 'git filter-repo --path secrets --invert-paths'
blocked "worktree remove --force" 'git worktree remove --force ../wt'
blocked "update-ref -d" 'git update-ref -d refs/heads/main'
blocked "remote branch delete via refspec" 'git push origin :main'
blocked "remote branch delete via --delete" 'git push --delete origin main'
blocked "rm -rf .git" 'rm -rf .git'
allowed "reflog show is read-only" 'git reflog show'
allowed "plain gc" 'git gc'
allowed "tag listing" 'git tag -l'

echo "══ 8. the command is not always the first token ══"
blocked "after && chaining" 'echo hi && git reset --hard'
blocked "after ; chaining" 'cd /tmp; git reset --hard'
blocked "after || chaining" 'false || git clean -fd'
blocked "piped into a chain" 'git log | head && git reset --hard'
blocked "env assignment prefix" 'GIT_DIR=/tmp/x git reset --hard'
blocked "sudo prefix" 'sudo git reset --hard'
blocked "git -C <dir> before subcommand" 'git -C /tmp/repo reset --hard'
blocked "git -c key=val before subcommand" 'git -c core.pager=cat reset --hard'
blocked "absolute path to git" '/usr/bin/git reset --hard'
allowed "merely mentioning it in a string" 'echo "never run git reset --hard"'
allowed "a git-adjacent word" 'gitk --all'

echo "══ 9. unparseable input must FAIL CLOSED (the old hook exited 0) ══"
raw_blocked "malformed JSON is blocked" 'not json at all'
raw_blocked "truncated JSON is blocked" '{"tool_input":{"command":'
raw_blocked "empty stdin is blocked" ''
# A well-formed envelope with no command is NOT an error — other tools match too.
allowed "valid JSON with an empty command" ''

echo "══ 10. commit policy: attribution in the MESSAGE, never in paths ══"
blocked "Co-Authored-By" 'git commit -m "feat: thing

Co-Authored-By: Someone <a@b.c>"'
blocked "attribution in prose" 'git commit -m "made by the assistant claude"'
blocked "vendor name in prose" 'git commit -m "anthropic wrote this"'
blocked "ai-generated" 'git commit -m "ai-generated patch"'
blocked "attribution hidden in a slash-shaped token" 'git commit -m "fix via claude.ai/opus"'
allowed "a path that merely contains the word" 'git commit -m "refactor home/claude.nix seeding"'
allowed "a clean message" 'git commit -m "fix: bound the mach send"'
allowed "commit with no -m at all" 'git commit --amend --no-edit'

echo "══ 10b. config paths and scopes are not attribution ══"
# This repo MANAGES Claude Code, so its own files and commit scopes name it
# constantly. A guard that blocks `feat(claude):` blocks this repo's own
# convention (see commit f8d974b) — naming a config path is not attribution.
allowed "conventional-commit scope" 'git commit -m "feat(claude): manage the observer config"'
allowed "scope with a breaking marker" 'git commit -m "fix(claude)!: drop the settings sync"'
allowed "a dotfile directory in prose" 'git commit -m "fix: update .claude hooks"'
allowed "a bare filename with an extension" 'git commit -m "refactor claude.nix seeding"'
allowed "a nested config path" 'git commit -m "move dotfiles/claude/settings.json"'
allowed "staging the .claude folder" 'git add .claude/settings.json'
allowed "staging a managed claude path" 'git add dotfiles/claude/hooks/git-guard.sh'
allowed "diffing the claude folder" 'git diff -- dotfiles/claude/'
allowed "checkout of a scoped claude path" 'git checkout .claude/settings.json'
# …while real prose attribution still goes nowhere.
blocked "bare word attribution still blocked" 'git commit -m "made by claude"'

echo "══ 11. commit policy: -F message files ══"
MSGDIR=$(mktemp -d)
trap 'rm -rf "$MSGDIR" "$ERRFILE"' EXIT
printf 'fix: a perfectly clean message\n' >"$MSGDIR/clean.txt"
printf 'feat: x\n\nCo-Authored-By: Someone <a@b.c>\n' >"$MSGDIR/coauthor.txt"
printf 'written by claude\n' >"$MSGDIR/attributed.txt"
allowed "-F with a clean message file" "git commit -F $MSGDIR/clean.txt"
blocked "-F file containing Co-Authored-By" "git commit -F $MSGDIR/coauthor.txt"
blocked "-F file containing attribution" "git commit -F $MSGDIR/attributed.txt"
# The regression the guard's own comments describe: the PATH contains the word
# but the message is clean, so this must pass.
mkdir -p "$MSGDIR/claude-501"
printf 'fix: unrelated clean message\n' >"$MSGDIR/claude-501/msg.txt"
allowed "-F under a path containing 'claude', clean message" "git commit -F $MSGDIR/claude-501/msg.txt"

echo
if [ "$fails" -eq 0 ]; then
  printf '\033[0;32m══ ALL GIT-GUARD TESTS PASSED ══\033[0m\n'
else
  printf '\033[0;31m══ %d GIT-GUARD TEST(S) FAILED ══\033[0m\n' "$fails"
fi
[ "$fails" -eq 0 ]
