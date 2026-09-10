# Directory-scoped IDENTITY — who git thinks you are, decided by where you cd.
#
# This is a per-DIRECTORY invariant, identical on every machine. Each entry
# renders a git includeIf block: enter a context's directory and its identity
# applies; everywhere else the base identity holds. Adding a context is one
# attrset entry — the machine never enters into it. (Machine look/livery is a
# separate invariant: theme.nix.)
{ lib, ... }:

{
  options.catalyst.git = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "DJ Daniels";
    };
    email = lib.mkOption {
      type = lib.types.str;
      default = "djdanielsh@gmail.com";
      description = "base identity — applies everywhere no context matches";
    };
    contexts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          dir = lib.mkOption {
            type = lib.types.str;
            description = "gitdir prefix (trailing slash) this context owns";
          };
          email = lib.mkOption { type = lib.types.str; };
          extraConfig = lib.mkOption {
            type = lib.types.attrs;
            default = { };
            description = "extra git config for this context (signingkey, …)";
          };
        };
      });
      default = {
        protecht = {
          dir = "~/catalyst-devspace/";
          email = "h.daniels@protecht.com";
        };
        # carve-out: the personal-org working repos INSIDE the work devspace.
        # git.nix renders contexts most-specific-last, so this deeper dir
        # wins over protecht for everything under catalyst/.
        catalyst = {
          dir = "~/catalyst-devspace/catalyst/";
          email = "djdanielsh@gmail.com"; # mirrors the base identity
        };
        # future contexts drop in here, e.g.:
        # teak = { dir = "~/teak/"; email = "..."; };
      };
    };
  };
}
