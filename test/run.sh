#!/bin/sh
# Assertions run INSIDE the container.
set -u
cd "$DOTFILES" || exit 1

fails=0
ok() { printf '  \033[0;32m✔\033[0m %s\n' "$1"; }
bad() {
  printf '  \033[0;31m✖\033[0m %s\n' "$1"
  fails=$((fails + 1))
}
check() {
  d="$1"
  shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi
}

# Docker on Apple Silicon gives linux/arm64 — pick the matching output.
case "$(uname -m)" in
aarch64 | arm64) CFG="linux-generic-arm" ;;
*) CFG="linux-generic" ;;
esac
echo "══ target: .#homeConfigurations.${CFG} ($(uname -m)) ══"

# POSIX sh has no pipefail: `cmd | tail` reports tail's status and masks the
# failure. Capture to a file, test the command's own status, then show a tail.
LOG=/tmp/step.log
run_step() { # run_step <desc> <cmd...>
  d="$1"
  shift
  if "$@" >"$LOG" 2>&1; then
    tail -5 "$LOG"
    ok "$d"
  else
    tail -40 "$LOG"
    bad "$d"
    exit 1
  fi
}

echo "══ 1. flake evaluates ══"
run_step "flake show" nix flake show --no-write-lock-file

echo "══ 2. activation package BUILDS ══"
run_step "activationPackage built" \
  nix build ".#homeConfigurations.${CFG}.activationPackage" \
  --no-write-lock-file --print-build-logs

echo '══ 3. activate against a real $HOME ══'
run_step "activation succeeded" ./result/activate

echo "══ 4. links ══"
check "~/.zshrc exists" test -e "$HOME/.zshrc"
# ~/.zsh may exist (HM installs its zsh plugins there) but the old
# numbered-file payload must be gone — HM initContent is the only init.
check "no numbered zsh files" sh -c '! ls "$HOME"/.zsh/[0-9]*.zsh >/dev/null 2>&1'
check "git config (xdg)" test -e "$HOME/.config/git/config"
check "tmux.conf (xdg)" test -e "$HOME/.config/tmux/tmux.conf"

echo "══ 5. tools on PATH (the afx+brew replacement) ══"
. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" 2>/dev/null || true
export PATH="$HOME/.nix-profile/bin:$PATH"
for t in zsh tmux eza bat rg fd jq yq delta starship gh lazygit k9s kubectl sops age testssl.sh; do
  check "$t" command -v "$t"
done

echo "══ 6. THE MONEY TEST: does an interactive shell start silently? ══"
# TERM must be sane: starship (correctly) skips init on a dumb terminal.
export TERM=xterm-256color
out="$(zsh -i -c exit 2>&1)"
if [ -n "$out" ]; then
  bad "interactive zsh emitted output:"
  printf '%s\n' "$out" | sed 's/^/      /'
else
  ok "interactive zsh starts silently"
fi

echo "══ 7. did the zsh payload actually load? (the afx trap) ══"
check "aliases loaded" zsh -i -c 'alias | grep -q .'
check "safety rails active" zsh -i -c 'alias cp | grep -q nocorrect'
check "setopts applied" zsh -i -c '[[ -o autopushd ]]'
check "spellcheck retired" zsh -i -c '[[ ! -o correctall ]]'
check "starship is the prompt" zsh -i -c 'typeset -f prompt_starship_precmd >/dev/null'

echo "══ 8. direnv helper library (home/direnv/lib) ══"
LIBDIR="${XDG_CONFIG_HOME:-$HOME/.config}/direnv/lib"
check "onepassword.sh installed" test -e "$LIBDIR/onepassword.sh"
check "nix-direnv still installed alongside it" test -e "$LIBDIR/hm-nix-direnv.sh"
# The suite is bash (arrays, [[ ]]); this image ships busybox sh. Run it when a
# bash exists, and SAY SO when it does not — a silent skip reads as a pass.
if command -v bash >/dev/null 2>&1; then
  # Not run_step: that aborts the whole file, and a direnv failure should not
  # cost us the summary for everything after it.
  if bash ./test/direnv/run.sh "$LIBDIR/onepassword.sh" >"$LOG" 2>&1; then
    ok "direnv/op suite (against the INSTALLED lib)"
  else
    tail -40 "$LOG"
    bad "direnv/op suite (against the INSTALLED lib)"
  fi
else
  printf '  \033[0;33m—\033[0m %s\n' 'direnv/op suite SKIPPED: no bash in this image (run `just test-direnv` on the host)'
fi

echo
if [ "$fails" -eq 0 ]; then
  printf '\033[0;32m══ ALL TESTS PASSED ══\033[0m\n'
else
  printf '\033[0;31m══ %d TEST(S) FAILED ══\033[0m\n' "$fails"
fi
exit "$fails"
