# wakatime — coding-time heartbeats, pointed at a SELF-HOSTED receiver.
#
# Two things are managed here, and only two:
#
#   1. ~/.wakatime.cfg, GENERATED from the base below on every switch. The
#      WakaTime app and the editor plugins all read this one file; none of
#      them own it any more. Corollary worth saying out loud: settings typed
#      into the WakaTime UI (or the VS Code "enter your api key" prompt) are
#      CLOBBERED on the next switch. Change things here, not there.
#
#   2. The api key, rendered from 1Password at activation — never committed,
#      never in the store. Same lane as ~/.catalyst/secrets.env: the file in
#      the store is a TEMPLATE carrying an op:// reference, and `op inject`
#      turns it into a 0600 real file in $HOME. This is why the cfg is NOT a
#      home.file symlink: a store path is world-readable, and the api key is
#      a credential to a server that accepts writes.
#
# Rejected alternative, for the record: wakatime-cli also supports
#   api_key_vault_cmd = op read op://...
# which would keep the key out of $HOME entirely. It puts 1Password on the
# heartbeat path instead of the switch path — every few minutes, from GUI
# editors with a truncated PATH, against a vault that locks. A dropped
# heartbeat is silent data loss, so the key gets materialized once per switch
# instead.
#
# The binary: nix installs nothing here. The macOS app is a Homebrew cask
# (hosts/*/default.nix) and every editor plugin downloads its own
# wakatime-cli into ~/.wakatime/. pkgs.wakatime-cli exists if a terminal-side
# consumer ever needs one — nothing does yet.
{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.catalyst.wakatime;

  # INI, hand-rolled rather than pkgs.formats.ini, for ONE reason: lists.
  # wakatime's `exclude`/`include` are multi-value keys written as indented
  # continuation lines, which pkgs.formats.ini cannot express. Verified
  # against wakatime-cli v2.26 (--verbose reports the parsed patterns, one
  # regex per line, surrounding whitespace trimmed).
  renderValue = v: if lib.isBool v then lib.boolToString v else toString v;

  # A list becomes `key =` followed by one indented line per entry; a scalar
  # stays on the key's own line. Kept apart so the list form does not leave a
  # trailing space after the `=`.
  renderKV =
    k: v:
    if lib.isList v then
      "${k} =\n" + lib.concatMapStringsSep "\n" (e: "    ${toString e}") v + "\n"
    else
      "${k} = ${renderValue v}\n";

  # null = "leave the key out and let wakatime's own default stand". Every
  # option below leans on this, so an unset knob is silence, not an empty
  # string that overrides a sane default with nothing.
  renderSection =
    name: attrs:
    "[${name}]\n"
    + lib.concatStrings (lib.mapAttrsToList renderKV (lib.filterAttrs (_: v: v != null) attrs));

  baseSettings = {
    # The receiver. Self-hosted receivers take the API ROOT, not the host —
    # wakapi-style deployments want https://<host>/api.
    api_url = cfg.apiUrl;

    # An op:// REFERENCE in the store copy; the real key only ever exists in
    # the 0600 file activation writes. Nothing secret is committed.
    api_key = cfg.apiKeyRef;

    # Which box this is, on the receiver's dashboard. The whole reason this
    # module carries a per-host option — see hosts/<name>/home.nix.
    hostname = cfg.machineName;

    # Queue heartbeats locally when the receiver is unreachable and flush
    # them later. This is wakatime-cli's default; it is pinned here because
    # a self-hosted receiver goes down in ways api.wakatime.com does not,
    # and losing a day of history to a container restart is the failure this
    # setting exists to prevent.
    offline = true;

    # Editor status-bar readout ("2 hrs 14 mins today"). Plugin-side setting
    # that lives in this file, so it belongs to the base, not to VS Code's
    # own settings.json.
    status_bar_enabled = true;
    status_bar_coding_activity = true;

    # Noise floor. Patterns are case-insensitive regexes matched against the
    # absolute path, NOT globs. Everything here is either machine-generated,
    # ephemeral, or someone else's code: counting it as "coding time" makes
    # the dashboard lie.
    exclude = [
      "^COMMIT_EDITMSG$" # git commit buffers — editing one is not coding
      "^TAG_EDITMSG$"
      "^MERGE_MSG$"
      "^/nix/store/" # read-only, and not yours
      "/node_modules/"
      "/\\.direnv/"
      "/\\.venv/"
      "/__pycache__/"
      "/\\.git/"
      "^/private/var/folders/" # macOS per-user temp
      "^/tmp/"
    ];
  };

  settings = baseSettings // cfg.extraSettings;

  cfgText = lib.concatStringsSep "\n" (
    [ (renderSection "settings" settings) ] ++ lib.mapAttrsToList renderSection cfg.extraSections
  );

  # The template: committed-safe, store-safe, secret-free.
  cfgTemplate = pkgs.writeText "wakatime.cfg.tpl" cfgText;

  target = "${config.home.homeDirectory}/.wakatime.cfg";
in
{
  options.catalyst.wakatime = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Generate ~/.wakatime.cfg. Off means nix does not touch the file at
        all — it does not delete an existing one, so flipping this off on a
        borrowed box leaves whatever was already there alone.
      '';
    };

    machineName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "teakbook-work";
      description = ''
        The name this machine reports to the receiver — a free-form label,
        not a DNS name. SET THIS PER HOST in hosts/<hostname>/home.nix: it is
        the one field here that is genuinely per-machine, and without it the
        dashboard cannot tell two boxes apart by anything but a guess.

        null omits the key entirely, and wakatime-cli falls back to the real
        system hostname. That is the right answer for linux-generic, which is
        a shape for borrowed machines rather than a specific machine.
      '';
    };

    apiUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "https://boomtime.knowledgedump.space/api/v1";
      example = "https://wakapi.example.com/api/v1";
      description = ''
        API root of the receiver — boomtime, self-hosted. NOT per-host: one
        receiver collects every machine, so this stays in the module and
        hosts/* only sets machineName.

        The /api/v1 suffix is the real path, not decoration. wakatime-cli
        appends /users/current/heartbeats.bulk to this value; verified
        against a local listener, where every heartbeat landed on
        POST /api/v1/users/current/heartbeats.bulk (the CLI also normalizes a
        bare /api up to /api/v1, so both spellings work — this one is the
        canonical form and needs no rewriting).

        null falls back to wakatime-cli's built-in api.wakatime.com, which
        for this setup is the wrong place, not a safe default.
      '';
    };

    apiKeyRef = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "op://dev/wakatime/api-key";
      example = "op://dev/wakatime/api-key";
      description = ''
        1Password secret REFERENCE (vault/item/field) for the receiver's api
        key — resolved by `op inject` at activation, never stored in nix.
        Rotate the value in 1Password; this string does not change.

        null writes the cfg with no api_key line at all.
      '';
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.nullOr (
          lib.types.oneOf [
            lib.types.bool
            lib.types.int
            lib.types.str
            (lib.types.listOf lib.types.str)
          ]
        )
      );
      default = { };
      example = {
        exclude_unknown_project = true;
      };
      description = ''
        Merged OVER the base [settings] block — same key wins here. This is
        the extension point for both hosts/* and future settings: the base
        stays a base, and an override is one line instead of a fork of it.
        A null value deletes a base key.
      '';
    };

    extraSections = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      example = {
        projectmap = {
          "/devspace/teak/(.*)" = "teak-\\1";
        };
      };
      description = ''
        Extra cfg sections verbatim — [projectmap], [git], [git_submodule].
        Rendered after [settings] in the order given.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Real 0600 file, written at activation — not a home.file symlink. See
    # the header: the rendered file carries a credential, and everything in
    # the nix store is world-readable.
    home.activation.wakatimeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      _tpl="${cfgTemplate}"
      _out=${lib.escapeShellArg target}
      _op="${pkgs._1password-cli}/bin/op"
      _tmp=$(mktemp)

      ${
        if cfg.apiKeyRef == null then
          ''
            # No key configured — the config still lands (excludes, hostname,
            # status bar all apply the moment a key shows up), it just cannot
            # send anything yet.
            $DRY_RUN_CMD install -m 600 "$_tpl" "$_out"
            echo "wakatime: .wakatime.cfg written WITHOUT an api key (catalyst.wakatime.apiKeyRef is null)"
          ''
        else
          ''
            if "$_op" inject -f -i "$_tpl" -o "$_tmp" >/dev/null 2>&1; then
              $DRY_RUN_CMD install -m 600 "$_tmp" "$_out"
              echo "wakatime: .wakatime.cfg rendered (api key from 1Password)"
            elif [ -e "$_out" ]; then
              # Locked, offline, or the item does not exist yet. KEEP the old
              # file whole rather than rewriting it keyless: config edits then
              # wait for the next unlocked switch, which is a delay. The other
              # way round silently stops tracking, which is data loss.
              echo "wakatime: ✖ op inject failed (locked? offline? item missing?) — keeping existing .wakatime.cfg"
              echo "wakatime:   config changes in this switch did NOT land; unlock 1Password and re-switch"
            else
              $DRY_RUN_CMD install -m 600 "$_tpl" "$_out"
              echo "wakatime: ✖ op inject failed and no existing config — wrote it with the op:// reference UNRESOLVED"
              echo "wakatime:   nothing will be tracked until ${cfg.apiKeyRef} resolves. Seed it once with:"
              echo "wakatime:     op item create --category=password --title=wakatime --vault=dev 'api-key=<key>'"
            fi
          ''
      }

      rm -f "$_tmp"
    '';
  };
}
