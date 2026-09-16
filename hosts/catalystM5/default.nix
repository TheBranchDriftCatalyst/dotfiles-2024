# macOS system configuration (nix-darwin) — catalystM5.
#
# Everything here replaces etc/provision/80_macos.sh, which was a pile of
# imperative `defaults write` calls you had to remember to re-run.
{ pkgs, ... }:

{
  # Rice stack (AeroSpace + JankyBorders + SketchyBar) — tiling WM + focus
  # glow + menu-bar replacement, all colored from palette.nix
  imports = [ ./rice.nix ];

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
  };

  users.users.panda.home = "/Users/panda";

  # Matches `hostname -s`, so darwin-rebuild's hostname-based auto-selection
  # finds this config with no #target: `darwin-rebuild switch --flake .`
  # (LocalHostName is still the stock `bfmac-2`; -s is what nix-darwin reads.)
  networking.hostName = "catalystM5";

  # Determinate Nix manages the daemon and nix.conf itself (flakes are on by
  # default there); nix-darwin must not fight it — its native Nix management
  # aborts activation when determinate-nixd is detected.
  nix.enable = false;

  programs.zsh.enable = true; # ensure /etc/zshrc sources the nix profile

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
        AppleInterfaceStyle = "Dark"; # system-wide dark mode
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
        ApplePressAndHoldEnabled = false;
        AppleShowAllExtensions = true;
        NSDocumentSaveNewDocumentsToCloud = false;
        # macOS "smart" text meddling corrupts anything pasted into a form or
        # chat that happens to be code — quotes/dashes/periods stay literal
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        # save dialogs open expanded instead of the collapsed mini panel
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        NSTableViewDefaultSizeMode = 1; # small sidebar icons
      };

      finder = {
        AppleShowAllFiles = true; # needs a Finder relaunch to bite
        ShowPathbar = true;
        ShowStatusBar = true;
        FXEnableExtensionChangeWarning = false;
        _FXShowPosixPathInTitle = true; # full path in the window title
        FXDefaultSearchScope = "SCcf"; # search the current folder, not the Mac
        FXPreferredViewStyle = "Nlsv"; # list view by default
        QuitMenuItem = true; # Finder gets a real Cmd-Q
        NewWindowTarget = "Home"; # new windows open ~, not Recents
        _FXSortFoldersFirst = true; # folders sort above files
      };

      ActivityMonitor = {
        ShowCategory = 100; # all processes, not just mine
        SortColumn = "CPUUsage";
        SortDirection = 0;
      };

      CustomUserPreferences = {
        # keep .DS_Store droppings off network shares and USB drives
        "com.apple.desktopservices" = {
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        # stop offering every plugged-in disk as a backup target
        "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
        "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
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
        disable-shadow = true; # window shots without the huge drop shadow
        show-thumbnail = false; # skip the floating preview; file lands instantly
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

    # mas: the CLI `brew bundle` shells out to for masApps below. Pinned
    # explicitly rather than trusting bundle's on-demand install of it.
    brews = [ "mas" ];

    # NOT docker — Docker Desktop is replaced by colima (home/darwin.nix);
    # the Desktop app and colima fight over the docker socket/context.
    casks = [
      "ghostty" # nixpkgs' ghostty is Linux-only
      "stats" # free open-source iStat Menus (exelban/stats)
      "visual-studio-code"
      "jetbrains-toolbox"
      "insomnia"
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

      # Kernel/system extensions — these can NEVER be Nix packages.
      "little-snitch"
      # virtual HID driver; its config is managed in home/karabiner.nix
      "karabiner-elements"
    ];

    masApps = {
      Fantastical = 975937182;
      Yoink = 457622435;
      # no cask exists and it's not in nixpkgs — MAS is the only managed lane
      PDFgear = 6469021132;
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
