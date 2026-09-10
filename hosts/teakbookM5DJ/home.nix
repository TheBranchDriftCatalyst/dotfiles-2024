# Livery + devspace naming for teakbookM5DJ.
# (Identity stays directory-scoped and machine-agnostic in home/contexts.nix —
# the devspace NAME is the machine-flavored part: work box = teak-devspace,
# with the personal org carved out under catalyst/.)
_:

{
  catalyst.devspace = {
    root = "teak-devspace";
    orgSubdir = "catalyst";
  };

  # values live in palette.nix (plain attrset) so rice.nix — a darwin-layer
  # module that can't see HM config — colors the bar/borders from the same file
  catalyst.palette = import ./palette.nix;
}
