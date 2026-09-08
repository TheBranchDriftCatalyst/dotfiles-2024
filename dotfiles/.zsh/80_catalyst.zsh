# ─────────────────────────────────────────────────────────────────────────────
# 80_catalyst :: catalyst devspace wiring.
#
# Previously this echoed two lines on EVERY shell start and used `return 1` on
# a missing devspace — which aborts the rest of the file (and, under afx, can
# take the remaining plugins with it). Now it's silent when healthy and only
# complains when you ask it to.
#
#   CATALYST_VERBOSE=1   report what was loaded
#   catalyst-doctor      check the setup on demand
# ─────────────────────────────────────────────────────────────────────────────

# DEV_SPACE_ROOT is exported in .zshenv; keep a fallback for odd load orders.
: "${DEV_SPACE_ROOT:=$HOME/catalyst-devspace}"
export DEV_SPACE_ROOT

_catalyst_cli_bin="${DEV_SPACE_ROOT}/catalyst/@cli-tools/bin"

# PATH is already set in .zshenv (with -U, so this is a no-op duplicate guard).
# Kept here so a shell that somehow skipped .zshenv still finds the tools.
if [[ -d "$_catalyst_cli_bin" ]]; then
  path=("$_catalyst_cli_bin" $path)
  [[ "${CATALYST_VERBOSE:-0}" == "1" ]] && print -P "%F{green}✔%f catalyst cli-tools: $_catalyst_cli_bin"
elif [[ "${CATALYST_VERBOSE:-0}" == "1" ]]; then
  print -P "%F{yellow}⚠%f catalyst cli-tools not found: $_catalyst_cli_bin"
fi
unset _catalyst_cli_bin

# On-demand health check — no cost at shell startup.
catalyst-doctor() {
  local ok=0
  if [[ -d "$DEV_SPACE_ROOT" ]]; then
    print -P "%F{green}✔%f devspace       $DEV_SPACE_ROOT"
  else
    print -P "%F{red}✖%f devspace       missing: $DEV_SPACE_ROOT"
    print -P "  run: mkdir -p $DEV_SPACE_ROOT"
    ok=1
  fi
  local d
  for d in @dotfiles @cli-tools @machines @secrets; do
    if [[ -d "$DEV_SPACE_ROOT/catalyst/$d" ]]; then
      print -P "%F{green}✔%f $d"
    else
      print -P "%F{yellow}⚠%f $d           not cloned"
    fi
  done
  return $ok
}
