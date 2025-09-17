#!/bin/bash

# Claude Code Status Line
# Simplified and reliable version

# Read JSON input from stdin
input=$(cat)

# Extract JSON data safely
dir=$(echo "$input" | jq -r '.workspace.current_dir // "."')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // ""')
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
style=$(echo "$input" | jq -r '.output_style.name // "default"')

# Color definitions
RESET='\033[0m'
CYAN='\033[1;36m'
PURPLE='\033[1;35m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
WHITE='\033[1;37m'
DIM='\033[2;37m'

# Simple git status
get_git_info() {
    if git rev-parse --git-dir >/dev/null 2>&1; then
        local branch=$(git branch --show-current 2>/dev/null)
        if [[ -n "$branch" ]]; then
            printf " ${PURPLE}git:$branch${RESET}"

            # Simple status indicators
            if ! git diff --quiet 2>/dev/null; then
                printf " ${YELLOW}*${RESET}"
            fi
            if ! git diff --cached --quiet 2>/dev/null; then
                printf " ${GREEN}+${RESET}"
            fi
        fi
    fi
}

# Simple project detection
get_project_info() {
    local info=""

    if [[ -f "$dir/package.json" ]]; then
        info+=" ${GREEN}node${RESET}"
    fi

    if [[ -f "$dir/go.mod" ]]; then
        info+=" ${CYAN}go${RESET}"
    fi

    if [[ -f "$dir/Taskfile.yaml" ]] || [[ -f "$dir/Taskfile.yml" ]]; then
        info+=" ${YELLOW}Taskfile${RESET}"
    fi

    printf "$info"
}

# Main function
main() {
    # Get directory name
    local dir_name=$(basename "$dir")

    # Build output
    printf "${CYAN}$dir_name${RESET}"
    printf "$(get_git_info)"
    printf "$(get_project_info)"
    printf " ${WHITE}$model${RESET}"

    if [[ "$style" != "default" ]]; then
        printf " ${DIM}[$style]${RESET}"
    fi
}

# Execute
main