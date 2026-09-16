#!/usr/bin/env bash
# Uninstall all VSCode extensions except those declared in home/vscode.nix

set -euo pipefail

# Baseline extensions from nix config
BASELINE=(
  "anthropic.claude-code"
  "golang.go"
  "jnoortheen.nix-ide"
  "bbenoist.nix"
  "ms-vscode.makefile-tools"
  "max-ss.cyberpunk"
  "robbowen.synthwave-vscode"
  "ekelley.midnight-synth"
  "akamud.vscode-theme-onedark"
  "miguelsolorio.fluent-icons"
  "vscode-icons-team.vscode-icons"
)

echo "Fetching installed extensions..."
INSTALLED=$(code --list-extensions | tr '[:upper:]' '[:lower:]')

# Backup current extensions list
BACKUP_FILE="$HOME/.dotfiles/.scratch/vscode-extensions-backup-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$BACKUP_FILE")"
code --list-extensions >"$BACKUP_FILE"
echo "Backed up current extensions to: $BACKUP_FILE"
echo

echo "Extensions to keep:"
printf '  %s\n' "${BASELINE[@]}"
echo

TO_REMOVE=()
while IFS= read -r ext; do
  ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
  keep=false
  for baseline in "${BASELINE[@]}"; do
    baseline_lower=$(echo "$baseline" | tr '[:upper:]' '[:lower:]')
    if [[ $ext_lower == "$baseline_lower" ]]; then
      keep=true
      break
    fi
  done
  if [[ $keep == false ]]; then
    TO_REMOVE+=("$ext")
  fi
done <<<"$INSTALLED"

if [[ ${#TO_REMOVE[@]} -eq 0 ]]; then
  echo "No extensions to remove."
  exit 0
fi

echo "Will remove ${#TO_REMOVE[@]} extensions:"
printf '  %s\n' "${TO_REMOVE[@]}"
echo

read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 1
fi

for ext in "${TO_REMOVE[@]}"; do
  echo "Uninstalling $ext..."
  code --uninstall-extension "$ext" || echo "Failed to uninstall $ext"
done

echo "Done! Remaining extensions:"
code --list-extensions
