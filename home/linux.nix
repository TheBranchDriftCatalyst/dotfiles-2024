# Linux-only home-manager bits. Deliberately thin — the whole point of this
# rewrite is that the terminal is identical on both platforms.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # GNU userland is native here, so only genuinely Linux-only tools belong.
    xclip
  ];

  # Standalone home-manager doesn't manage the login shell; point the user at
  # the fix rather than silently doing nothing.
  home.activation.zshHint = ''
    if [ "$(basename "''${SHELL:-}")" != "zsh" ]; then
      echo "note: \$SHELL is not zsh — run: chsh -s $(command -v zsh)"
    fi
  '';
}
