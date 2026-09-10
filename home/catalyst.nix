# devspace wiring — owns DEV_SPACE_ROOT and the dotbot-git repo cloning,
# which has no home-manager equivalent.
# The devspace is NAMED for the machine's home context (work box:
# teak-devspace, personal: catalyst-devspace) — hosts override the two
# options below. Identity mapping for both layouts lives in contexts.nix.
# NOTE: @cli-tools/bin is deliberately NOT on PATH anymore (2026-09) — the
# bin-dir pattern is retired; those tools get a modular repackaging (DJ's).
{ pkgs, lib, config, ... }:

let
  cfg = config.catalyst.devspace;
  devspace = "${config.home.homeDirectory}/${cfg.root}";
  # where the personal-org (@-prefixed) working repos live: a carve-out
  # subdir on the work machine, the devspace root itself on the personal one
  orgDir = if cfg.orgSubdir == null then devspace else "${devspace}/${cfg.orgSubdir}";
in
{
  options.catalyst.devspace = {
    root = lib.mkOption {
      type = lib.types.str;
      default = "catalyst-devspace";
      description = "devspace folder name under $HOME, named for the machine's home context";
    };
    orgSubdir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "subdir holding the personal-org repos (null = devspace root)";
    };
  };

  config = {
    home.sessionVariables.DEV_SPACE_ROOT = devspace;

    # dotbot's `git:` directive cloned @cli-tools / @machines / @secrets. These
    # are working repos you commit to, so they must NOT become read-only store
    # paths via flake inputs — an activation script preserves the semantics.
    # (@dotfiles moved OUT to ~/.dotfiles, 2026-09 — the org dir holds the
    # personal-org working repos only, and contexts.nix carves it out of the
    # work git identity.)
    # TODO: need to add some tender love and care here, yea this is going to entirely change
    # we are going to get rid of these and we are goign to install the cli tool i built instead
    home.activation.catalystRepos =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _clone() {
          local dest="$1" url="$2"
          if [ ! -d "$dest/.git" ]; then
            $DRY_RUN_CMD ${pkgs.git}/bin/git clone --quiet "$url" "$dest" || \
              echo "  warn: could not clone $url"
          fi
        }
        $DRY_RUN_CMD mkdir -p ${orgDir}
        _clone "${orgDir}/@cli-tools" "https://github.com/TheBranchDriftCatalyst/cli-tools.git"
        _clone "${orgDir}/@machines"  "https://github.com/TheBranchDriftCatalyst/machines.git"
        _clone "${orgDir}/@secrets"   "https://github.com/TheBranchDriftCatalyst/secrets.git"
      '';
  };
}
