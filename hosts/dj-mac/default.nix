# macOS system configuration (nix-darwin).
#
# Everything here replaces etc/provision/80_macos.sh, which was a pile of
# imperative `defaults write` calls you had to remember to re-run.
{ pkgs, ... }:

{
  system.stateVersion = 5;
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  users.users.dj.home = "/Users/dj";

  # nix-darwin activation runs as root now; user-scoped options (homebrew,
  # dock/finder defaults, screencapture) apply to this user.
  system.primaryUser = "dj";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "dj" ];
  };

  programs.zsh.enable = true;   # ensure /etc/zshrc sources the nix profile

  # ── macOS defaults ────────────────────────────────────────────────────
  system.defaults = {
    NSGlobalDomain = {
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      ApplePressAndHoldEnabled = false;
      AppleShowAllExtensions = true;
      NSDocumentSaveNewDocumentsToCloud = false;
    };

    finder = {
      AppleShowAllFiles = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXEnableExtensionChangeWarning = false;
    };

    dock = {
      autohide = true;
      show-recents = false;
    };

    screencapture = {
      location = "/Users/dj/Screenshots";
      type = "png";
    };
  };

  # ── Homebrew: GUI apps only ───────────────────────────────────────────
  # nix-darwin does NOT install Homebrew — it drives `brew bundle`. Brew must
  # already be present (it is). cleanup="zap" makes this genuinely declarative:
  # anything not listed here gets removed.
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = false;
      upgrade = false;
    };

    casks = [
      "ghostty"                  # nixpkgs' ghostty is Linux-only
      "visual-studio-code"
      "jetbrains-toolbox"
      "docker"
      "insomnia"
      "postman"
      "dash"
      "1password"
      "gpg-suite"
      "firefox"
      "alfred"
      "rectangle-pro"
      "obsidian"
      "notion"
      "spotify"
      "wakatime"

      # Kernel/system extensions — these can NEVER be Nix packages.
      "little-snitch"
    ];

    masApps = {
      Fantastical = 975937182;
      Yoink = 457622435;
    };
  };

  # NOTE deliberately NOT casks anymore — nixpkgs supplies these:
  #   font-hack-nerd-font, font-3270-nerd-font -> home/packages.nix
  #   1password-cli, ngrok, session-manager-plugin
  #   iterm2 -> replaced by ghostty

  fonts.packages = with pkgs; [
    nerd-fonts.hack
    nerd-fonts._3270
  ];
}
