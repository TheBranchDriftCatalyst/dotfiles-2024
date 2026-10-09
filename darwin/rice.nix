# The rice stack — AeroSpace (tiling) + JankyBorders (focus glow) +
# SketchyBar (menu-bar replacement), all colored from the host's palette.
#
# This is the layer every hot nix-darwin config has and we didn't (2026-09).
# All three are darwin services; the trio is version-interdependent, so they
# live together in this one file (pattern: zmre/aerospace-sketchybar-nix).
#
# SHARED across every darwin host — the only per-host inputs are the palette
# (catalyst.palette, fed from hosts/<name>/palette.nix) and the tiling toggle
# below. Both hosts ran byte-identical copies of this file before it moved.
#
# Muscle-memory card:
#   alt-h/j/k/l        focus window        alt-1..9   go to workspace
#   alt-shift-h/j/k/l  move window         alt-shift-1..9  send to workspace
#   alt-slash          tiles h/v toggle    alt-comma  accordion
#   alt-f              fullscreen          alt-shift-space  float toggle
#   alt-r              resize mode (hjkl then esc)
{
  pkgs,
  lib,
  config,
  ...
}:

let
  tiling = config.catalyst.rice.tiling;

  p = config.catalyst.palette;
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
      -- deck (interactive popup) tokens. `hot` is the livery's hot pink,
      -- reserved exclusively for the armed-to-kill row state — nothing else
      -- on the bar may use it, that's what makes it read as danger.
      hot = 0xffff2e97,
      hover = ${c "26" p.glow},
      -- opaque for the same reason as bar_bg: without real blur, whatever
      -- window sits behind the popup bleeds through translucency as mush
      popup_bg = ${c "ff" p.deep},
      edge = ${c "59" p.glow},
      -- fully opaque: the auto-hidden native menu bar blurs whatever sits
      -- behind it when it slides down — over translucent neon it was
      -- unreadable mush; over solid deep-green both bars stay legible
      bar_bg = ${c "ff" p.deep},
      transparent = 0x00000000,
    }
  '';
  settingsLua = pkgs.writeText "settings.lua" ''
    return {
      font = "Hack Nerd Font",
      aerospace = "${pkgs.aerospace}/bin/aerospace",
      tiling = ${if tiling then "true" else "false"},
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
  # ONE-FLIP TOGGLE, per host: false = Rectangle Pro era (cask, darwin/brew) —
  # aerospace service off, workspace pills off. Flip to true to return to
  # tiling; everything below is kept intact for that day.
  options.catalyst.rice.tiling = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Run AeroSpace as the window manager instead of Rectangle Pro.";
  };

  config = {
    # Passwordless root for exactly two binaries — nothing broader. The user is
    # derived, not hardcoded: this file is shared and the old copies both said
    # `dj`, which silently did nothing on the host whose user is `panda`.
    #
    #   purge(8)        the mem deck's "purge now" button; root-only.
    #   powermetrics(1) CPU/GPU/power sampling; root-only. Adopted 2026-09-22
    #                   from an undeclared /etc/sudoers.d/powermetrics written
    #                   2026-05-30, i.e. machine-local drift that predated this
    #                   config and existed on one host only.
    #
    # CAVEAT, deliberately accepted: powermetrics takes `-o <file>` and runs as
    # root, so this grant is a root-owned-file-write primitive, not merely a
    # read. sudoers cannot constrain arguments safely (they are trivially
    # bypassed), so the choice is all-or-nothing. Kept because the machine is a
    # single-user laptop where the owner can already sudo interactively; drop
    # the line if that ever stops being true.
    #
    # After switching, delete the now-redundant standalone rule:
    #   sudo rm /etc/sudoers.d/powermetrics
    security.sudo.extraConfig = ''
      ${config.system.primaryUser} ALL=(root) NOPASSWD: /usr/sbin/purge
      ${config.system.primaryUser} ALL=(root) NOPASSWD: /usr/bin/powermetrics
    '';

    # ── AeroSpace: i3-like tiling, no SIP shenanigans (unlike yabai) ─────────
    services.aerospace = {
      enable = tiling;
      settings = {
        # v2: persistent-workspaces must be declared instead of being inferred
        # from the keybindings (v1 behavior, warned as outdated on every parse)
        config-version = 2;
        persistent-workspaces = [
          "1"
          "2"
          "3"
          "4"
          "5"
          "6"
          "7"
          "8"
          "9"
        ];

        after-startup-command = [ ];
        # tell sketchybar when the workspace changes (its items subscribe)
        exec-on-workspace-change = [
          "/bin/bash"
          "-c"
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

    # ── The freeze fix: the bar must never block on its client ───────────────
    # sketchybar and its Lua client talk over mach ports, and neither drains its
    # own port while blocked in a send. So the two could end up sending to each
    # other with nobody receiving, both parked in mach_msg2_trap at 0% CPU
    # forever — a "frozen bar". Stacks sampled in the wild 2026-09-22 and
    # 2026-09-24; in every sample the bar was stuck in the SAME send,
    # bar_item.c:169 handing an event to the client.
    #
    # The fix that matters is that send: it now gets a zero budget — one attempt,
    # then drop. A client too backed up to accept a message (its queue is
    # MACH_PORT_QLIMIT_LARGE, 1024 deep) is already beyond saving, and a dropped
    # mouse event is cosmetic. Because the bar can no longer be stopped by a slow
    # client, it always returns to its runloop, always drains commands, and
    # always replies — so the client's waits always resolve. That is what makes
    # the deadlock structurally impossible rather than merely rare.
    #
    # Reply-expecting sends (the `sketchybar` CLI, client commands) keep a
    # bounded 100ms deadline as a backstop that should now never be reached.
    #
    # CAREFUL: MACH_SEND_TIMEOUT alone does NOT bound a send. The library
    # silently retries an interrupted send and REUSES the original timeout, so
    # signals restart the clock forever — documented in the Mach Reference
    # Manual (Message Send) and mis-shipped here once already, which cost a day.
    # MACH_SEND_INTERRUPT plus our own deadline loop is the correct API use.
    # `just test-mach` fails if that flag is ever dropped again.
    #
    # The SbarLua patch also releases two Lua registry refs it never released —
    # every sbar.exec and sbar.delay callback was pinned forever (cpu alone execs
    # every 5s). Unrelated to the freeze, but a real leak found alongside it.
    #
    # Patches are cut against the exact revisions nixpkgs pins — sketchybar
    # v2.24.0 and SbarLua dba9cc42, both upstream HEAD as of 2026-09-24, so there
    # is no newer release to move to. Drop these if upstream fixes its own sends.
    nixpkgs.overlays = [
      (_final: prev: {
        sketchybar = prev.sketchybar.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./patches/sketchybar-timed-mach-send.patch ];
        });
        sbarlua = prev.sbarlua.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./patches/sbarlua-timed-mach-send.patch ];
        });
      })
    ];

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
    environment.systemPackages = [
      pkgs.aerospace
      pkgs.sketchybar
    ];
  };
}
