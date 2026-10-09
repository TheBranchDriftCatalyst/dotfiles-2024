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
{
  config,
  lib,
  pkgs,
  dotfilesRepo,
  ...
}:

let
  repo = "${config.home.homeDirectory}/${dotfilesRepo}";
  live = name: config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/claude/${name}";

  # ── ECC (github.com/affaan-m/ECC) ────────────────────────────────────────
  # Knobs deliberately sit here, not buried in the script: flipping `enable`
  # off or bumping `version` is a one-line declarative edit + switch, which is
  # the only "nix deploys ECC" property actually worth having. The plugin's
  # CONTENT still installs per-machine on first use — same trade the catalyst
  # and beads marketplaces already make (see the header note above).
  ecc = {
    # DISARMED (DJ's call, 2026-10-09): hermes gets stood up and proven on its
    # own first, and hermes is meant to use ECC eventually — so arming both in
    # the same switch would mean debugging two new layers at once. Flip to true
    # when hermes is working and the ECC layer is wanted; the next `just switch`
    # then runs the official installer.
    #
    # false does NOT uninstall, and ECC is ALREADY installed on this machine by
    # hand (settings.json enables ecc@ecc and the 2.2.3 plugin cache is on
    # disk). This flag only governs whether activation reinstalls/updates it.
    # To genuinely remove it: `/plugin uninstall ecc@ecc` plus reverting the
    # settings.json diff.
    enable = false;
    version = "2.2.3";
    scope = "user"; # user | project | local
    hooks = "minimal"; # off | minimal | standard | strict
    pluginId = "ecc@ecc";
  };

  # Written by the activation script, read by its own guard. Mirrors how
  # catalyst.nix owns ~/.catalyst/secrets.env.
  eccStamp = "${config.home.homeDirectory}/.claude/.ecc-version";
  eccSettings = "${repo}/dotfiles/claude/settings.json";
in
{
  home.file = {
    ".claude/settings.json".source = live "settings.json";
    ".claude/CLAUDE.md".source = live "CLAUDE.md";
    ".claude/agents".source = live "agents";
    ".claude/commands".source = live "commands";
    ".claude/hooks".source = live "hooks";
  };

  # ECC plugin, installed through its OWN official installer rather than by
  # planting files. `npx ecc-universal setup` drives the real
  # `claude plugin marketplace add` / `plugin install`, and is also the
  # documented update and scope-change path — reimplementing that in nix would
  # mean forfeiting `ecc doctor` / `ecc repair` and the hook-profile mechanism.
  # So nix owns WHEN and WITH WHAT ARGUMENTS, the installer owns HOW.
  #
  # The installer writes into ~/.claude/settings.json, which is a live
  # out-of-store symlink into dotfiles/ — so its marketplace + enablement lines
  # land in the repo as a reviewable diff, and that commit is what makes a
  # fresh machine reproduce this.
  home.activation.eccPlugin = lib.mkIf ecc.enable (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      _want=${lib.escapeShellArg ecc.version}
      _stamp=${lib.escapeShellArg eccStamp}
      _settings=${lib.escapeShellArg eccSettings}
      _npx="${pkgs.nodejs}/bin/npx"
      _jq="${pkgs.jq}/bin/jq"

      # Claude Code is a Homebrew cask here, NOT a nix package, so there is no
      # store path to interpolate — it has to be found on PATH. Activation runs
      # with a minimal PATH, hence the explicit prepend.
      export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

      if ! command -v claude >/dev/null 2>&1; then
        echo "ecc: ✖ claude not on PATH — skipping (install Claude Code, then re-switch)"
      else
        _have=""
        [ -r "$_stamp" ] && _have=$(cat "$_stamp" 2>/dev/null || true)
        _enabled=false
        if [ -r "$_settings" ]; then
          "$_jq" -e --arg id ${lib.escapeShellArg ecc.pluginId} \
            '(.enabledPlugins // {}) | has($id)' "$_settings" >/dev/null 2>&1 \
            && _enabled=true
        fi

        # Steady state is the common case: already enabled AND stamped at the
        # pinned version means no npx, no network, no slow switch.
        if [ "$_enabled" = true ] && [ "$_have" = "$_want" ]; then
          echo "ecc: $_want already installed — nothing to do"
        else
          if [ "$_enabled" = true ] && [ -n "$_have" ]; then
            echo "ecc: $_have -> $_want, updating"
          else
            echo "ecc: installing $_want (scope=${ecc.scope} hooks=${ecc.hooks})"
          fi
          # --mode claude-plugin is MANDATORY here, not optional: without it the
          # installer refuses outright in a non-TTY with
          #   SETUP_FAILED "Interactive setup requires a terminal.
          #                 Pass --mode claude-plugin and the required flags."
          # Verified by dry-run on 2026-10-08 — an earlier version of this
          # script omitted it and would have failed every switch. --yes skips
          # the confirmation; --scope/--hooks supply what the wizard would
          # otherwise prompt for.
          # A DURABLE log, not a mktemp: nh swallows activation stdout on
          # darwin (nh#233), so a failure printed to the console can vanish
          # entirely. `just switch` and `just ecc-status` both read this file,
          # which is the only copy that survives. Truncated per attempt so a
          # stale failure cannot raise a false alarm on a later switch.
          _log="$HOME/.claude/.ecc-install.log"
          $DRY_RUN_CMD mkdir -p "$(dirname "$_log")"
          : > "$_log" 2>/dev/null || true
          if $DRY_RUN_CMD "$_npx" --yes "ecc-universal@$_want" setup \
               --mode claude-plugin \
               --scope ${lib.escapeShellArg ecc.scope} \
               --hooks ${lib.escapeShellArg ecc.hooks} \
               --yes --json >"$_log" 2>&1; then
            $DRY_RUN_CMD mkdir -p "$(dirname "$_stamp")"
            $DRY_RUN_CMD sh -c "printf '%s' \"$_want\" > \"$_stamp\""
            echo "ecc: $_want installed — review and commit the settings.json diff"
            $DRY_RUN_CMD sh -c "printf 'ok: installed %s\n' \"$_want\" > \"$_log\"" || true
          else
            # Never fail the switch for this. Offline, npm down, or a bad pin
            # all degrade to a warning, exactly as catalyst.nix does when op is
            # locked.
            echo "ecc: ✖ \`npx ecc-universal@$_want setup\` failed (offline? bad version?) — leaving the current install alone"
            echo "ecc:   installer said:"
            sed 's/^/ecc:     /' "$_log" 2>/dev/null || true
            echo "ecc:   re-run by hand for the full output:"
            echo "ecc:     npx ecc-universal@$_want setup --mode claude-plugin --scope ${ecc.scope} --hooks ${ecc.hooks} --yes --dry-run --json"
          fi
          # deliberately NOT removed — see the durable-log note above
        fi
      fi
    ''
  );
}
