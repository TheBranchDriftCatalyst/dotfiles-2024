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

  # ── SbarLua config assembly ──────────────────────────────────────────────
  # Static Lua lives in ./sketchybar; colors.lua + settings.lua are generated
  # here so the bar follows palette.nix and store paths stay exact.
  colorsLua = pkgs.writeText "colors.lua" ''
    return {
      glow = ${c "ff" p.glow},
      accent = ${c "ff" p.accent},
      deep = ${c "ff" p.deep},
      mid = ${c "ff" p.mid},
      sunTop = ${c "ff" p.sunTop},
      sunBot = ${c "ff" p.sunBot},
      dim = ${c "80" p.accent},
      red = 0xffff5555,
      bar_bg = ${c "e0" p.deep},
      transparent = 0x00000000,
    }
  '';
  settingsLua = pkgs.writeText "settings.lua" ''
    return {
      font = "Hack Nerd Font",
      aerospace = "${pkgs.aerospace}/bin/aerospace",
    }
  '';
  sketchybarConfig = pkgs.runCommand "sketchybar-lua-config" { } ''
    mkdir -p $out
    cp -r ${./sketchybar}/. $out/
    cp ${colorsLua} $out/colors.lua
    cp ${settingsLua} $out/settings.lua
  '';
in
{
  # ── AeroSpace: i3-like tiling, no SIP shenanigans (unlike yabai) ─────────
  services.aerospace = {
    enable = true;
    settings = {
      # v2: persistent-workspaces must be declared instead of being inferred
      # from the keybindings (v1 behavior, warned as outdated on every parse)
      config-version = 2;
      persistent-workspaces = [ "1" "2" "3" "4" "5" "6" "7" "8" "9" ];

      after-startup-command = [ ];
      # tell sketchybar when the workspace changes (its items subscribe)
      exec-on-workspace-change = [
        "/bin/bash" "-c"
        "${pkgs.sketchybar}/bin/sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
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

  # ── SketchyBar: SbarLua, palette-driven, aerospace-aware ─────────────────
  # Lua config in ./sketchybar (workspace pills with app-font glyphs, front
  # app, clock/battery/cpu). The rc bootstraps the Lua 5.5 interpreter with
  # the sbarLua C module and the app-font icon map on LUA_PATH.
  services.sketchybar = {
    enable = true;
    config = ''
      #!/bin/bash
      export LUA_CPATH="${pkgs.sbarlua}/lib/lua/5.5/?.so"
      export LUA_PATH="${sketchybarConfig}/?.lua;${sketchybarConfig}/?/init.lua;${pkgs.sketchybar-app-font}/lib/sketchybar-app-font/?.lua"
      exec ${pkgs.lua5_5}/bin/lua ${sketchybarConfig}/init.lua
    '';
  };

  # app glyphs for the workspace pills
  fonts.packages = [ pkgs.sketchybar-app-font ];

  # the bar replaces the native menu bar
  system.defaults.NSGlobalDomain._HIHideMenuBar = true;

  # aerospace CLI + sketchybar on PATH for click_scripts and debugging
  environment.systemPackages = [ pkgs.aerospace pkgs.sketchybar ];
}
