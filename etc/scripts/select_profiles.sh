#!/usr/bin/env bash
set -euo pipefail

# ────────────────────────────────────────────────────────────────────────────────
# Sexy CLI Multiselect for Profiles
# ────────────────────────────────────────────────────────────────────────────────

# Color palette
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

# Paths
# Hmm this needs not not be the bash source, its relative to command execution
# SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="./profiles"
INSTALL_CONF="./install.conf.yaml"

# Banner
printf "${BLUE}┌────────────────────────────────────────────┐\n"
printf "│      🚀 Select Your Profiles, Dawg!        │\n"
printf "└────────────────────────────────────────────┘${NC}\n\n"

# Ensure fzf is available
if ! command -v fzf &>/dev/null; then
  printf "${RED}Error:${NC} 'fzf' not found. Install it with 'brew install fzf'.\n"
  exit 1
fi

# Overwrite check
if [[ -f "$INSTALL_CONF" ]]; then
  printf "${YELLOW}Warning:${NC} %s exists and will be overwritten.\n" "$INSTALL_CONF"
  read -r -p "$(printf "${BLUE}Continue?${NC} (y/n): ")" ans
  [[ $ans =~ ^[Yy]$ ]] || exit 0
  rm -f "$INSTALL_CONF"
  printf "${GREEN}Removed existing config.${NC}\n\n"
fi

# Verify profiles directory
if [[ ! -d "$PROFILE_DIR" ]]; then
  printf "${RED}Error:${NC} Profiles directory '%s' not found.\n" "$PROFILE_DIR"
  exit 1
fi

# Launch fzf for multi-select
cd "$PROFILE_DIR"
selected=$(ls *.yaml \
  | fzf --multi --height 40% --border \
        --prompt="Profiles> " \
        --header="Select profiles (Tab to select, Enter to confirm)")
cd - > /dev/null

[[ -n $selected ]] || { printf "${YELLOW}No profiles selected. Exiting.${NC}\n"; exit 0; }

# Generate install.conf.yaml
printf "${GREEN}Generating %s...${NC}\n\n" "$INSTALL_CONF"
{
  printf "# Auto-generated install.conf.yaml\n"
  for profile in $selected; do
    # printf "- include: %s/%s\n" "$PROFILE_DIR" "$profile"
    printf -- "- include: %s/%s\n" "$PROFILE_DIR" "$profile"
  done
} > "$INSTALL_CONF"

# Summary
printf "${GREEN}✔ Done! Selected profiles:${NC}\n"
for profile in $selected; do
  printf "  • %s\n" "$profile"
done