# Livery for teakbookM5DJ.
# (Devspace root and org layout are machine-agnostic now — ~/devspace with
# per-org subdirs, defaults in home/catalyst.nix; identity per org dir in
# home/contexts.nix. Nothing devspace-flavored left to override here.)
_:

{
  # mise — HOST-SCOPED on purpose. Only the work machine needs it: work repos
  # pin runtimes with .nvmrc / .python-version and must not be asked to adopt
  # nix. Personal machines stay nix-only; see the header in mise.nix.
  imports = [ ../../home/mise.nix ];

  # values live in palette.nix (plain attrset) so rice.nix — a darwin-layer
  # module that can't see HM config — colors the bar/borders from the same file
  catalyst.palette = import ./palette.nix;
}
