# ─────────────────────────────────────────────────────────────────────────────
# 00_guards :: helpers every later file depends on. MUST sort first.
#
# Loaded by afx (local package `zsh`, sources '[0-9]*.zsh') or by the fallback
# loop in .zshrc when afx isn't installed yet.
# ─────────────────────────────────────────────────────────────────────────────

# has <cmd> — the single predicate guarding every optional integration.
# Without this, a fresh machine throws a dozen errors per prompt.
has() { (( $+commands[$1] )) }

# src <file> — source only if readable.
src() { [[ -r "$1" ]] && source "$1" }

# try_eval <cmd> <args...> — run a tool's shell-init hook only if installed.
#   try_eval starship init zsh
try_eval() { has "$1" && eval "$("$@")" }

# try_comp <cmd> [args...] — source a tool's completion only if installed.
# Completions are slow; DOTFILES_FAST=1 skips them all.
try_comp() {
  [[ "${DOTFILES_FAST:-0}" == "1" ]] && return 0
  has "$1" && source <("$@") 2>/dev/null
}
