# Home directories redirected into Dropbox — catalystM5 ONLY.
#
# Deliberately host-scoped, not in home/darwin.nix: work machines must never
# get Dropbox-backed home directories. Importing this anywhere shared is a bug.
#
# These links predate nix (hand-made, years old) and already exist on this
# machine. The activation below ADOPTS them rather than replacing them — a
# correct link is left byte-identical and untouched, so a switch is a no-op
# once converged.
#
# Why an activation script and not home.file:
#   home.file/home.activation's file-linking machinery treats a pre-existing
#   path as a collision and moves it to .hm-bak. For SIX directories holding
#   years of real data that behaviour is actively dangerous — it would rename
#   the live Dropbox links out from under Finder and every open document.
#   This script instead inspects each path and only acts when it must.
#
# Safety rule: it NEVER deletes a real directory. If a path exists as actual
# content rather than a link, it warns and skips — resolving that is a human
# decision, not something a switch should do silently.
{ config, lib, ... }:

let
  dropbox = "${config.home.homeDirectory}/Library/CloudStorage/Dropbox";

  # <link under $HOME> = <path under Dropbox>
  #
  # NOTE Movies and Videos BOTH point at Dropbox/Videos. That mirrors the
  # pre-nix state exactly (macOS wants ~/Movies, the Dropbox folder is named
  # Videos) — it is deliberate, not drift. See dotfiles-rog.
  links = {
    "Documents" = "Documents";
    "Downloads" = "Downloads";
    "Pictures" = "Pictures";
    "Movies" = "Videos";
    "Videos" = "Videos";
    "Dropbox" = ""; # the root itself
  };

  mkLink =
    name: sub:
    let
      link = "${config.home.homeDirectory}/${name}";
      target = if sub == "" then dropbox else "${dropbox}/${sub}";
    in
    ''
      _link=${lib.escapeShellArg link}
      _target=${lib.escapeShellArg target}

      if [ ! -e "$_target" ] && [ ! -L "$_target" ]; then
        # Dropbox not synced yet (fresh machine, or CloudStorage not mounted).
        # Creating a link to a missing target would produce a broken link that
        # Dropbox then refuses to sync into. Skip and let the next switch do it.
        echo "dropbox-dirs: ✖ target missing, skipping ${name} -> $_target"
      elif [ -L "$_link" ]; then
        _current=$(readlink "$_link")
        if [ "$_current" = "$_target" ]; then
          : # already correct — ADOPTED, no action, no churn
        else
          echo "dropbox-dirs: repointing ${name} ($_current -> $_target)"
          $DRY_RUN_CMD ln -sfn "$_target" "$_link"
        fi
      elif [ -e "$_link" ]; then
        # Real directory or file with content. Never clobber this.
        echo "dropbox-dirs: ✖ ${name} exists as real content, NOT a link — skipping."
        echo "dropbox-dirs:   move it aside by hand if you want it Dropbox-backed."
      else
        echo "dropbox-dirs: linking ${name} -> $_target"
        $DRY_RUN_CMD ln -s "$_target" "$_link"
      fi
    '';
in
{
  home.activation.dropboxDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatStringsSep "\n" (lib.mapAttrsToList mkLink links)
  );
}
