# catalyst devspace wiring — replaces .zsh/80_catalyst.zsh's PATH handling
# and the dotbot-git repo cloning, which has no home-manager equivalent.
{ pkgs, lib, config, ... }:

let
  devspace = "${config.home.homeDirectory}/catalyst-devspace";
in
{
  home.sessionVariables.DEV_SPACE_ROOT = devspace;

  home.sessionPath = [ "${devspace}/catalyst/@cli-tools/bin" ];

  # dotbot's `git:` directive cloned @cli-tools / @machines / @secrets. These
  # are working repos you commit to, so they must NOT become read-only store
  # paths via flake inputs — an activation script preserves the semantics.
  home.activation.catalystRepos =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      _clone() {
        local dest="$1" url="$2"
        if [ ! -d "$dest/.git" ]; then
          $DRY_RUN_CMD ${pkgs.git}/bin/git clone --quiet "$url" "$dest" || \
            echo "  warn: could not clone $url"
        fi
      }
      $DRY_RUN_CMD mkdir -p ${devspace}/catalyst
      _clone "${devspace}/catalyst/@cli-tools" "https://github.com/TheBranchDriftCatalyst/cli-tools.git"
      _clone "${devspace}/catalyst/@machines"  "https://github.com/TheBranchDriftCatalyst/machines.git"
      _clone "${devspace}/catalyst/@secrets"   "https://github.com/TheBranchDriftCatalyst/secrets.git"
    '';
}
