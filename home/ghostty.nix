# ghostty — replaces iTerm2, whose config was 100% manual (colour schemes were
# imported by hand through Preferences).
#
# NOTE: nixpkgs' ghostty is Linux-only; the macOS build needs Xcode and ships
# as a signed app. So on darwin the BINARY comes from a Homebrew cask (see
# the host config) while the CONFIG is still managed here — declarative either way.
{ pkgs, config, ... }:

let
  p = config.catalyst.palette;
in

{
  programs.ghostty = {
    enable = true;
    package = if pkgs.stdenv.hostPlatform.isDarwin then null else pkgs.ghostty;
    enableZshIntegration = true;

    settings = {
      # Base scheme, then explicit overrides below sync the terminal to the
      # IDE's "Retro Synth Cyan" theme (values lifted verbatim from the
      # extension's retro-synth-cyan.json terminal.ansi* block — including
      # its signature remaps: magenta→orange, cyan→purple). One look across
      # VS Code and ghostty.
      theme = "Synthwave Everything";
      font-family = "Hack Nerd Font";
      font-size = 13;

      background = "#000000"; # the IDE's editor black — not synthwave grey
      # livery primary as body text, muted: p.glow (#39ff14) blended ~30%
      # toward silver — full-sat neon glares as body copy; this keeps the
      # TEAK green identity at ~13:1 on the black ground. Pure glow stays
      # reserved for the cursor.
      foreground = "#62ec48";
      palette = [
        "0=#0d0221" # black cell darker than the theme's grey — keeps bg contrast
        "1=#f82a5d"
        "2=#00d836"
        "3=#e7dc60"
        "4=#5ccaef"
        "5=#f57f00" # theme remap: magenta slot is ORANGE
        "6=#a57fff" # theme remap: cyan slot is PURPLE
        "7=#f1f1f1"
        "8=#8f8f8f"
        "9=#f82a5d"
        "10=#00ff00"
        "11=#e7dc60"
        "12=#5ccaef"
        "13=#f57f00"
        "14=#a57fff"
        "15=#ffffff"
      ];

      window-padding-x = 8;
      window-padding-y = 8;
      window-save-state = "always";
      macos-option-as-alt = true;

      # ── cyber neon vibrancy ─────────────────────────────────────────────
      # 0.93 (was 0.82): the IDE-black background reads DARK — the old glass
      # let the desktop wash it toward grey. Still faintly acrylic.
      background-opacity = 0.93;
      background-blur-radius = 24; # frosted, not muddy
      window-colorspace = "display-p3"; # wider gamut = hotter neons
      bold-is-bright = true; # bold text jumps to bright palette
      minimum-contrast = 1.1; # keep glow readable on the glass

      cursor-style = "block";
      cursor-style-blink = true;
      cursor-color = p.glow; # the machine's neon (livery)
      cursor-text = p.deep;
      selection-background = "#7b2fbe"; # neon purple sweep
      selection-foreground = "#f8f8f2";
      unfocused-split-opacity = 0.65;

      # Split pane dividers. The option is `split-divider-color` — there is
      # no thickness knob; ghostty draws the divider one border-width wide
      # and scales it with the display.
      window-decoration = true;
      split-divider-color = p.glow; # neon divider to match cursor
      # The unfocused-split dim overlay is documented to default to the
      # background, but has been reported to pick up the divider colour once
      # that is set (a bright wash over unfocused panes). Pin it explicitly.
      unfocused-split-fill = "#000000";

      # Ghostty has no plugin system (by design) — custom GLSL shaders are
      # the extension point. This one is a restrained CRT pass; remove the
      # line to disable.
      custom-shader = "${./dotfiles/ghostty-crt.glsl}";

      shell-integration = "zsh";
      copy-on-select = true;
      confirm-close-surface = false;
    };
  };
}
