# ============================
# Completion Menu Behavior
# ============================

# Enable menu selection mode for completions with a minimum of 2 matches
zstyle ':completion:*:default' menu select=2
# Example: Typing `git che` and pressing Tab will show a menu with completions like `checkout`, `cherry-pick`, etc.

# ============================
# Option Descriptions and Formatting
# ============================

# Enable descriptions for options
zstyle ':completion:*:options' description 'yes'
# Example: When completing options for a command, descriptions will be shown.

# Format for displaying descriptions
zstyle ':completion:*:descriptions' format '%F{yellow}Completing %B%d%b%f'
# Example: Descriptions will appear in yellow and bold, e.g., "Completing -a: Show all".

# ============================
# Grouping and Matching
# ============================

# Group completions by their type (e.g., commands, files)
zstyle ':completion:*' group-name ''
# Example: Completions will be grouped under headings like "Commands", "Files", etc.

# Define matcher list for case-insensitive matching
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# Example: Typing `cd doc` will match `Documents` and `docs`.

# ============================
# Completers and Verbosity
# ============================

# Enable verbose output for completions
zstyle ':completion:*' verbose yes
# Example: Additional information about matches will be displayed.

# Define the order of completers
zstyle ':completion:*' completer _expand _complete _match _prefix _approximate _list _history
# Example: This order determines how completions are generated and matched.

# ============================
# File Completion Settings
# ============================

# Ignore certain file patterns during completion
zstyle ':completion:*:*files' ignored-patterns '*?.o' '*?~' '*\#'
# Example: Files ending with `.o`, `~`, or `#` will be excluded from file completions.

# Enable caching for file completions
zstyle ':completion:*' use-cache true
# Example: Previously completed file paths will be cached for faster future completions.

# ============================
# Directory Completion
# ============================

# Ignore parent directories in path completion
zstyle ':completion:*:cd:*' ignore-parents parent pwd
# Example: When completing a directory path, `..` and the current directory will be excluded.

# Set directory listing colors
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# Example: Directories will be displayed in blue, executables in green, etc., based on `LS_COLORS`.

# ============================
# Separator and Manual Pages
# ============================

# Set the separator for completion lists
zstyle ':completion:*' list-separator '-->'
# Example: Completion lists will be separated by `-->`.

# Separate sections in manual page completions
zstyle ':completion:*:manuals' separate-sections true
# Example: Manual pages will be grouped by section (e.g., `1`, `2`, `3`).

# ============================
# Menu Selection Key Bindings
# ============================

# Load the completion list module
zmodload -i zsh/complist

# Bind keys for menu selection navigation
bindkey -M menuselect '^h' vi-backward-char
bindkey -M menuselect '^j' vi-down-line-or-history
bindkey -M menuselect '^k' vi-up-line-or-history
bindkey -M menuselect '^l' vi-forward-char
# Example: These bindings allow navigation through the completion menu using `Ctrl+h`, `Ctrl+j`, `Ctrl+k`, and `Ctrl+l`.

# ============================
# Autoloaded Functions
# ============================

# Autoload various utility functions
autoload -Uz cdr history-search-end modify-current-argument smart-insert-last-word terminfo vcs_info zcalc zmv run-help-git run-help-svk run-help-svn
# Example: These functions provide additional capabilities like directory navigation, history search, argument modification, and version control integration.

# ============================
# URL Escaping
# ============================

# Autoload URL quoting function
autoload -Uz url-quote-magic

# Bind the URL quoting function to the self-insert widget
zle -N self-insert url-quote-magic
# Example: Automatically escapes URLs when typing them, useful for copying and pasting URLs into the terminal.

# ============================
# Prompt Customization
# ============================

# Source the Powerlevel10k prompt configuration if it exists
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# Example: If the `~/.p10k.zsh` file exists, it will be sourced to customize the Zsh prompt.
