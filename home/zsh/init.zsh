# ─────────────────────────────────────────────────────────────────────────────
# init.zsh :: ACTIVE runtime settings — sourced by home/zsh.nix on every shell.
#
# Unlike aliases/functions/fzf-git (curation contract, commented until used),
# everything here is live: setopts, zstyles, keybindings, and the core
# aliases. Pure zsh — anything needing a nix store path (LS_COLORS, the
# library source lines) stays in zsh.nix itself.
# ─────────────────────────────────────────────────────────────────────────────

# ── keybindings: emacs base, VS Code-style word motion ───────────────────────
# ^A/^E are deliberately repurposed from line motion to word motion
# (Ctrl+←/→ muscle memory). This is a chosen sharp edge.
bindkey -e
bindkey '^E' forward-word
bindkey '^A' backward-word

# ── setopts not covered by programs.zsh.history ──────────────────────────────
# Deliberately NOT set (retired 2026-09): correct/correct_all (arg
# spellcheck), sh_word_split, no_global_rcs (fights /etc/zshrc nix profile
# sourcing), mail_warning.
setopt auto_cd auto_pushd pushd_ignore_dups pushd_to_home pushd_minus
setopt extended_glob glob_dots no_case_glob mark_dirs
setopt interactive_comments no_beep no_list_beep no_hist_beep
setopt complete_in_word always_last_prompt auto_menu auto_param_slash
setopt auto_param_keys auto_remove_slash list_types
setopt long_list_jobs notify no_flow_control auto_resume
setopt no_clobber rm_star_wait print_exit_value
setopt hist_verify hist_reduce_blanks hist_no_store hist_no_functions
setopt hist_find_no_dups hist_save_no_dups bang_hist
setopt brace_ccl equals magic_equal_subst multios rc_quotes
setopt no_prompt_cr path_dirs print_eight_bit

# only record commands that actually resolve to something
zshaddhistory() { whence ${${(z)1}[1]} >| /dev/null || return 1 }

# ── completion styling (ported from 70_zstyles.zsh, curated) ─────────────────
# list-colors reads LS_COLORS, which zsh.nix exports (vivid) before sourcing
# this file — order is load-bearing.
zstyle ':completion:*:default' menu select=2
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:descriptions' format '%F{yellow}Completing %B%d%b%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' verbose yes
# completer chain: _approximate removed with correct_all
zstyle ':completion:*' completer _expand _complete _match _prefix _list _history
zstyle ':completion:*:*files' ignored-patterns '*?.o' '*?~' '*\#'
zstyle ':completion:*' use-cache true
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
zstyle ':completion:*:cd:*' ignore-parents parent pwd
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-separator '-->'
zstyle ':completion:*:manuals' separate-sections true

# hjkl navigation inside the completion menu
zmodload -i zsh/complist
bindkey -M menuselect '^h' vi-backward-char
bindkey -M menuselect '^j' vi-down-line-or-history
bindkey -M menuselect '^k' vi-up-line-or-history
bindkey -M menuselect '^l' vi-forward-char

# paste-safe URL handling; replaces the old url-quote-magic self-insert
# rebind, which fights autosuggestions + syntax-highlighting.
autoload -Uz bracketed-paste-magic
zle -N bracketed-paste bracketed-paste-magic

# zcalc is the only survivor of the old autoload batch — the rest (cdr,
# vcs_info, smart-insert-last-word, run-help-svk…) were unbound or served
# tools that no longer exist.
autoload -Uz zcalc

# ── core aliases (ported from afx plugin.env/snippet blocks) ─────────────────
# exa aliases carried over onto eza; rm goes to the trash can, not the void.
alias ls='eza'
alias l='eza -1'
alias ll='eza -l --git'
alias la='eza -a'
alias lla='eza -la --git'
alias lt='eza --tree --level=2'
alias lta='eza --tree --level=2 -a'
alias cat='bat'
alias rm='gomi'
alias g='lazygit'
alias jq='jq -C'
alias diff='colordiff -u'
export BAT_PAGER='less -RF'

# bare `cd` -> interactive picker of recent dirs (the old enhancd muscle
# memory, rebuilt on zoxide's frecency db + fzf). With args, cd behaves
# normally; zoxide keeps learning either way.
cd() {
  if (( $# == 0 )) && whence __zoxide_zi >/dev/null 2>&1; then
    __zoxide_zi
  else
    builtin cd "$@"
  fi
}

# auto-list on cd: every directory change shows what's there. Guarded on a
# real terminal; capped for huge dirs so cd into node_modules doesn't flood
# the screen.
_eza_on_chpwd() {
  [[ -t 1 ]] || return 0
  local count
  count=$(command ls -A 2>/dev/null | wc -l | tr -d " ")
  if [[ "${count:-0}" -gt 100 ]]; then
    eza --group-directories-first | head -20
    print -P "%F{8}… ${count} entries%f"
  else
    eza --group-directories-first
  fi
}
add-zsh-hook chpwd _eza_on_chpwd

# fzf integration — guard on a real terminal, not [[ -o zle ]]; key bindings
# are meaningless without one and the eval errors headlessly.
if (( $+commands[fzf] )) && [[ -t 0 ]]; then
  eval "$(fzf --zsh)"
fi
