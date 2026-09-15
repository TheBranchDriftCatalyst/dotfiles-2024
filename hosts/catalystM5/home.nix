# Livery for catalystM5.
# (Devspace root and org layout are machine-agnostic — ~/devspace with
# per-org subdirs, defaults in home/catalyst.nix; identity per org dir in
# home/contexts.nix. Nothing devspace-flavored left to override here.)
_:

{
  # values live in palette.nix (plain attrset) so rice.nix — a darwin-layer
  # module that can't see HM config — colors the bar/borders from the same file
  catalyst.palette = import ./palette.nix;
}
