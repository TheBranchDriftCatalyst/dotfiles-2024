# catalystM5 — per-machine identity ONLY.
#
# Every macOS default, the rice stack and the brew plumbing live in ../../darwin
# (wired in by flake.nix, the same way ./home is wired into home-manager).
# If something here is true of every Mac, it belongs there instead.
_:

{
  # Matches `hostname -s`, so darwin-rebuild's hostname-based auto-selection
  # finds this config with no #target: `darwin-rebuild switch --flake .`
  # (LocalHostName is still the stock `bfmac-2`; -s is what nix-darwin reads.)
  networking.hostName = "catalystM5";

  # nix-darwin activation runs as root now; user-scoped options (homebrew,
  # dock/finder defaults, screencapture) apply to this user.
  system.primaryUser = "panda";

  catalyst = {
    # the darwin half of the livery; hosts/catalystM5/home.nix feeds the same
    # file to home-manager's catalyst.palette
    palette = import ./palette.nix;

    brew = {
      bundles = [
        "core"
        "dev"
        "security"
        "media"
      ];
      extraCasks = [ "google-chrome" ];
    };
  };
}
