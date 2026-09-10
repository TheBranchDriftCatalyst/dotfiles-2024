# Machine LIVERY — the palette that identifies which box you're on.
#
# This is a per-MACHINE invariant, set in hosts/<hostname>/home.nix and
# consumed by the wallpaper generator (and future theming). It says nothing
# about who you are or what you're working on — identity is a per-DIRECTORY
# invariant and lives in contexts.nix. The two never combine.
{ lib, ... }:

{
  options.catalyst.palette = {
    deep = lib.mkOption { type = lib.types.str; default = "#0d0221"; };
    mid = lib.mkOption { type = lib.types.str; default = "#2b0c4a"; };
    glow = lib.mkOption { type = lib.types.str; default = "#ff2e97"; };
    sunTop = lib.mkOption { type = lib.types.str; default = "#ffef00"; };
    sunBot = lib.mkOption { type = lib.types.str; default = "#ff2e97"; };
    grid = lib.mkOption { type = lib.types.str; default = "#ff2e97"; };
    accent = lib.mkOption { type = lib.types.str; default = "#5ee7ff"; };
    text = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "livery title overlaid on the wallpaper (rendered caps, chrome+glow)";
    };
  };
}
