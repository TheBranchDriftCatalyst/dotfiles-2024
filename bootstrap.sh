#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# LAYER 0 — bare metal to "ready to build".
#
# This is the only imperative script in the repo, and it exists because Nix
# cannot install itself. Everything after this is declarative.
#
#   curl -fsSL https://raw.githubusercontent.com/TheBranchDriftCatalyst/dotfiles-2024/nix-next/bootstrap.sh | bash
#
# THE single button. From bare metal it: installs Xcode CLT + Homebrew
# (macOS), installs Determinate Nix, clones this repo, COMPILES the full
# configuration (changing nothing), then asks ONCE before activating.
#   --switch / BOOTSTRAP_SWITCH=1   skip the question (fully unattended)
#
# Idempotent: every step checks before acting, so re-running is safe.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_DIR="$HOME/.dotfiles"
REPO_URL="https://github.com/TheBranchDriftCatalyst/dotfiles-2024.git"
BRANCH="${BRANCH:-nix-next}"

if [ -t 1 ]; then
  R=$'\033[0;31m'
  G=$'\033[0;32m'
  Y=$'\033[1;33m'
  B=$'\033[1;34m'
  D=$'\033[2m'
  N=$'\033[0m'
else
  R=''
  G=''
  Y=''
  B=''
  D=''
  N=''
fi
info() { printf '%s→%s %s\n' "$B" "$N" "$*"; }
ok() { printf '%s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s⚠%s %s\n' "$Y" "$N" "$*" >&2; }
die() {
  printf '%s✖%s %s\n' "$R" "$N" "$*" >&2
  exit 1
}
step() { printf '\n%s── %s %s%s\n' "$B" "$*" "$(printf '─%.0s' $(seq 1 $((50 - ${#1}))))" "$N"; }
has() { command -v "$1" >/dev/null 2>&1; }

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
  if [ "$ARCH" = "arm64" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
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

# A rerun in a shell that hasn't sourced Nix's profile would wrongly re-invoke
# the installer (harmless but noisy — it prints a scary "try uninstalling"
# no-op message). Source the profile first so `has nix` sees an existing
# install.
if ! has nix && [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

if has nix; then
  ok "nix $(nix --version)"
else
  info "installing Determinate Nix (flakes enabled by default)…"
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix |
    sh -s -- install --no-confirm
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
  printf 'experimental-features = nix-command flakes\n' >>"$HOME/.config/nix/nix.conf"
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

# secret-scanning + lint hooks — the pre-commit BLOCKS commits with secrets
git -C "$REPO_DIR" config core.hooksPath .githooks &&
  ok "git hooks registered (.githooks — gitleaks pre-commit)"

# ── 4. build ─────────────────────────────────────────────────────────────────
# Compiling the full configuration changes NOTHING on the machine — it only
# proves the config is sound and downloads what a switch would need.
step "4. build (changes nothing)"

cd "$REPO_DIR"

case "$OS" in
Darwin)
  # darwin configs are named by hostname. A brand-new machine won't have a
  # hosts/<name>/ yet — say so instead of failing cryptically.
  TARGET="$(hostname -s)"
  if ! grep -q "\"$TARGET\"" "$REPO_DIR/flake.nix"; then
    warn "no darwinConfigurations.\"$TARGET\" in flake.nix —"
    warn "create hosts/$TARGET/ (copy hosts/teakbookM5DJ) and wire it in flake.nix"
    die "then rerun"
  fi
  ;;
Linux) [ "$ARCH" = "aarch64" ] && TARGET="linux-generic-arm" || TARGET="linux-generic" ;;
esac

info "building .#${TARGET} — first run downloads a lot; go get coffee…"
if [ "$OS" = "Darwin" ]; then
  nix run nix-darwin/master#darwin-rebuild -- build --flake ".#${TARGET}"
else
  nix build ".#homeConfigurations.${TARGET}.activationPackage"
fi
ok "configuration compiled — nothing on this machine has changed yet"

# ── 5. switch ────────────────────────────────────────────────────────────────
# The ONLY gate. --switch (or BOOTSTRAP_SWITCH=1) skips the question for a
# truly unattended run; otherwise one keypress decides.
step "5. activate"

do_switch=0
case "''${1:-}" in --switch) do_switch=1 ;; esac
[ "''${BOOTSTRAP_SWITCH:-0}" = "1" ] && do_switch=1

if [ "$do_switch" -eq 0 ] && [ -t 0 ]; then
  printf '%s?%s Activate now? This links dotfiles, applies macOS defaults, and\n' "$B" "$N"
  printf '  (on macOS) syncs Homebrew casks — removing casks NOT in the list. [y/N] '
  read -r ans
  case "$ans" in [Yy]*) do_switch=1 ;; esac
fi

if [ "$do_switch" -eq 1 ]; then
  if [ "$OS" = "Darwin" ]; then
    sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ".#${TARGET}"
  else
    nix run home-manager/master -- switch --flake ".#${TARGET}"
  fi
  ok "activated — open a NEW terminal to get the full environment"
else
  cat <<EOF

  ${G}Built and ready.${N} Nothing was changed. To activate later:

      cd $REPO_DIR
EOF
  if [ "$OS" = "Darwin" ]; then
    echo "      sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#${TARGET}"
  else
    echo "      nix run home-manager/master -- switch --flake .#${TARGET}"
  fi
  echo
fi
