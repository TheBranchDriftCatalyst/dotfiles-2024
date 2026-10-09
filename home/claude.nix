# claude — Claude Code's user config, split by the symlink doctrine.
#
# ~/.claude is mostly runtime state (projects/, plugins/, sessions, caches) —
# nix never touches the directory itself, only plants links inside it:
#
#   LIVE (dotfiles/claude/, everything — app writes through the links):
#     CLAUDE.md     — global prompt; /memory and `#` write it
#     settings.json — /config, permission approvals, plugin enables land here.
#                     DOES NOT write through the link, and cannot: Claude Code
#                     rewrites it atomically (temp file + rename), and rename
#                     REPLACES a symlink with a regular file. It therefore
#                     carries force = true plus a reconcile step — see the
#                     note on the option below.
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
    # ARMED (DJ's call, 2026-10-09). ECC is the layer being worked on; hermes
    # gets layered onto it afterwards.
    #
    # Note what this flag does and does not do. ECC 2.2.3 is ALREADY installed
    # and running on this machine from a manual install — settings.json enables
    # ecc@ecc, the plugin is at plugins/cache/ecc/ecc/2.2.3, and all 24 of its
    # hooks across 7 events are live (verified 2026-10-09 by driving each one
    # through its own bootstrap). What is missing is only the declarative half:
    # ~/.claude/.ecc-version is absent, so nix has never been the thing that
    # installed it, and a fresh machine would not reproduce it.
    #
    # So the next activation reconciles rather than installs from nothing. The
    # exact command it runs was dry-run first and reports "would-update":
    #   npx ecc-universal@2.2.3 setup --mode claude-plugin --scope user \
    #     --hooks minimal --yes --dry-run --json
    # Setting this false again stops reinstalls but does NOT uninstall; that
    # needs `/plugin uninstall ecc@ecc` plus reverting the settings.json diff.
    enable = true;
    version = "2.2.3";
    scope = "user"; # user | project | local
    # The installer ARGUMENT only. Under --mode claude-plugin every hook ships
    # inside the plugin's hooks/hooks.json and is filtered AT RUNTIME, so this
    # value does not by itself decide which hooks run.
    #
    # The effective profile is persisted by the installer into settings.json as
    #   pluginConfigs."ecc@ecc".options.hook_profile
    # which Claude surfaces to hooks as CLAUDE_PLUGIN_OPTION_HOOK_PROFILE and
    # scripts/lib/hook-flags.js reads. That file is repo-tracked, so the
    # effective profile is already declarative — and it is the lever to change,
    # NOT an ECC_HOOK_PROFILE export, which takes PRECEDENCE over the plugin
    # option and would silently defeat any later `/plugin config` change.
    #
    # Kept in step with that value deliberately: this said "minimal" until
    # 2026-10-09 while the real profile was "standard". Every profile-gated
    # hook in 2.2.3 is gated to `standard,strict`, so a genuinely-applied
    # "minimal" would switch 14 of the 24 off — PreCompact context preservation
    # and the Edit/Write fact gate among them.
    hooks = "standard"; # off | minimal | standard | strict
    pluginId = "ecc@ecc";
  };

  # Written by the activation script, read by its own guard. Mirrors how
  # catalyst.nix owns ~/.catalyst/secrets.env.
  eccStamp = "${config.home.homeDirectory}/.claude/.ecc-version";
  eccSettings = "${repo}/dotfiles/claude/settings.json";
in
{
  home.file = {
    ".claude/settings.json" = {
      source = live "settings.json";
      # The app replaces this symlink with a regular file every time it records
      # a permission, a plugin enable, or a plugin option (atomic rename — see
      # the header). home-manager then finds a real file where its link should
      # be and refuses to clobber it. On 2026-10-09 that aborted an entire
      # darwin switch at checkLinkTargets, because the backup slot was already
      # occupied by a settings.json.hm-bak left behind on 2026-09-06.
      #
      # force overwrites rather than backing up, so a switch can always relink.
      # The data loss that would otherwise imply is held off by
      # scripts/claude-settings-sync.sh: `just switch` runs it in --check mode
      # and refuses to switch while the live file holds anything the repo has
      # not absorbed, so app-side settings are committed, never destroyed.
      #
      # ONLY this file needs it. CLAUDE.md, agents/, commands/ and hooks/ were
      # verified on 2026-10-09 (readlink -f) to still resolve through their
      # out-of-store links into the repo — nothing rewrites those atomically.
      force = true;
    };
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
