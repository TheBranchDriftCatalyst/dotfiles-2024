# Machine LIVERY at the DARWIN layer — the darwin-module twin of home/theme.nix.
#
# Two module systems, two option trees: home/theme.nix declares
# `catalyst.palette` for home-manager (wallpaper, ghostty, nvim…), this file
# declares the same shape for nix-darwin (sketchybar, jankyborders). A host
# feeds both from the one `hosts/<name>/palette.nix` attrset — home.nix sets
# the HM copy, default.nix sets this one. Same values, same names, and the
# defaults below are kept in sync with home/theme.nix on purpose.
{ lib, ... }:

let
  colour =
    default:
    lib.mkOption {
      type = lib.types.str;
      inherit default;
    };
in
{
  options.catalyst.palette = {
    deep = colour "#0d0221";
    mid = colour "#2b0c4a";
    glow = colour "#ff2e97";
    sunTop = colour "#ffef00";
    sunBot = colour "#ff2e97";
    grid = colour "#ff2e97";
    accent = colour "#5ee7ff";
    text = lib.mkOption {
      type = lib.types.str;
      default = "Default Maxxing";
      description = "livery title overlaid on the wallpaper (rendered caps, chrome+glow)";
    };
  };
}
