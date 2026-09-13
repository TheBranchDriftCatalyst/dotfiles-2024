# claude — Claude Code's user config, split by the symlink doctrine.
#
# ~/.claude is mostly runtime state (projects/, plugins/, sessions, caches) —
# nix never touches the directory itself, only plants links inside it:
#
#   LIVE (dotfiles/claude/, everything — app writes through the links):
#     settings.json — /config, permission approvals, plugin enables land here
#     CLAUDE.md     — global prompt; /memory and `#` write it
#     agents/, commands/ — /agents creates files in them
#     hooks/ — deliberate doctrine EXCEPTION: the app never writes these, but
#              hook scripts are iterated like the prompt, not like nix config,
#              so they ride the live link (DJ's call, 2026-09-10). git-guard.sh
#              is wired in settings.json; the other three are PARKED (need the
#              beads/memory-service MCPs — operator notes in each script).
#
# Plugin identity is declarative: settings.json carries
# extraKnownMarketplaces + enabledPlugins, so a fresh machine re-registers
# the catalyst + beads marketplaces on first launch (plugin *content* still
# installs per-machine on first use).
#
# Known caveat: cloud/Cowork sessions skip a symlinked ~/.claude/CLAUDE.md.
# Local sessions — the ones that matter here — follow it fine.
{ config, dotfilesRepo, ... }:

let
  repo = "${config.home.homeDirectory}/${dotfilesRepo}";
  live = name: config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/claude/${name}";
in
{
  home.file = {
    ".claude/settings.json".source = live "settings.json";
    ".claude/CLAUDE.md".source = live "CLAUDE.md";
    ".claude/agents".source = live "agents";
    ".claude/commands".source = live "commands";
    ".claude/hooks".source = live "hooks";
  };
}
