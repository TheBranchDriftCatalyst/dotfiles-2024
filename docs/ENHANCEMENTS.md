# Enhancements rundown (2026-09-10)

Everything added in the OP-ification pass: what it is, why it's here, how to
use it, and how to rip it out if it doesn't earn its keep. The anti-bloat
contract: **anything on this list you haven't touched in a couple months is a
deletion candidate — one module/line each, nothing is load-bearing.**

## The rice stack (`hosts/teakbookM5DJ/rice.nix`)

> New to tiling? **[RICE-GUIDE.md](RICE-GUIDE.md)** is the full tutorial:
> the mental model, every hotkey, customization recipes, bar anatomy.

| Thing            | What                                                                             | Daily driver moves                                                                                                                                                                                                                  |
| ---------------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **AeroSpace**    | i3-style tiling WM, no SIP hacks                                                 | `alt-hjkl` focus · `alt-shift-hjkl` move · `alt-1..9` workspace · `alt-shift-1..9` send · `alt-tab` last workspace · `alt-f` fullscreen · `alt-r` resize mode · `alt-slash` tiles / `alt-comma` accordion · `alt-shift-space` float |
| **JankyBorders** | glow border on the focused window                                                | passive — neon green = focused, dim green = not. It IS the livery                                                                                                                                                                   |
| **SketchyBar**   | replaces the Apple menu bar (SbarLua config in `hosts/teakbookM5DJ/sketchybar/`) | workspace pills show the **app icons** living in each workspace (sketchybar-app-font glyphs) — click to jump; front app with icon; clock/battery/CPU right side. Native bar is hidden (`_HIHideMenuBar`)                            |

Escape hatch: comment the `imports = [ ./rice.nix ];` line in
`hosts/teakbookM5DJ/default.nix`, switch, done — all three go away together.

## CLI pack (`home/cli.nix`)

- **atuin** — shell history in SQLite with a real search TUI. `ctrl-r` (or up-arrow)
  opens it; type to fuzzy-search, Enter runs, Tab edits. Sync is OFF —
  `atuin register` / self-host on the homelab when you want cross-machine
  history (it's E2E encrypted).
- **yazi** — TUI file manager, image previews work in Ghostty. Run `yy`
  (cd-follows-you wrapper) or `yazi`. `q` quits, `hjkl` moves, `Enter` opens.
- **lazygit** — `lazygit` in any repo. Borders/accents follow the palette.
  Learn ONE thing: `?` shows every keybind in context.
- **nix-index + comma** — a missing command tells you what package ships it,
  and `, <cmd>` runs any binary without installing: `, cowsay moo`.
  DB is prebuilt weekly (flake input), zero local indexing.
- **bat** — now themed `livery` (generated from the palette). `bat file.py`.
- **delta** — `git diff`/`log`/`show` are now side-by-side + syntax-highlighted,
  same livery theme. `n`/`N` jump between files in a long diff.

## Nix ergonomics

- **nh** — `just switch` now uses it: tree-style build output + a package diff
  on every activation, no more wall of derivation paths. `just switch-raw` is
  the bypass if nh ever misbehaves (known darwin edge: nh#233).
  Bonus: `nh clean all --keep 5` > `nix-collect-garbage`.
- **treefmt** — `just fmt` formats the whole repo (nix+sh+lua+md/json);
  `just fmt-check` verifies. NOTE: first run will reformat files nixfmt has
  opinions about — eyeball that diff before committing it.
- **mac-app-util** — invisible plumbing: nix-installed GUI apps now index in
  Spotlight/Launchpad via trampolines. Matters the day a cask moves to nixpkgs.

## Palette pipeline (the "one palette → everything" dream)

`catalyst.palette` (livery, per-host) now drives: **wallpaper** (already did),
**starship** prompt, **ghostty** cursor/selection, **tmux** status+borders,
**bat/delta** syntax theme, **lazygit** UI, **yazi** UI, **sketchybar** bar,
**jankyborders** glow. Change hexes in `hosts/teakbookM5DJ/palette.nix`,
switch, and the whole machine changes costume. The personal laptop gets its
own palette file and instantly looks different everywhere.

Not wired (deliberately): VS Code colors (settings.json is live+app-written —
nix writing it would fight the doctrine), vivid LS_COLORS (still stock
cyberdream; generating it from the palette is a parked followup).

## Ghostty extras

Ghostty has **no plugin system** (by design). Its extension point is custom
GLSL shaders: `home/dotfiles/ghostty-crt.glsl` is now wired — restrained
scanlines + vignette + a whisper of bloom over the acrylic. Too much? Delete
the `custom-shader` line in `home/ghostty.nix`. Want more? Shadertoy-style
shaders drop into the same file (search "ghostty shaders" — bloom, CRT curve,
cursor smear all exist).

## Colima (asked, mostly NOT added)

Current state (deliberate): `just vm` / `just vm k8s=true` / `just vm-stop`.
Considered and skipped for now:

- **launchd autostart** — costs battery on a laptop for a VM you don't always
  need; `just vm` is one command. Say the word and it's 5 lines in darwin.nix.
- **declarative colima.yaml** — colima rewrites its own config file (state,
  not config, by the symlink doctrine). The `just vm` flags ARE the config.
- k3s inside colima already covers the local-k8s story (`k8s=true`).

## Follow-ups this pass created

- atuin sync server decision (homelab candidate: it's one container).
- ~~SketchyBar plain-shell → SbarLua glow-up~~ DONE same day: Lua config with
  app-icon workspace pills. Next rung if wanted: battery/volume popups,
  media item, wifi.
- First `just fmt` run = big one-time diff; do it as its own commit.
- vivid-from-palette still parked.
