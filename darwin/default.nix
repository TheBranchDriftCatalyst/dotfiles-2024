# macOS system configuration (nix-darwin) — SHARED across every darwin host.
#
# Everything here replaces etc/provision/80_macos.sh, which was a pile of
# imperative `defaults write` calls you had to remember to re-run.
#
# This is the darwin-layer twin of home/: hosts/<name>/default.nix carries only
# what is genuinely per-machine (hostname, user, palette, bundle picks) and
# everything else lives here. Before this split the two hosts' default.nix were
# 187 and 188 lines that differed by a username, a hostname and one cask.
#
# User-scoped paths derive from system.primaryUser — never hardcode /Users/<name>.
{ pkgs, config, ... }:

{
  imports = [
    ./theme.nix
    ./rice.nix
    ./brew
  ];

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
  };

  users.users.${config.system.primaryUser}.home = "/Users/${config.system.primaryUser}";

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
        location = "/Users/${config.system.primaryUser}/Screenshots";
        type = "png";
        disable-shadow = true; # window shots without the huge drop shadow
        show-thumbnail = false; # skip the floating preview; file lands instantly
      };
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
