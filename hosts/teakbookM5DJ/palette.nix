# teakbookM5DJ livery values — a PLAIN attrset (no module machinery) so both
# layers can import it: home.nix feeds catalyst.palette (HM), rice.nix colors
# the darwin-level bar/borders. One source of truth for the machine's neon.
#
# Retro-Synth conversion (2026-09): depth layers follow the IDE's Retro Synth
# Cyan theme (true black ground, dark synth purple mid); TEAK NEON GREEN stays
# the primary — the glow/grid identity says which machine this is, the theme
# only says how dark the room is. Accents borrow the theme's exact values.
{
  deep = "#000000"; # the IDE's editor black — one ground across bar/wallpaper/terminal
  mid = "#0d0221"; # dark synth purple (retro-synth depth layer)
  glow = "#39ff14"; # TEAK neon green — the machine's primary, unchanged
  sunTop = "#d4ff3f"; # acid yellow-green
  sunBot = "#00d836"; # retro-synth terminal green (was #00ff87)
  grid = "#39ff14";
  accent = "#5ccaef"; # retro-synth blue-cyan counterpoint (was #5ee7ff)
  text = "TeakMaXXing";
}
