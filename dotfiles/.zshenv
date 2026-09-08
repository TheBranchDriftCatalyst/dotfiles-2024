# ─────────────────────────────────────────────────────────────────────────────
# .zshenv :: sourced for EVERY zsh (interactive, scripts, subshells).
#
#   zshenv (this) -> zprofile (login) -> zshrc (interactive) -> zlogin
#
# Keep this file cheap and side-effect free: no evals, no completions, no
# output. Paths only. https://zsh.sourceforge.io/Doc/Release/Files.html
# ─────────────────────────────────────────────────────────────────────────────

# Where the dotfiles repo and the surrounding devspace live. Everything else
# derives from these — never hardcode a /Users/<name> path anywhere.
export DEV_SPACE_ROOT="${DEV_SPACE_ROOT:-$HOME/catalyst-devspace}"
export DOTFILES_ROOT="${DOTFILES_ROOT:-$DEV_SPACE_ROOT/catalyst/@dotfiles}"

# XDG — afx, mise, gh, k9s and friends all key off these.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Homebrew prefix differs by arch; resolve rather than assume.
if [[ -z "${HOMEBREW_PREFIX:-}" ]]; then
  if [[ "$(uname -m)" == "arm64" ]]; then
    export HOMEBREW_PREFIX=/opt/homebrew
  else
    export HOMEBREW_PREFIX=/usr/local
  fi
fi

# -U = unique, so re-sourcing never duplicates entries.
typeset -gx -U path
path=(
  "$DEV_SPACE_ROOT/catalyst/@cli-tools/bin"(N-/)
  "$HOME/bin"(N-/)
  "$HOME/.local/bin"(N-/)
  "$HOMEBREW_PREFIX/bin"(N-/)
  "$HOMEBREW_PREFIX/sbin"(N-/)
  "${KREW_ROOT:-$HOME/.krew}/bin"(N-/)
  "$HOME/.cargo/bin"(N-/)
  "$HOME/.docker/bin"(N-/)
  "$path[@]"
)

typeset -gx -U fpath
fpath=(
  "$HOME/.zsh/Completion"(N-/)
  "$HOME/.zsh/functions"(N-/)
  "$HOME/.docker/completions"(N-/)
  "$HOMEBREW_PREFIX/share/zsh-completions"(N-/)
  "$HOMEBREW_PREFIX/share/zsh/site-functions"(N-/)
  "$fpath[@]"
)

export GOPATH="${GOPATH:-$HOME/go}"
