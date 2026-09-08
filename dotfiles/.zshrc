# ─────────────────────────────────────────────────────────────────────────────
# .zshrc :: interactive shells. This file is an ORCHESTRATOR — ordering matters
# and nothing here may assume a tool is installed.
#
# Order:
#   1. guards        has() and friends
#   2. compinit      ONCE, early — 40_functions.zsh calls compdef
#   3. plugins       afx (also sources ~/.zsh/[0-9]*.zsh via its `local` pkg),
#                    falling back to a direct loop when afx isn't installed
#   4. tools         mise / direnv / starship / fzf  (guarded)
#   5. completions   per-tool, guarded
#
# Debug a slow start with:  DOTFILES_PROFILE=1 zsh -i -c exit
# Skip all completions with: DOTFILES_FAST=1
# ─────────────────────────────────────────────────────────────────────────────

[[ -n "$VIMRUNTIME" ]] && return 0          # zsh launched from inside vim

[[ "${DOTFILES_PROFILE:-0}" == "1" ]] && zmodload zsh/zprof

# ── 1. guards ────────────────────────────────────────────────────────────────
# Must load before anything else; afx may not exist yet to load it for us.
source "$HOME/.zsh/00_guards.zsh"

# only record commands that actually resolve to something
zshaddhistory() { whence ${${(z)1}[1]} >| /dev/null || return 1 }

# ── 2. compinit ──────────────────────────────────────────────────────────────
# MUST run before the config files below: 40_functions.zsh calls compdef, which
# does not exist until compinit has run. fpath is already final (set in
# .zshenv). -C skips the security audit of the cached dump.
autoload -Uz compinit colors add-zsh-hook
compinit -C
colors

# ── 3. plugins + config files ────────────────────────────────────────────
# afx owns plugin loading AND sources ~/.zsh/[0-9]*.zsh via the `local` package
# in ~/.config/afx/local.yaml. On a machine where afx isn't installed yet we
# still want aliases and functions, so fall back to sourcing them directly.
#
# NOTE: afx silently reports "No packages to install" if ~/.config/afx is a
# SYMLINK (babarot/afx#40) — that's why the dotbot profile links the individual
# yaml files into a real ~/.config/afx directory instead of linking the dir.
if has afx; then
  source <(afx init)
else
  for _f in "$HOME"/.zsh/[0-9]*.zsh(N); do source "$_f"; done
  unset _f
fi

# ── 4. tool activation ───────────────────────────────────────────────────────
src "$HOME/.cargo/env"

try_eval mise activate zsh
try_eval starship init zsh
try_eval direnv hook zsh
# fzf's integration installs ZLE key bindings, and its scripts save/restore the
# full option set — including `zle`, which cannot be changed in a shell with no
# real line editor. Under `zsh -i -c ...` that prints:
#     (eval):1: can't change option: zle
# `[[ -o zle ]]` is true even there, so test for an actual terminal instead.
# Key bindings are meaningless without one anyway.
if has fzf && [[ -t 0 ]]; then
  eval "$(fzf --zsh)"
fi

# ── 5. tool completions ───────────────────────────────────────────────────────────
# Every one of these used to run unguarded and error on a fresh machine.
for _c in kubectl helm skaffold minikube docker; do
  try_comp "$_c" completion zsh
done
unset _c
try_comp afx completion zsh
has saml2aws && eval "$(saml2aws --completion-script-zsh)"

# nvm is lazy — sourcing it eagerly costs ~200ms
export NVM_DIR="$HOME/.nvm"
src "$NVM_DIR/nvm.sh"
src "$NVM_DIR/bash_completion"

# Generic loader: source zsh completions that direnv-managed .envrc files
# advertise via $DIRENV_ZSH_COMPLETIONS (colon-separated). Registered AFTER the
# direnv hook so the var is exported before this runs each prompt.
typeset -gA _DIRENV_COMPS_LOADED
_load_direnv_completions() {
  [[ -n "$DIRENV_ZSH_COMPLETIONS" ]] || return
  local f
  for f in ${(s.:.)DIRENV_ZSH_COMPLETIONS}; do
    [[ -r "$f" && -z "${_DIRENV_COMPS_LOADED[$f]}" ]] || continue
    source "$f" && _DIRENV_COMPS_LOADED[$f]=1
  done
}
add-zsh-hook precmd _load_direnv_completions

[[ "${DOTFILES_PROFILE:-0}" == "1" ]] && zprof
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/dj/.docker/completions $fpath)
autoload -Uz compinit
(( ${+_comps[docker]} )) || compinit
# End of Docker CLI completions
