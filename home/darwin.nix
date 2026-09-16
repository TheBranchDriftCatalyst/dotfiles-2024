# macOS-only home-manager bits.
{
  pkgs,
  lib,
  config,
  dotfilesRepo,
  ...
}:
let
  repo = "${config.home.homeDirectory}/${dotfilesRepo}";
  pal = config.catalyst.palette;
  paletteStr = lib.concatStringsSep "," (
    map (lib.removePrefix "#") [
      pal.deep
      pal.mid
      pal.glow
      pal.sunTop
      pal.sunBot
      pal.grid
      pal.accent
    ]
  );
  # Filename carries the palette hash: changing the palette in a host
  # config automatically renders a fresh wallpaper on the next switch.
  palHash = builtins.substring 0 8 (builtins.hashString "sha256" (paletteStr + pal.text));
  wallpaper = "${config.home.homeDirectory}/Pictures/catalyst-${palHash}.png";
in
{
  # Finder right-click Quick Actions (image resize/convert/halve) — .workflow
  # bundles generated from nix, no Automator involved.
  imports = [
    ./quick-actions.nix
    # Keyboard remapping. macOS-only by nature — the app is a system-extension
    # cask, declared in hosts/<host>/default.nix.
    ./karabiner.nix
  ];

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
    sessionPath = [
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
    ];

    # Wallpaper is generated, not stored — scripts/gen-wallpaper.py is ~90
    # lines of stdlib Python (the repo's pre-commit blocks binaries >1MB,
    # and code beats a blob). Regenerate by deleting the PNG and switching.
    activation.wallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "${wallpaper}" ]; then
        echo "wallpaper: generating…"
        $DRY_RUN_CMD mkdir -p "$(dirname "${wallpaper}")"
        $DRY_RUN_CMD ${pkgs.python3}/bin/python3 \
          "${repo}/scripts/gen-wallpaper.py" "${wallpaper}" 3456x2234 "${paletteStr}" "${pal.text}" \
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
