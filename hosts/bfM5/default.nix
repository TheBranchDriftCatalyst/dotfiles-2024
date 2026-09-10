# macOS system configuration (nix-darwin).
#
# Everything here replaces etc/provision/80_macos.sh, which was a pile of
# imperative `defaults write` calls you had to remember to re-run.
{ pkgs, ... }:

{
  imports = [ ./rice.nix ];

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
  };

  users.users.panda.home = "/Users/panda";

  # Declared hostname — this machine had drifted into three conflicting
  # names (bfM5 / takbookM5 / djTeakbook). One name, everywhere,
  # and darwin-rebuild's hostname-based config auto-selection becomes
  # deterministic: `darwin-rebuild switch --flake .` needs no #target.
  networking.hostName = "bfM5";

  # Determinate Nix manages the daemon and nix.conf itself (flakes are on by
  # default there); nix-darwin must not fight it — its native Nix management
  # aborts activation when determinate-nixd is detected.
  nix.enable = false;

  programs.zsh.enable = true;   # ensure /etc/zshrc sources the nix profile

  # nix-darwin's options manual builds an options.json via builtins.derivation
  # with an uncontexted nixpkgs path — upstream bug, warns on every eval.
  # The manpages aren't used here (options get looked up in the source /
  # online), so drop the docs build and the warning with it.
  documentation.enable = false;

  # ── macOS defaults ────────────────────────────────────────────────────
  system = {
    stateVersion = 5;
    # nix-darwin activation runs as root now; user-scoped options (homebrew,
    # dock/finder defaults, screencapture) apply to this user.
    primaryUser = "panda";

    defaults = {
      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";      # system-wide dark mode
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
        # Declared dock = the ONLY pinned apps. Everything Apple ships pinned
        # (Safari, Messages, Mail, Maps, Photos, TV, News…) is removed on
        # switch. Add/remove lines here, not by dragging — a switch resets it.
        persistent-apps = [
          "/Applications/Ghostty.app"
          "/Applications/Visual Studio Code.app"
          "/Applications/Google Chrome.app"
        ];
      };

      screencapture = {
        location = "/Users/panda/Screenshots";
        type = "png";
      };
    };
  };

  # ── Homebrew: GUI apps only ───────────────────────────────────────────
  # nix-darwin does NOT install Homebrew — it drives `brew bundle`. Brew must
  # already be present (it is). cleanup="zap" makes this genuinely declarative:
  # anything not listed here gets removed.
  homebrew = {
    enable = true;
    onActivation = {
      # "none": casks in this list get installed, but nothing undeclared is
      # ever removed — brew can drift. Ratchet back up when the list feels
      # complete: "uninstall" (remove undeclared, keep their data) or "zap"
      # (remove + purge app data — deletes trial installs on every switch).
      cleanup = "none";
      # Every switch also refreshes brew's index and upgrades outdated casks.
      # Trade-off, chosen deliberately: switches are slower and may change
      # apps beyond the config diff, but casks never drift stale. Flip both
      # to false if a config-only switch surprising you with an app upgrade
      # ever bites.
      autoUpdate = true;
      upgrade = true;
    };

    # NOT docker — Docker Desktop is replaced by colima (home/darwin.nix);
    # the Desktop app and colima fight over the docker socket/context.
    casks = [
      "ghostty"                  # nixpkgs' ghostty is Linux-only
      "stats"                    # free open-source iStat Menus (exelban/stats)
      "visual-studio-code"
      "jetbrains-toolbox"
      "insomnia"
      "postico"
      "postman"
      "dash"
      "1password"
      "gpg-suite"
      "firefox"
      "google-chrome"
      "alfred"
      "rectangle-pro"
      "obsidian"
      "notion"
      "spotify"
      "wakatime"
      "veracrypt"

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
