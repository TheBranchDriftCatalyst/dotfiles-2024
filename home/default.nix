# Shared home-manager config — imported by BOTH the macOS and Linux entrypoints.
# Anything platform-specific belongs in darwin.nix / linux.nix, not here.
{ pkgs, lib, ... }:

{
  # NOTE: imports must be STATIC. Deriving them from pkgs.stdenv.isDarwin
  # causes infinite recursion (pkgs is a module arg, resolved after imports).
  # Platform modules are attached at the flake level instead.
  imports = [
    ./packages.nix
    ./zsh.nix
    ./git.nix
    ./tmux.nix
    ./starship.nix
    ./mise.nix
    ./neovim.nix
    ./catalyst.nix
    ./ghostty.nix
    ./vscode.nix
  ];

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
  # Small static dotfiles from the payload — pure store links.
  home.file.".curlrc".source = ../dotfiles/.curlrc;
  home.file.".dir_colors".source = ../dotfiles/.dir_colors;
  home.file.".editorconfig".source = ../dotfiles/.editorconfig;
  home.file.".prettierrc.yaml".source = ../dotfiles/.prettierrc.yaml;
  home.file.".obsidian.vimrc".source = ../dotfiles/.obsidian.vimrc;
  home.file.".gitmessage".source = ../dotfiles/.gitmessage;

  home.sessionPath = [
    "$HOME/bin"
    "$HOME/.local/bin"
  ];
}
