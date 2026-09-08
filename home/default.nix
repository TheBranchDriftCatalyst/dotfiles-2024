# Shared home-manager config — imported by BOTH the macOS and Linux entrypoints.
# Anything platform-specific belongs in darwin.nix / linux.nix, not here.
{ pkgs, lib, ... }:

{
  imports = [
    ./packages.nix
    ./zsh.nix
    ./git.nix
    ./tmux.nix
    ./starship.nix
    ./neovim.nix
    ./catalyst.nix
    ./ghostty.nix
  ]
  ++ lib.optional pkgs.stdenv.isDarwin ./darwin.nix
  ++ lib.optional pkgs.stdenv.isLinux ./linux.nix;

  home.username = lib.mkDefault "dj";
  home.homeDirectory = lib.mkDefault (
    if pkgs.stdenv.isDarwin then "/Users/dj" else "/home/dj"
  );

  # Bump deliberately after reading the release notes; it is NOT "latest".
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    PAGER = "less";
    LESSCHARSET = "utf-8";
    # word split: kept from the old .zprofile
    WORDCHARS = "*?_-.[]~=&;!#$%^(){}<>";
  };

  # @cli-tools/bin is appended by catalyst.nix, which owns that option.
  home.sessionPath = [
    "$HOME/bin"
    "$HOME/.local/bin"
  ];
}
