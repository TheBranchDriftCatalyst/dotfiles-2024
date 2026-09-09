# Per-host PERSONA overrides for dj-mac — the axis orthogonal to platform.
# Platform (arch, casks, defaults) lives in ./default.nix; identity and
# palette live here. This machine: personal identity, green-primary skin.
_:

{
  catalyst.palette = {
    deep = "#010b06";     # near-black green
    mid = "#06331c";
    glow = "#39ff14";     # neon green horizon/glow
    sunTop = "#d4ff3f";   # acid yellow-green
    sunBot = "#00ff87";
    grid = "#39ff14";
    accent = "#5ee7ff";   # cyan stays as the counterpoint
  };
  # identity: defaults from home/theme.nix (personal + protecht includeIf)
}
