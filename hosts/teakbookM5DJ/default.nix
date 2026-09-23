# teakbookM5DJ — per-machine identity ONLY.
#
# Every macOS default, the rice stack and the brew plumbing live in ../../darwin
# (wired in by flake.nix, the same way ./home is wired into home-manager).
# If something here is true of every Mac, it belongs there instead.
_:

{
  # Declared hostname — this machine had drifted into three conflicting
  # names (teakbookM5DJ / takbookM5 / DJTeakbook). One name, everywhere,
  # and darwin-rebuild's hostname-based config auto-selection becomes
  # deterministic: `darwin-rebuild switch --flake .` needs no #target.
  networking.hostName = "teakbookM5DJ";

  # nix-darwin activation runs as root now; user-scoped options (homebrew,
  # dock/finder defaults, screencapture) apply to this user.
  system.primaryUser = "dj";

  catalyst = {
    # the darwin half of the livery; hosts/teakbookM5DJ/home.nix feeds the same
    # file to home-manager's catalyst.palette
    palette = import ./palette.nix;

    brew = {
      bundles = [
        "core"
        "dev"
        "security"
        "media"
      ];
      # NOT google-chrome — Addigy (MDM) deploys it root-owned into
      # /Applications; brew's upgrade needs sudo it can't prompt for during
      # activation, so every switch fails. Addigy + Chrome's own updater keep
      # it current. (The dock still pins it: the app IS there, just not ours.)
    };
  };
}
