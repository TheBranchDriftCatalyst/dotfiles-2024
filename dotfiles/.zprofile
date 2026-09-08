# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:/Users/dj/.docker/bin"
# End of Docker Desktop section.

# ─────────────────────────────────────────────────────────────────────────────
# .zprofile :: login shells only. Environment, not behaviour.
#
# PATH lives in .zshenv (needed by non-login shells too). compinit lives in
# .zshrc and runs exactly once — it used to run here AND twice in .zshrc.
# ─────────────────────────────────────────────────────────────────────────────

# ── locale ───────────────────────────────────────────────────────────────────
export LANGUAGE="en_US.UTF-8"
export LANG="${LANGUAGE}"
export LC_ALL="${LANGUAGE}"
export LC_CTYPE="${LANGUAGE}"

# ── editor ───────────────────────────────────────────────────────────────────
# Fall back to vim when nvim isn't installed yet — otherwise a fresh box has no
# usable $EDITOR and `git commit` fails.
if (( $+commands[nvim] )); then
  export EDITOR=nvim
elif (( $+commands[vim] )); then
  export EDITOR=vim
else
  export EDITOR=vi
fi
export VISUAL="${EDITOR}"
export CVSEDITOR="${EDITOR}"
export SVN_EDITOR="${EDITOR}"
export GIT_EDITOR="${EDITOR}"

# ── pager ────────────────────────────────────────────────────────────────────
export PAGER=less
export LESS='-R -f -X -i -P ?f%f:(stdin). ?lb%lb?L/%L.. [?eEOF:?pb%pb\%..]'
export LESSCHARSET='utf-8'

# man page colors
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[00;44;37m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

# ── ls colors ────────────────────────────────────────────────────────────────
export LSCOLORS=exfxcxdxbxegedabagacad
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'

# ── history ──────────────────────────────────────────────────────────────────
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=1000000
export SAVEHIST=1000000
export LISTMAX=50
# never persist root history
if [[ $UID == 0 ]]; then
  unset HISTFILE
  export SAVEHIST=0
fi

# ── misc ─────────────────────────────────────────────────────────────────────
export CORRECT_IGNORE='_*'
export CORRECT_IGNORE_FILE='.*'
export WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
export FZF_DEFAULT_OPTS="--extended --ansi --multi"
export STARSHIP_CONFIG="$HOME/starship.toml"
