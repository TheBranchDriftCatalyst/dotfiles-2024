# Rice guide: AeroSpace + SketchyBar

The "window shit is weird as fuck" doc. Everything here matches OUR config
(`hosts/teakbookM5DJ/rice.nix`) — not upstream defaults.

## The mental model (why windows jump around)

AeroSpace is a **tiling** window manager, i3-style. The rules:

1. **You don't place windows — the layout does.** Every new window gets
   inserted into the current workspace's *tree* and the tree divides the
   screen. Two windows = half/half. Three = the space splits again. You never
   drag to arrange; you move windows *within the tree* with the keyboard.
2. **Workspaces (1-9) replace macOS Spaces.** They're instant (no swoosh
   animation) because AeroSpace fakes them by hiding windows, not by using
   macOS Spaces. A window lives in exactly one workspace. The bar's pills
   show what's where.
3. **Two layouts per tree node:**
   - **tiles** (default): windows side-by-side / stacked, all visible.
   - **accordion**: windows overlap like a deck; the focused one is full-size
     with a sliver of the others peeking. Great for 4+ terminals.
4. **Floating is the escape hatch.** A floated window ignores the tree
   (System Settings, popups, that one dialog that tiles like garbage).
5. **Focus follows the keyboard.** `alt-hjkl` moves your focus around the
   tree geometrically (left/down/up/right). The neon border = focused.

Day-one workflow that makes it click: `alt-1` terminal workspace, `alt-2`
editor, `alt-3` browser. `alt-shift-2` throws the current window to
workspace 2. `alt-tab` bounces between your two most-used workspaces.

## Hotkey cheat sheet (our bindings)

> **`alt` = the Option key (⌥)** — between Control and Command.
>
> Option is double-booked on this machine, deliberately: Ghostty sets
> `macos-option-as-alt = true`, making ⌥ the **Meta** key for shell binds
> inside the terminal. AeroSpace grabs its own combos at the system level
> *first*, so ⌥+hjkl / ⌥+1..9 / etc. never reach the shell — every ⌥ combo
> AeroSpace does NOT bind still works as Meta in the terminal. If a shell
> keybind you care about ever "stops working", it's an AeroSpace binding
> shadowing it: rebind one side (aerospace: `rice.nix`; shell:
> `home/zsh/*.zsh` / `home/dotfiles/tmux.conf`).

### Focus & movement
| Keys | Does |
|---|---|
| `alt-h/j/k/l` | focus window left/down/up/right |
| `alt-shift-h/j/k/l` | **move** the focused window within the tree |
| `alt-tab` | previous workspace (back-and-forth) |

### Workspaces
| Keys | Does |
|---|---|
| `alt-1` … `alt-9` | go to workspace N |
| `alt-shift-1` … `alt-shift-9` | send focused window to workspace N (you don't follow) |
| bar pill click | go to that workspace |

### Layout
| Keys | Does |
|---|---|
| `alt-slash` | tiles layout; press again to flip horizontal/vertical split |
| `alt-comma` | accordion layout; press again to flip its axis |
| `alt-f` | fullscreen the focused window (within the workspace) |
| `alt-shift-space` | float ↔ tile the focused window |

### Resize mode
`alt-r` enters **resize mode** — then plain `h/l` = narrower/wider,
`j/k` = taller/shorter (50px steps), `esc` or `enter` to leave. Modes are
i3's trick for not burning a zillion chords.

### Not bound (on purpose, add when needed)
Multi-monitor moves (`move-node-to-monitor`), service mode (reload/flatten),
join-with (merging windows into one split). See "Customizing" below.

## Customizing AeroSpace

Everything lives in `services.aerospace.settings` in
`hosts/teakbookM5DJ/rice.nix` — it's the TOML config as a nix attrset.
Change → `just switch` → aerospace reloads.

Common tweaks, copy-paste ready:

```nix
# gaps (currently 8 everywhere)
gaps.inner.horizontal = 12;

# app always floats (find the app-id: aerospace list-apps)
on-window-detected = [{
  "if".app-id = "com.apple.systempreferences";
  run = "layout floating";
}];

# app always opens in a workspace
on-window-detected = [{
  "if".app-id = "com.google.Chrome";
  run = "move-node-to-workspace 3";
}];

# a service mode for rare ops (i3 convention: alt-shift-semicolon)
mode.main.binding.alt-shift-semicolon = "mode service";
mode.service.binding = {
  r = [ "reload-config" "mode main" ];
  f = [ "flatten-workspace-tree" "mode main" ];  # un-fuck a weird tree
  esc = "mode main";
};
```

Debugging: `aerospace list-windows --all`, `aerospace list-apps`,
`aerospace debug-windows` (tells you why a window behaves oddly).
Full command list: `aerospace --help`, docs at
https://nikitabobko.github.io/AeroSpace/commands

## SketchyBar: how ours is put together

The bar is a launchd service running a **Lua program**
(`hosts/teakbookM5DJ/sketchybar/`) via SbarLua. Anatomy:

```
rice.nix                 generates colors.lua (from palette.nix) + settings.lua
sketchybar/init.lua      entrypoint: begin_config → modules → event_loop
sketchybar/bar.lua       the bar itself (height, position, translucent deep bg)
sketchybar/default.lua   inherited item defaults (fonts, colors, padding)
sketchybar/items/
  workspaces.lua         pills 1-9: number + app glyphs per workspace
  front_app.lua          focused app icon + name
  widgets.lua            clock · battery · cpu (right side)
```

Core concepts:
- An **item** = icon + label + background, positioned left/center/right.
- Items **subscribe to events** (`front_app_switched`, `routine` — fired
  every `update_freq` seconds, `power_source_change`, custom ones).
- AeroSpace pushes a **custom event** (`aerospace_workspace_change`) on every
  workspace switch — wired in rice.nix `exec-on-workspace-change`. That's
  how pills repaint instantly.
- App icons are **font glyphs**: `icon_map.lua` (from sketchybar-app-font)
  maps "App Name" → ":glyph:"; unknown apps get `:default:`.

### Adding a widget (the pattern)

Drop this in `items/widgets.lua`, `just switch`:

```lua
local wifi = sbar.add("item", "wifi", {
  position = "right",
  update_freq = 30,
  icon = { string = "󰖩" },
})
wifi:subscribe({ "routine", "system_woke" }, function()
  sbar.exec("ipconfig getsummary en0 | awk -F' SSID : ' '/ SSID/ {print $2}'", function(out)
    wifi:set({ label = { string = (out or ""):gsub("%s+$", "") } })
  end)
end)
```

Then `require` it if you made a new file (items/init.lua lists modules).

### Debugging the bar
- `sketchybar --reload` — restart the config without a switch (config is a
  store path, so a *code* change still needs `just switch`).
- `sketchybar --query bar` / `--query space.1` — dump an item's state as JSON.
- Logs: `log show --last 5m --predicate 'process == "sketchybar"'` or check
  `/tmp/sketchybar_dj.err` style launchd logs via
  `launchctl print gui/$UID/org.nixos.sketchybar`.
- Bar gone entirely? `launchctl kickstart -k gui/$UID/org.nixos.sketchybar`.

### Theming
You don't theme the bar — you theme the **palette**
(`hosts/teakbookM5DJ/palette.nix`) and the bar follows, same as the prompt,
tmux, and the borders. Bar-specific knobs (heights, paddings, fonts) live in
`bar.lua` / `default.lua`.

## Kill switches

- Whole rice stack: comment `imports = [ ./rice.nix ];` in
  `hosts/teakbookM5DJ/default.nix`, `just switch`. Menu bar comes back
  (`_HIHideMenuBar` lives in rice.nix too).
- Just tiling: `alt-shift-space` floats the current window; for everything,
  `aerospace enable off` (until next login) — windows stay where they are.
