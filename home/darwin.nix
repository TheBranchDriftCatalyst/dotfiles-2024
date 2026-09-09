# macOS-only home-manager bits.
{ pkgs, lib, config, dotfilesRepo, ... }:
let
  repo = "${config.home.homeDirectory}/${dotfilesRepo}";
  wallpaper = "${config.home.homeDirectory}/Pictures/catalyst-synthwave.png";
in
{
  # Container runtime: colima (replaces Docker Desktop, which self-destructed
  # mid-session). `colima start --kubernetes` gives k3s inside the VM —
  # replacing minikube/k3d from the old setup.
  home = {
    # Container runtime CLI stack; colima provides the daemon.
    packages = with pkgs; [
      colima
      docker
      docker-buildx
      docker-compose
    ];

    # Homebrew's bin dir still needs to be on PATH: nix-darwin drives brew
    # for GUI casks (it does not, and cannot, install them itself).
    sessionPath = [ "/opt/homebrew/bin" "/opt/homebrew/sbin" ];

    # Wallpaper is generated, not stored — scripts/gen-wallpaper.py is ~90
    # lines of stdlib Python (the repo's pre-commit blocks binaries >1MB,
    # and code beats a blob). Regenerate by deleting the PNG and switching.
    activation.wallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "${wallpaper}" ]; then
        echo "wallpaper: generating…"
        $DRY_RUN_CMD mkdir -p "$(dirname "${wallpaper}")"
        $DRY_RUN_CMD ${pkgs.python3}/bin/python3 \
          "${repo}/scripts/gen-wallpaper.py" "${wallpaper}" 3456x2234 \
          || echo "wallpaper: ✖ generation failed"
      fi
      if [ -f "${wallpaper}" ]; then
        $DRY_RUN_CMD /usr/bin/osascript -e \
          'tell application "System Events" to set picture of every desktop to "'"${wallpaper}"'"' \
          2>/dev/null || echo "wallpaper: could not set (System Events permission?)"
      fi
    '';
  };

}
