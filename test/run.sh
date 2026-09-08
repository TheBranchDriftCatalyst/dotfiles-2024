#!/bin/sh
# Assertions run INSIDE the container.
set -u
cd "$DOTFILES" || exit 1

fails=0
ok()   { printf '  \033[0;32m✔\033[0m %s\n' "$1"; }
bad()  { printf '  \033[0;31m✖\033[0m %s\n' "$1"; fails=$((fails+1)); }
check(){ d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }

# Docker on Apple Silicon gives linux/arm64 — pick the matching output.
case "$(uname -m)" in
  aarch64|arm64) CFG="dj-linux-arm" ;;
  *)             CFG="dj-linux" ;;
esac
echo "══ target: .#homeConfigurations.${CFG} ($(uname -m)) ══"

echo "══ 1. flake evaluates ══"
if nix flake show --no-write-lock-file 2>&1 | tail -20; then
  ok "flake show"
else
  bad "flake show — flake does not evaluate"; exit 1
fi

echo "══ 2. activation package BUILDS ══"
if nix build ".#homeConfigurations.${CFG}.activationPackage" \
     --no-write-lock-file --print-build-logs 2>&1 | tail -30; then
  ok "activationPackage built"
else
  bad "build failed"; exit 1
fi

echo "══ 3. activate against a real \$HOME ══"
if ./result/activate 2>&1 | tail -20; then
  ok "activation succeeded"
else
  bad "activation failed"; exit 1
fi

echo "══ 4. links ══"
check "~/.zshrc exists"        test -e "$HOME/.zshrc"
check "~/.zsh dir present"     test -d "$HOME/.zsh"
check "numbered zsh files"     sh -c 'ls "$HOME"/.zsh/[0-9]*.zsh >/dev/null 2>&1'
check "~/.gitconfig exists"    test -e "$HOME/.gitconfig"
check "~/.tmux.conf exists"    test -e "$HOME/.tmux.conf"

echo "══ 5. tools on PATH (the afx+brew replacement) ══"
. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" 2>/dev/null || true
export PATH="$HOME/.nix-profile/bin:$PATH"
for t in zsh tmux eza bat rg fd jq yq delta starship gh lazygit k9s kubectl sops age; do
  check "$t" command -v "$t"
done

echo "══ 6. THE MONEY TEST: does an interactive shell start silently? ══"
out="$(zsh -i -c exit 2>&1)"
if [ -n "$out" ]; then
  bad "interactive zsh emitted output:"
  printf '%s\n' "$out" | sed 's/^/      /'
else
  ok "interactive zsh starts silently"
fi

echo "══ 7. did the zsh payload actually load? (the afx trap) ══"
check "aliases loaded"          zsh -i -c 'alias | grep -q .'
check "has() defined"           zsh -i -c 'typeset -f has >/dev/null'
check "catalyst-doctor defined" zsh -i -c 'typeset -f catalyst-doctor >/dev/null'
check "compdef worked"          zsh -i -c 'typeset -f git_dbranch >/dev/null'
check "starship is the prompt"  zsh -i -c 'typeset -f starship_precmd >/dev/null'

echo
if [ "$fails" -eq 0 ]; then
  printf '\033[0;32m══ ALL TESTS PASSED ══\033[0m\n'
else
  printf '\033[0;31m══ %d TEST(S) FAILED ══\033[0m\n' "$fails"
fi
exit "$fails"
