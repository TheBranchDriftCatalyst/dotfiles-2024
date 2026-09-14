#!/usr/bin/env bash
# Claude Code status line — receives session JSON on stdin, prints ONE line.
# Nix-managed: lives in dotfiles/claude/hooks (claude.nix live-symlinks the
# hooks dir into ~/.claude), wired via settings.json "statusLine".
#
#   🌴 Fable ~/devspace/.catalyst-cli  bugfix/DEV-777/old-slug* 🎫 DEV-777 ▰▰▱▱▱ 31% (309k/1M) +42/-7 · $1.23
#
set -uo pipefail

in=$(cat)
command -v jq >/dev/null 2>&1 || {
  printf '🌴 Claude'
  exit 0
}
j() { printf '%s' "$in" | jq -r "$1" 2>/dev/null; }

model=$(j '.model.display_name // .model.id // "Claude"')
raw_dir=$(j '.workspace.current_dir // .cwd // empty')
dir=${raw_dir/#$HOME/\~}
added=$(j '.cost.total_lines_added // 0')
removed=$(j '.cost.total_lines_removed // 0')
cost=$(j '.cost.total_cost_usd // 0')

# context window — provided directly (context_window.*); nullable early in a
# session, so the whole segment hides until real numbers arrive.
fmt_tok() { # 309244 → 309k, 1000000 → 1M
  local n=$1
  if [ "$n" -ge 1000000 ] && [ $((n % 1000000)) -lt 100000 ]; then
    printf '%dM' $((n / 1000000))
  elif [ "$n" -ge 1000 ]; then
    printf '%dk' $((n / 1000))
  else
    printf '%d' "$n"
  fi
}
ctx_seg=""
used_pct=$(j '.context_window.used_percentage // empty')
if [ -n "$used_pct" ]; then
  used_pct=${used_pct%.*} # integer floor; bash can't printf floats from jq reliably
  size=$(j '.context_window.context_window_size // 0')
  used_tok=$(j '.context_window.total_input_tokens // 0')
  # gauge: 5 cells, colored by headroom — green <50%, yellow <80%, red beyond
  cells=$(((used_pct + 10) / 20))
  [ "$cells" -gt 5 ] && cells=5
  bar=""
  for i in 1 2 3 4 5; do
    if [ "$i" -le "$cells" ]; then bar+="▰"; else bar+="▱"; fi
  done
  col='\033[32m'
  [ "$used_pct" -ge 50 ] && col='\033[33m'
  [ "$used_pct" -ge 80 ] && col='\033[31m'
  ctx_seg=$(printf ' %b%s %s%% (%s/%s)\033[0m' "$col" "$bar" "$used_pct" "$(fmt_tok "$used_tok")" "$(fmt_tok "$size")")
fi

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

printf '\033[1;32m🌴 %s\033[0m \033[36m%s\033[0m%s%s%b \033[2m+%s/-%s · $%.2f\033[0m' \
  "$model" "$dir" "$git_seg" "$ticket_seg" "$ctx_seg" "$added" "$removed" "$cost"
