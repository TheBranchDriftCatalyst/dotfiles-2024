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

  catalyst.palette = {
    deep = "#010b06";     # near-black green
    mid = "#06331c";
    glow = "#39ff14";     # neon green horizon/glow
    sunTop = "#d4ff3f";   # acid yellow-green
    sunBot = "#00ff87";
    grid = "#39ff14";
    accent = "#5ee7ff";   # cyan counterpoint
    text = "TeakMaXXing";
  };
}
