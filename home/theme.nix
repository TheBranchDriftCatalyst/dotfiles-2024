# The persona axis — orthogonal to the platform axis (hosts/*).
#
# hosts/* answers "how does this machine run" (arch, darwin/linux, casks).
# These options answer "who is this machine for": identity and palette.
# A host COMPOSES a persona: hosts/dj-mac/home.nix sets these, and modules
# like git.nix and the wallpaper consume them instead of hardcoding.
{ lib, ... }:

{
  options.catalyst = {
    identity = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "DJ Daniels";
      };
      email = lib.mkOption {
        type = lib.types.str;
        default = "djdanielsh@gmail.com";
        description = "primary (personal) git identity";
      };
      work = {
        email = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "h.daniels@protecht.com";
          description = "work identity; null disables the includeIf split";
        };
        dir = lib.mkOption {
          type = lib.types.str;
          default = "~/catalyst-devspace/";
          description = "gitdir prefix where the work identity applies";
        };
      };
    };

    # Wallpaper / accent palette. Defaults are the classic pink synthwave;
    # a host overrides these to re-skin the machine (see hosts/dj-mac).
    palette = {
      deep = lib.mkOption { type = lib.types.str; default = "#0d0221"; };
      mid = lib.mkOption { type = lib.types.str; default = "#2b0c4a"; };
      glow = lib.mkOption { type = lib.types.str; default = "#ff2e97"; };
      sunTop = lib.mkOption { type = lib.types.str; default = "#ffef00"; };
      sunBot = lib.mkOption { type = lib.types.str; default = "#ff2e97"; };
      grid = lib.mkOption { type = lib.types.str; default = "#ff2e97"; };
      accent = lib.mkOption { type = lib.types.str; default = "#5ee7ff"; };
    };
  };
}
