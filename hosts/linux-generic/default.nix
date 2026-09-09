# Linux host overrides for standalone home-manager.
#
# Standalone means this works on ANY distro — Debian, Ubuntu, Fedora, Arch —
# and on machines where you don't control the OS (work servers, containers).
# It manages your home directory only.
{ lib, ... }:

{
  home.username = lib.mkForce "dj";
  home.homeDirectory = lib.mkForce "/home/dj";

  # Fonts install into the user profile; refresh the cache so the terminal
  # actually picks up the nerd fonts without a re-login.
  home.activation.fontCache = ''
    if command -v fc-cache >/dev/null 2>&1; then
      $DRY_RUN_CMD fc-cache -f >/dev/null 2>&1 || true
    fi
  '';
}
