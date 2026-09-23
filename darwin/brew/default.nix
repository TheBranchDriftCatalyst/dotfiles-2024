# Composable Homebrew bundles.
#
# Why not literal Brewfiles: nix-darwin already GENERATES a Brewfile from
# homebrew.{brews,casks,masApps} and runs `brew bundle` against it. Hand-written
# Brewfiles would mean giving up masApps handling and the cleanup ratchet below,
# so the bundles are plain Nix attrsets instead — same composability, none of
# the loss. Each ./<name>.nix returns { casks = [...]; brews = [...];
# taps = [...]; masApps = {...}; }, any key optional.
#
# A host picks bundles and adds its own one-offs:
#   catalyst.brew.bundles = [ "core" "dev" "security" "media" ];
#   catalyst.brew.extraCasks = [ "google-chrome" ];
{ lib, config, ... }:

let
  cfg = config.catalyst.brew;

  available = {
    core = import ./core.nix;
    dev = import ./dev.nix;
    security = import ./security.nix;
    media = import ./media.nix;
  };

  chosen = map (name: available.${name}) cfg.bundles;
  collect = key: lib.concatMap (b: b.${key} or [ ]) chosen;
in
{
  options.catalyst.brew = {
    bundles = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (lib.attrNames available));
      default = [ ];
      description = "Named bundles from darwin/brew/ to install on this host.";
    };
    extraCasks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Host-specific casks that don't belong in a shared bundle.";
    };
    extraBrews = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    extraMasApps = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = { };
    };
  };

  # ── Homebrew: GUI apps only ───────────────────────────────────────────
  # nix-darwin does NOT install Homebrew — it drives `brew bundle`. Brew must
  # already be present (it is). cleanup="zap" makes this genuinely declarative:
  # anything not listed here gets removed.
  config.homebrew = {
    enable = true;

    # Don't stamp com.apple.quarantine on casks. Brew downloads over TLS from
    # the vendor URL this config names — Gatekeeper's quarantine adds no trust
    # we don't already have, and it actively BREAKS self-updating casks: an
    # app flagged `auto_updates` (spotify) rewrites its own bundle in place,
    # the quarantine xattr stays on the stale container, and Gatekeeper then
    # reports "Apple cannot verify this app is free of malware" on every
    # launch. Trashing the app doesn't end it — brew's receipt survives, so
    # the next switch reinstalls it, freshly quarantined, and the loop repeats.
    #
    # GLOBAL on purpose — every cask gets this, and new ones should too.
    # Measured 2026-09-22: 18 of 19 declared casks are flagged `auto_updates`,
    # so all but `wakatime` hit the breakage above. Per-cask scoping was
    # considered and rejected: it would annotate 18 entries to preserve the
    # same behaviour and add a footgun for every cask added later.
    #
    # Cost, precisely: a newly installed cask skips the one-time "downloaded
    # from the Internet" prompt on FIRST launch. Not per-execution, and apps
    # already installed are unaffected — the xattr is written at install time.
    caskArgs.no_quarantine = true;

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

    # mas: the CLI `brew bundle` shells out to for masApps. Pinned explicitly
    # rather than trusting bundle's on-demand install of it.
    brews = [ "mas" ] ++ collect "brews" ++ cfg.extraBrews;
    casks = collect "casks" ++ cfg.extraCasks;
    # A bundle declares its own taps, so a cask that only exists in a third-party
    # tap travels with the tap it needs instead of relying on a global list that
    # nothing ties back to it.
    taps = collect "taps";
    masApps = lib.mkMerge (map (b: b.masApps or { }) chosen ++ [ cfg.extraMasApps ]);
  };

  # Belt to caskArgs' braces. `no_quarantine` stops brew stamping anything it
  # installs FROM NOW ON, but every cask installed before that landed is still
  # carrying the xattr, and a self-updating cask can re-acquire one behind
  # brew's back. This sweeps them after each `brew bundle` (activation-scripts
  # orders homebrew before postActivation), so the fix is self-healing instead
  # of a one-off command someone has to remember.
  #
  # Scope is deliberately narrow: ONLY bundles whose quarantine stamp names
  # Homebrew as the agent, plus the Caskroom itself. Apps that landed some
  # other way — MDM, a manual download — keep their quarantine, because
  # blanket-clearing /Applications would bless whatever happened to be sitting
  # there.
  #
  # Best-effort by design (every call is `|| true`): macOS App Management
  # (TCC) refuses xattr writes on some signed bundles no matter who asks. Those
  # are cleared the reliable way instead — `brew reinstall`, which now picks up
  # the no_quarantine cask_arg above and lays the app down unstamped.
  config.system.activationScripts.postActivation.text = lib.mkAfter ''
    # the download cache is where the poison actually pools: a stamped
    # tarball keeps re-infecting the app every reinstall, which is why a
    # plain `brew reinstall` never clears it
    #
    # Every xattr call ends in `|| true` and the whole block is `|| true`:
    # activation runs under `set -e`, and `[ -d x ] && cmd` does NOT protect
    # you — set -e exempts the TEST, but `cmd` is the last command in the
    # list, so ITS failure is fatal. xattr always exits non-zero here (TCC
    # refuses some bundle internals), which is enough to abort the whole
    # switch. A best-effort cleanup must never be able to fail a deploy.
    {
      for tree in ${config.homebrew.prefix}/Caskroom \
        /Users/${config.system.primaryUser}/Library/Caches/Homebrew/downloads; do
        if [ -d "$tree" ]; then
          /usr/bin/xattr -d -r com.apple.quarantine "$tree" >/dev/null 2>&1 || true
        fi
      done
    for app in /Applications/*.app; do
      [ -e "$app" ] || continue
      stamp=$(/usr/bin/xattr -p com.apple.quarantine "$app" 2>/dev/null) || continue
      case "$stamp" in
        # top level only, never -r: Gatekeeper reads the stamp on the bundle
        # directory, and recursing into a signed bundle trips App Management
        # (TCC) on every inner file for thousands of lines of noise.
        *Homebrew*) /usr/bin/xattr -d com.apple.quarantine "$app" >/dev/null 2>&1 || true ;;
        esac
      done
    } || true
  '';
}
