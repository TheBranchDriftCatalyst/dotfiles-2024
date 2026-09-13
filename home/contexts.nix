# Directory-scoped IDENTITY — who git thinks you are, decided by where you cd.
#
# This is a per-DIRECTORY invariant, identical on every machine. Each entry
# renders a git includeIf block: enter a context's directory and its identity
# applies; everywhere else the base identity holds. Adding a context is one
# attrset entry — the machine never enters into it. (Machine look/livery is a
# separate invariant: theme.nix.)
#
# The devspace root is the SAME on every machine now (~/devspace) and each
# organization is a directory under it, so identity is purely org-scoped:
#   ~/devspace/teak/      → work identity
#   ~/devspace/catalyst/  → personal identity (mirrors the base)
# Everything else — including the catalyst tool's own repo at ~/devspace/.wt —
# gets the base (personal) identity. catalyst's bare mirrors live INSIDE each
# org dir (<org>/.cache/<repo>.git), which is what makes these includeIf
# blocks cover worktrees too: a worktree resolves identity through its common
# (bare) git dir.
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
      type = lib.types.attrsOf (
        lib.types.submodule {
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
        }
      );
      default = {
        # the work org — the only place the work identity applies
        teak = {
          dir = "~/devspace/teak/";
          email = "h.daniels@protecht.com";
        };
        # the personal org — mirrors the base identity, kept explicit so the
        # mapping reads as a complete org→identity table
        catalyst = {
          dir = "~/devspace/catalyst/";
          email = "djdanielsh@gmail.com";
        };
      };
    };
  };
}
