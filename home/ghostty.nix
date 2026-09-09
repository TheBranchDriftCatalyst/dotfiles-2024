# ghostty — replaces iTerm2, whose config was 100% manual (colour schemes were
# imported by hand through Preferences).
#
# NOTE: nixpkgs' ghostty is Linux-only; the macOS build needs Xcode and ships
# as a signed app. So on darwin the BINARY comes from a Homebrew cask (see
# hosts/dj-mac) while the CONFIG is still managed here — declarative either way.
{ pkgs, lib, ... }:

{
  programs.ghostty = {
    enable = true;
    package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty;
    enableZshIntegration = true;

    settings = {
      # Ghostty bundles all the schemes from the old etc/iterm2 collection —
      # "Synthwave Everything", "Synthwave Alpha", "TokyoNight Storm", "Nord",
      # "Nordfox". Names are the display names, spaces included.
      theme = "Synthwave Everything";
      font-family = "Hack Nerd Font";
      font-size = 13;

      window-padding-x = 8;
      window-padding-y = 8;
      window-save-state = "always";
      macos-option-as-alt = true;

      cursor-style = "block";
      shell-integration = "zsh";
      copy-on-select = true;
      confirm-close-surface = false;
    };
  };
}
