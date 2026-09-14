#!/usr/bin/env bash
# Claude Code status line — receives session JSON on stdin, prints ONE line.
# Nix-managed: lives in dotfiles/claude/hooks (claude.nix live-symlinks the
# hooks dir into ~/.claude), wired via settings.json "statusLine".
#
#   🌴 Fable ~/devspace/.catalyst-cli  bugfix/DEV-777/old-slug* 🎫 DEV-777 +42/-7 · $1.23
#
set -uo pipefail

in=$(cat)
command -v jq >/dev/null 2>&1 || { printf '🌴 Claude'; exit 0; }
j() { printf '%s' "$in" | jq -r "$1" 2>/dev/null; }

model=$(j '.model.display_name // .model.id // "Claude"')
raw_dir=$(j '.workspace.current_dir // .cwd // empty')
dir=${raw_dir/#$HOME/\~}
added=$(j '.cost.total_lines_added // 0')
removed=$(j '.cost.total_lines_removed // 0')
cost=$(j '.cost.total_cost_usd // 0')

git_seg="" ticket_seg=""
if [ -n "$raw_dir" ] && git -C "$raw_dir" rev-parse --git-dir >/dev/null 2>&1; then
  br=$(git -C "$raw_dir" branch --show-current 2>/dev/null)
  [ -n "$br" ] || br=$(git -C "$raw_dir" rev-parse --short HEAD 2>/dev/null || echo '?')
  dirty=""
  git -C "$raw_dir" diff --quiet 2>/dev/null && git -C "$raw_dir" diff --cached --quiet 2>/dev/null || dirty="*"
  git_seg=$(printf ' \033[35m %s%s\033[0m' "$br" "$dirty")
  # catalyst branch shape <type>/<KEY>/<slug> → surface the ticket key
  case "$br" in
    */*/*) ticket_seg=$(printf ' \033[33m🎫 %s\033[0m' "$(printf '%s' "$br" | cut -d/ -f2)") ;;
  esac
fi

printf '\033[1;32m🌴 %s\033[0m \033[36m%s\033[0m%s%s \033[2m+%s/-%s · $%.2f\033[0m' \
  "$model" "$dir" "$git_seg" "$ticket_seg" "$added" "$removed" "$cost"
