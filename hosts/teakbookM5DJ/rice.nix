# The rice stack — AeroSpace (tiling) + JankyBorders (focus glow) +
# SketchyBar (menu-bar replacement), all colored from palette.nix.
#
# This is the layer every hot nix-darwin config has and we didn't (2026-09).
# All three are darwin services; the trio is version-interdependent, so they
# live together in this one file (pattern: zmre/aerospace-sketchybar-nix).
#
# Muscle-memory card:
#   alt-h/j/k/l        focus window        alt-1..9   go to workspace
#   alt-shift-h/j/k/l  move window         alt-shift-1..9  send to workspace
#   alt-slash          tiles h/v toggle    alt-comma  accordion
#   alt-f              fullscreen          alt-shift-space  float toggle
#   alt-r              resize mode (hjkl then esc)
{ pkgs, ... }:

let
  p = import ./palette.nix;
  # sketchybar/borders want 0xAARRGGBB; palette carries #RRGGBB
  c = alpha: hex: "0x${alpha}${builtins.substring 1 6 hex}";
in
{
  # ── AeroSpace: i3-like tiling, no SIP shenanigans (unlike yabai) ─────────
  services.aerospace = {
    enable = true;
    settings = {
      after-startup-command = [ ];
      # tell sketchybar when the workspace changes (its item subscribes)
      exec-on-workspace-change = [
        "/bin/bash" "-c"
        "sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
      ];
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";
      gaps = {
        inner.horizontal = 8;
        inner.vertical = 8;
        outer.left = 8;
        outer.bottom = 8;
        outer.top = 8;
        outer.right = 8;
      };
      mode.main.binding = {
        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";
        alt-shift-h = "move left";
        alt-shift-j = "move down";
        alt-shift-k = "move up";
        alt-shift-l = "move right";
        alt-1 = "workspace 1";
        alt-2 = "workspace 2";
        alt-3 = "workspace 3";
        alt-4 = "workspace 4";
        alt-5 = "workspace 5";
        alt-6 = "workspace 6";
        alt-7 = "workspace 7";
        alt-8 = "workspace 8";
        alt-9 = "workspace 9";
        alt-shift-1 = "move-node-to-workspace 1";
        alt-shift-2 = "move-node-to-workspace 2";
        alt-shift-3 = "move-node-to-workspace 3";
        alt-shift-4 = "move-node-to-workspace 4";
        alt-shift-5 = "move-node-to-workspace 5";
        alt-shift-6 = "move-node-to-workspace 6";
        alt-shift-7 = "move-node-to-workspace 7";
        alt-shift-8 = "move-node-to-workspace 8";
        alt-shift-9 = "move-node-to-workspace 9";
        alt-slash = "layout tiles horizontal vertical";
        alt-comma = "layout accordion horizontal vertical";
        alt-f = "fullscreen";
        alt-shift-space = "layout floating tiling";
        alt-tab = "workspace-back-and-forth";
        alt-r = "mode resize";
      };
      mode.resize.binding = {
        h = "resize width -50";
        j = "resize height +50";
        k = "resize height -50";
        l = "resize width +50";
        esc = "mode main";
        enter = "mode main";
      };
    };
  };

  # ── JankyBorders: the livery made physical ───────────────────────────────
  services.jankyborders = {
    enable = true;
    active_color = c "ff" p.glow;
    inactive_color = c "66" p.mid;
    width = 6.0;
  };

  # ── SketchyBar: minimal first cut, palette-driven ────────────────────────
  # Plain-shell config (SbarLua is the fancy path — upgrade later if wanted).
  services.sketchybar = {
    enable = true;
    config = ''
      #!/bin/bash
      sketchybar --bar height=32 position=top sticky=on \
                 color=${c "e0" p.deep} corner_radius=0 \
                 padding_left=8 padding_right=8

      sketchybar --default icon.font="Hack Nerd Font:Bold:14.0" \
                 label.font="Hack Nerd Font:Semibold:13.0" \
                 icon.color=${c "ff" p.glow} label.color=${c "ff" p.accent} \
                 padding_left=6 padding_right=6 \
                 icon.padding_right=4

      # workspace pills, driven by the aerospace trigger
      sketchybar --add event aerospace_workspace_change
      for sid in 1 2 3 4 5 6 7 8 9; do
        sketchybar --add item space.$sid left \
          --subscribe space.$sid aerospace_workspace_change \
          --set space.$sid label="$sid" icon.drawing=off \
                label.color=${c "80" p.accent} \
                background.corner_radius=6 background.height=22 \
                background.drawing=on background.color=${c "00" p.deep} \
                click_script="aerospace workspace $sid" \
                script='if [ "$sid" = "$FOCUSED_WORKSPACE" ]; then
                          sketchybar --set $NAME label.color=${c "ff" p.deep} background.color=${c "ff" p.glow}
                        else
                          sketchybar --set $NAME label.color=${c "80" p.accent} background.color=${c "00" p.deep}
                        fi' sid="$sid"
      done

      sketchybar --add item front_app left \
        --set front_app icon.drawing=off label.color=${c "ff" p.glow} \
              script='sketchybar --set $NAME label="$INFO"' \
        --subscribe front_app front_app_switched

      sketchybar --add item clock right \
        --set clock update_freq=10 \
              script='sketchybar --set $NAME label="$(date "+%H:%M")"'

      sketchybar --add item battery right \
        --set battery update_freq=120 \
              script='PCT=$(pmset -g batt | grep -Eo "[0-9]+%" | head -1)
                      sketchybar --set $NAME label="$PCT" icon="⚡"' \
        --subscribe battery system_woke power_source_change

      sketchybar --add item cpu right \
        --set cpu update_freq=5 \
              script='LOAD=$(ps -A -o %cpu | awk "{s+=\$1} END {printf \"%.0f%%\", s/$(sysctl -n hw.ncpu)}")
                      sketchybar --set $NAME label="$LOAD" icon="▮"'

      sketchybar --update
    '';
  };

  # the bar replaces the native menu bar
  system.defaults.NSGlobalDomain._HIHideMenuBar = true;

  # aerospace CLI + sketchybar on PATH for click_scripts and debugging
  environment.systemPackages = [ pkgs.aerospace pkgs.sketchybar ];
}
