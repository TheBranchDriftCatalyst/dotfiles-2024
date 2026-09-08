#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# LAYER 0 — bare metal to "ready to build".
#
# This is the only imperative script in the repo, and it exists because Nix
# cannot install itself. Everything after this is declarative.
#
#   curl -fsSL https://raw.githubusercontent.com/TheBranchDriftCatalyst/dotfiles-2024/nix-next/bootstrap.sh | bash
#
# Idempotent: every step checks before acting, so re-running is safe.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DEVSPACE="${DEVSPACE:-$HOME/catalyst-devspace}"
REPO_DIR="$DEVSPACE/catalyst/@dotfiles"
REPO_URL="https://github.com/TheBranchDriftCatalyst/dotfiles-2024.git"
BRANCH="${BRANCH:-nix-next}"

if [ -t 1 ]; then
  R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[1;33m'; B=$'\033[1;34m'; D=$'\033[2m'; N=$'\033[0m'
else
  R=''; G=''; Y=''; B=''; D=''; N=''
fi
info() { printf '%s→%s %s\n' "$B" "$N" "$*"; }
ok()   { printf '%s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s⚠%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s✖%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
step() { printf '\n%s── %s %s%s\n' "$B" "$*" "$(printf '─%.0s' $(seq 1 $((50 - ${#1}))))" "$N"; }
has()  { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"
ARCH="$(uname -m)"
info "$OS / $ARCH"

# ── 1. platform prerequisites ────────────────────────────────────────────────
step "1. platform prerequisites"

case "$OS" in
  Darwin)
    # Xcode CLT — required by the darwin stdenv even under Nix.
    if xcode-select -p >/dev/null 2>&1; then
      ok "Xcode Command Line Tools"
    else
      info "installing Xcode Command Line Tools (GUI prompt)…"
      xcode-select --install || true
      die "rerun this script once the CLT install finishes"
    fi

    # Homebrew stays: nix-darwin DRIVES brew for GUI casks, it does not
    # replace or install it. Casks cannot be Nix packages.
    if has brew; then
      ok "Homebrew $(brew --version | head -1)"
    else
      info "installing Homebrew (needed for GUI casks)…"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    # shellcheck disable=SC2046
    if [ "$ARCH" = "arm64" ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; 
    else eval "$(/usr/local/bin/brew shellenv)"; fi
    ;;

  Linux)
    # The Nix installer needs these; nothing else is required from the distro.
    for c in curl git xz; do
      has "$c" || warn "missing '$c' — install it via your package manager first"
    done
    ok "linux prerequisites checked"
    ;;

  *) die "unsupported OS: $OS" ;;
esac

# ── 2. Nix ───────────────────────────────────────────────────────────────────
step "2. Nix"

if has nix; then
  ok "nix $(nix --version)"
else
  info "installing Determinate Nix (flakes enabled by default)…"
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # The installer writes the profile script; this shell hasn't sourced it yet.
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
  has nix || die "nix installed but not on PATH — open a NEW shell and rerun"
fi

# Determinate enables flakes; a hand-rolled install may not have.
if ! nix flake --help >/dev/null 2>&1; then
  warn "flakes not enabled; adding to ~/.config/nix/nix.conf"
  mkdir -p "$HOME/.config/nix"
  printf 'experimental-features = nix-command flakes\n' >> "$HOME/.config/nix/nix.conf"
fi
ok "flakes available"

# ── 3. the repo ──────────────────────────────────────────────────────────────
step "3. dotfiles repo"

if [ -d "$REPO_DIR/.git" ]; then
  ok "already present at $REPO_DIR"
else
  info "cloning into $REPO_DIR…"
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

# ── 4. what to run next ──────────────────────────────────────────────────────
step "4. next"

cat <<EOF

  ${G}Layer 0 complete.${N} Everything from here is declarative.

  ${D}# see exactly what would change — builds, changes NOTHING${N}
  cd $REPO_DIR
EOF

if [ "$OS" = "Darwin" ]; then
cat <<EOF
  nix run nix-darwin -- build --flake .#dj-mac

  ${D}# then, when you're happy:${N}
  sudo nix run nix-darwin -- switch --flake .#dj-mac
EOF
else
cat <<EOF
  nix build .#homeConfigurations.dj-linux${ARCH:+$([ "$ARCH" = aarch64 ] && echo -arm)}.activationPackage

  ${D}# then, when you're happy:${N}
  nix run home-manager/master -- switch --flake .#dj-linux
EOF
fi
echo
