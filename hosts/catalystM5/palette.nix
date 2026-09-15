# catalystM5 livery — full Catalyst brand.
#
# A PLAIN attrset (no module machinery) so both layers can import it: home.nix
# feeds catalyst.palette (HM), rice.nix colors the darwin-level bar/borders.
# One source of truth for the machine's neon.
#
# Values are the canonical Catalyst brand, not an approximation — see
# catalyst-devspace/workspace/dungeon-library/.claude/catalyst-brand.md
# ("Cyberpunk / Synthwave — neon-infused, dark backgrounds, glowing accents").
# Where the brand names a token, it is used verbatim:
#
#   Neon Cyan   #00fcd6  primary accent, success, headings  -> glow, grid
#   Neon Pink   #ff6ec7  secondary accent, highlights       -> accent, sunTop
#   Neon Purple #c026d3  tertiary, tags, categories         -> sunBot
#   Background  #0a0a0f  deep black                         -> deep
#   Card        #16161d  surface                            -> mid
#
# The cyan grid + pink-to-purple sun is the brand's own synthwave reading:
# primary carries the glow, the secondary/tertiary pair carries the sun.
{
  deep = "#0a0a0f"; # brand Background — one ground across bar/wallpaper/terminal
  mid = "#16161d"; # brand Card (surface) — depth layer above the ground
  glow = "#00fcd6"; # brand Neon Cyan — THE Catalyst primary; the machine's identity
  sunTop = "#ff6ec7"; # brand Neon Pink — sun gradient, upper
  sunBot = "#c026d3"; # brand Neon Purple — sun gradient, lower
  grid = "#00fcd6"; # cyan grid, matching the brand's grid token rgba(0,252,214,.04)
  accent = "#ff6ec7"; # brand Neon Pink — counterpoint to the cyan primary
  text = "CATALYST"; # livery title on the wallpaper (rendered caps, chrome+glow)
}
