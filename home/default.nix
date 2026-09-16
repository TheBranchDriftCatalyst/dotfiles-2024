# Shared home-manager config — imported by BOTH the macOS and Linux entrypoints.
# Anything platform-specific belongs in darwin.nix / linux.nix, not here.
{ pkgs, lib, ... }:

{
  # NOTE: imports must be STATIC. Deriving them from stdenv.hostPlatform.isDarwin
  # causes infinite recursion (pkgs is a module arg, resolved after imports).
  # Platform modules are attached at the flake level instead.
  imports = [
    ./theme.nix
    ./contexts.nix
    ./packages.nix
    ./zsh.nix
    ./git.nix
    ./tmux.nix
    ./starship.nix
    ./neovim.nix
    ./catalyst.nix
    ./ghostty.nix
    ./vscode.nix
    ./claude.nix
    ./cli.nix
  ];

  home.username = lib.mkDefault "dj";
  home.homeDirectory = lib.mkDefault (
    if pkgs.stdenv.hostPlatform.isDarwin then "/Users/dj" else "/home/dj"
  );

  # Bump deliberately after reading the release notes; it is NOT "latest".
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  # HM's options manpage build rides nixpkgs' make-options-doc, which
  # triggers the "builtins.derivation ... options.json without a proper
  # context" eval warning on every build. Options get looked up online /
  # in source anyway — drop the manpage, drop the warning.
  manual.manpages.enable = false;

  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    PAGER = "less";
    LESSCHARSET = "utf-8";
    # word split: kept from the old .zprofile
    WORDCHARS = "*?_-.[]~=&;!#$%^(){}<>";
  };

  # Small static dotfiles — data in nix, payloads in ./dotfiles (named with
  # extensions so the IDE highlights them). NAMING: home/dotfiles = the STORE
  # payload set (read-only, rebuild-per-tweak); repo-root dotfiles/ = the LIVE
  # payload set (out-of-store symlinks, app-writable). Same word, two modes —
  # the directory you're in tells you which. Gone entirely: .dir_colors
  # (LS_COLORS via vivid in zsh.nix), .curlrc (once carried `-k`, disabling
  # TLS verification machine-wide), .obsidian.vimrc (plugin unused), and the
  # ~/.gitmessage link (git.nix points at the store copy).
  home.file.".editorconfig".source = ./dotfiles/editorconfig.ini;

  home.file.".prettierrc.yaml".source = (pkgs.formats.yaml { }).generate "prettierrc.yaml" {
    trailingComma = "es5";
    tabWidth = 2;
    semi = false;
    singleQuote = true;
  };

  home.sessionPath = [
    "$HOME/bin"
    "$HOME/.local/bin"
  ];
}
