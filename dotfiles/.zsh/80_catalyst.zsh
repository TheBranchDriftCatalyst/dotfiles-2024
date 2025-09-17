#!/usr/bin/env zsh

# Initialize an empty array to store found dependencies
DEPENDENCIES=()

# # Function to check if command exists and add it to the DEPENDENCIES array
check_command_exists() {
    if command -v "$1" >/dev/null 2>&1; then
        DEPENDENCIES+=("$1")  # Add command to dependencies list
    else
        echo >&2 "$1 is required but not installed. Aborting."
        exit 1
    fi
}

# # Check if required commands are installed
check_command_exists "figlet"
# check_command_exists "docker"
# check_command_exists "python"
# check_command_exists "node"
# check_command_exists "poetry"
# check_command_exists "pdm"
# check_command_exists "yarn"

# Function to generate dynamic ASCII art
generate_ascii_art() {
    local text="CatalystDev"
    echo -e "\e[1;35m$(figlet -f slant "$text")\e[0m"
}

# Function to display environment information
display_env_info() {
    # Display Synthwave-inspired header
    echo -e "\e[1;36m========================== CatalystDev Framework ==========================\e[0m"

    # Display environment info
    echo -e "\e[1;32mOS:\e[0m $(uname -s) $(uname -r)"
    echo -e "\e[1;32mPython Version:\e[0m $(python --version)"
    echo -e "\e[1;32mNode.js Version:\e[0m $(node -v)"
    echo -e "\e[1;32mDocker Version:\e[0m $(docker --version)"
    
    # Get active containers
    active_containers=$(docker ps -q)
    if [[ -z "$active_containers" ]]; then
        active_containers="No active containers"
    else
        active_containers="$(echo "$active_containers" | wc -l) running"
    fi
    echo -e "\e[1;32mActive Containers:\e[0m $active_containers"
    echo -e "\e[1;32mCatalystDev Framework:\e[0m Installed"
    
    # Display dependencies versions
    echo -e "\e[1;32mDependencies:\e[0m"
    for dep in "${DEPENDENCIES[@]}"; do
        echo -e "\e[1;32m   $dep:\e[0m $(command -v $dep)"
    done
    
    # Display Synthwave footer
    echo -e "\e[1;36m=========================================================================\e[0m"
}

# Function to display a slick synthwave-style table for environment info
display_synthwave_table() {
    echo -e "\e[1;35m┌──────────────────────────────────────────────────────────────────────┐"
    echo -e "\e[1;35m│             CatalystDev Framework Environment Setup                 │"
    echo -e "\e[1;35m│             Version: 1.0.0                                            │"
    echo -e "\e[1;35m│             Date: $(date)                                            │"
    echo -e "\e[1;35m│             Active Python Virtualenv: $(basename $(realpath $(which python))) │"
    echo -e "\e[1;35m└──────────────────────────────────────────────────────────────────────┘\e[0m"
}

# Function to load everything in a modular, clean way
load_catalystdev_setup() {
    # Temporarily removed the 'clear' command to test
    # clear

    # Display dynamic ASCII
    generate_ascii_art

    # Display environment information
    display_env_info

    # # Display synthwave-style table
    display_synthwave_table
}

# Run the setup
load_catalystdev_setup
