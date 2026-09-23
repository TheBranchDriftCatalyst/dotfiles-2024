#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# test/sketchybar/run.sh — the popup/deadlock suite for darwin/sketchybar.
#
# Loads the REAL items/widgets.lua with `sbar` stubbed, so no sketchybar
# process, no mach ports and no macOS are involved: it runs anywhere a Lua 5.5
# lives, in well under a second. Seconds, not containers — this is the gate for
# anything under darwin/sketchybar/.
#
#   ./test/sketchybar/run.sh [path/to/widgets.lua]
#
# Defaults to the in-repo copy; pass a /nix/store/*-sketchybar-lua-config path
# to test what was actually built.
#
# What it guards is written up at the top of harness.lua: the bar used to
# DEADLOCK against its own helper because the mouse.exited.global handler
# called back into sketchybar synchronously. Do not "simplify" the sbar.delay
# in widgets.lua away — that is the fix, and case 2 here fails without it.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WIDGETS="${1:-$REPO_ROOT/darwin/sketchybar/items/widgets.lua}"
HERE="$REPO_ROOT/test/sketchybar"

[[ -f $WIDGETS ]] || {
  echo "no such widgets.lua: $WIDGETS" >&2
  exit 1
}

# widgets.lua needs 5.2+ for table.unpack; every candidate below satisfies that.
LUA=""
for c in lua5.5 lua5.4 lua; do
  command -v "$c" >/dev/null && {
    LUA="$c"
    break
  }
done
[[ -n $LUA ]] || {
  echo "no lua interpreter on PATH (tried lua5.5, lua5.4, lua)" >&2
  echo "  nix shell nixpkgs#lua5_5 -c ./test/sketchybar/run.sh" >&2
  exit 1
}

echo "══ target: $WIDGETS ($($LUA -v 2>&1 | head -1)) ══"

# stubs first so they win over anything real sitting beside widgets.lua
LUA_PATH="$HERE/stub/?.lua;$(dirname "$WIDGETS")/?.lua;;" exec "$LUA" "$HERE/harness.lua"
