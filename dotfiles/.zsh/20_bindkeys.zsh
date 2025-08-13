# 1) Emacs‐mode
bindkey -e

# 2) Plain arrow = char‐by‐char motion
# bindkey '\e[C' forward-char
# bindkey '\e[D' backward-char

# # 3) Ctrl+Arrow (CSI versions) → word‐jumps
# bindkey '\e[1;5C' forward-word
# bindkey '\e[1;5D' backward-word

# 4) VS Code mapping: Ctrl+→ → C-E,   Ctrl+← → C-A
bindkey '^E' forward-word    # Ctrl+E (VS Code’s Ctrl→)
bindkey '^A' backward-word   # Ctrl+A (VS Code’s Ctrl←)

# TODO: give some sweet output here