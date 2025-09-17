# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **@dotfiles-2024** project - a Dotbot-based dotfiles management system that provides profile-driven configuration deployment for development environments.

## Build System & Commands

### Primary Commands
- `task install` - Interactive profile selection and dotfile installation via fuzzy finder
- `task clean` - Removes dead symlinks from home directory
- `task brew:dump` - Dumps current brew packages to Brewfile

### Development Workflow
1. Modify profiles in `profiles/` directory for different installation scenarios
2. Test with `task install` (uses interactive profile selection)
3. Update Brewfile with `task brew:dump` if packages changed
4. Use `task clean` to remove orphaned symlinks

## Architecture

### Profile System
- **Profile-based Configuration**: YAML profiles in `profiles/` directory define different installation scenarios
- **Dynamic Selection**: Fuzzy finder interface for interactive profile selection during installation
- **Generated Configuration**: `install.conf.yaml` is dynamically generated based on selected profile

### Key Components
- **Dotbot Integration**: Uses Dotbot submodule with custom plugins (`etc/plugins/`)
- **Modular Dotfiles**: Organized configuration in `dotfiles/` directory
  - `.zsh/` - Modular ZSH configuration with numbered files (30_aliases.zsh, 80_catalyst.zsh)
  - `.config/` - Application-specific configurations (direnv, git, vscode, claude)
- **Brew Integration**: Brewfile management for package consistency across environments

### Configuration Structure
- `dotfiles/.zsh/` - ZSH shell configuration with modular approach
- `dotfiles/.config/direnv/` - Directory environment management
- `dotfiles/.config/git/` - Git configuration and global ignore patterns
- `dotfiles/.config/claude/` - Claude Code settings and statusline
- `dotfiles/.config/.vscode/` - VSCode settings

## Available Profiles

Check `profiles/` directory for available installation profiles:
- Base profiles for different environment types
- Catalyst-specific profiles for development workflows
- Test profiles for safe development

## Testing

No formal test framework - relies on manual verification of symlink creation and configuration deployment.

## Key Files

- `Taskfile.yml` - Build system configuration
- `install.conf.yaml` - Generated dotbot configuration (created dynamically)
- `profiles/*.yaml` - Installation profile definitions
- `Brewfile` - Package management for macOS
- `dotfiles/.gitconfig` - Git configuration template
- `dotfiles/.zshrc` - ZSH shell configuration entry point