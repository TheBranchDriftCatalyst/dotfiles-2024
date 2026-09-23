# devspace wiring — owns DEV_SPACE_ROOT and the catalyst CLI itself.
# The devspace root is ~/devspace on EVERY machine; organizations are
# directories under it (teak/, catalyst/, …) and identity is org-scoped in
# contexts.nix. No more machine-flavored root names.
# catalyst-cli owns its packaging (its own flake); this module only consumes
# packages.${system}.default — binary + cy symlink + completions + widget.
# It also provisions ~/.catalyst: config.yaml seeded from 1Password (it is NOT
# in this repo — see below), and secrets.env rendered from 1Password.
{
  pkgs,
  lib,
  config,
  inputs,
  system,
  dotfilesRepo,
  ...
}:

let
  cfg = config.catalyst.devspace;
  devspace = "${config.home.homeDirectory}/${cfg.root}";
  catalyst-cli = inputs.catalyst-cli.packages.${system}.default;
  repo = "${config.home.homeDirectory}/${dotfilesRepo}";
  # The working copy whose ./bin/catalyst useLocalCatalystCLI points at.
  localCheckout = "${devspace}/${cfg.localCatalystPath}";
  # 1Password Document holding config.yaml — a document, not an op:// field
  # reference, for the same reason as kube.nix: a document's payload is not a
  # field, so `op read op://…` cannot fetch it.
  opVault = "dev";
  # PER-HOST document. config.yaml genuinely diverges between machines — the
  # worktree/devspace flow is a work-machine pattern, catalystM5 works on main
  # — so one shared document would mean a permanent drift warning on at least
  # one host, and a push from the wrong machine would destroy the other's
  # paths. Resolved at runtime (not from nix) so the justfile recipes and this
  # activation always agree on the name.
  opConfigItemPrefix = "catalyst-config";
  catalystConfig = "${config.home.homeDirectory}/.catalyst/config.yaml";
in
{
  options.catalyst.devspace = {
    root = lib.mkOption {
      type = lib.types.str;
      default = "devspace";
      description = "devspace folder name under $HOME — the same on every machine";
    };
    orgSubdir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "catalyst";
      description = "org dir holding the personal-org repos (null = devspace root)";
    };

    useLocalCatalystCLI = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install the catalyst binary from your LOCAL checkout instead of the
        flake input (which tracks origin/main).

        This is a swap, never an overlay: with it on, the flake's package is
        not installed at all, so only one catalyst binary exists and nothing
        shadows anything. ~/bin/{catalyst,cy} become out-of-store symlinks to
        <localCatalystPath>/bin/catalyst — the same live-symlink lane this
        module already uses for config.yaml — so `task build` in that checkout
        takes effect immediately, with no darwin-rebuild in the loop.

        Completions and the fzf-tab widget keep coming from the flake input's
        store path either way: they shell out to whichever `catalyst` is on
        PATH, so they follow the swap for free and never go stale.

        The cost is that your shell runs uncommitted code, and that a checkout
        you have never built leaves the symlink dangling. Activation warns
        about the second one; `task which` in the checkout reports both.
      '';
    };

    localCatalystPath = lib.mkOption {
      type = lib.types.str;
      default = ".catalyst-cli";
      description = "checkout used by useLocalCatalystCLI, relative to the devspace root";
    };
  };

  config = {
    home.sessionVariables.DEV_SPACE_ROOT = devspace;

    # Exactly one catalyst binary, always. Local mode does not layer a symlink
    # over the packaged build — it replaces it, so there is no shadow, no PATH
    # ordering to get right, and no "which one am I running?".
    home.packages = lib.optional (!cfg.useLocalCatalystCLI) catalyst-cli;

    # Out-of-store symlinks: they resolve at USE time, so the binary tracks
    # `task build` in the checkout. A store path would freeze whatever existed
    # at switch time — the stale-binary trap this option exists to avoid.
    home.file."bin/catalyst" = lib.mkIf cfg.useLocalCatalystCLI {
      source = config.lib.file.mkOutOfStoreSymlink "${localCheckout}/bin/catalyst";
    };
    home.file."bin/cy" = lib.mkIf cfg.useLocalCatalystCLI {
      source = config.lib.file.mkOutOfStoreSymlink "${localCheckout}/bin/catalyst";
    };

    # A never-built checkout leaves those links dangling, and a dangling
    # catalyst is a confusing failure ("command not found" for a tool you can
    # see in ~/bin). Say so at switch time, where it is still cheap to fix.
    home.activation.catalystLocalCheck = lib.mkIf cfg.useLocalCatalystCLI (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -x "${localCheckout}/bin/catalyst" ]; then
          echo "catalyst: ✖ useLocalCatalystCLI is on but ${localCheckout}/bin/catalyst is missing"
          echo "catalyst:   run 'task build' in ${localCheckout} — ~/bin/catalyst dangles until you do"
        fi
      ''
    );

    # config.yaml: deliberately NOT in this repo and NOT a symlink into it.
    # It carries org-identifying data — jira tenant + cloud_id, work email,
    # private repo URLs — and this repo is public. It lives in ~/.catalyst and
    # in 1Password, nowhere else. (No credentials were ever in it: jira.token
    # and github.token are {env.X} refs resolved from secrets.env below.)
    #
    # The LOCAL file is AUTHORITATIVE, because catalyst writes it between
    # switches (config set, repo add). So activation never overwrites it:
    #   * missing        -> seed, so a fresh machine comes up working
    #   * present + drift -> WARN only, so you know to push
    # Pushing is always deliberate: `just catalyst-config-push`.
    #
    # Seed the document once per account:
    #   just catalyst-config-push        (creates it, named per host)
    home.activation.catalystConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      _out=${lib.escapeShellArg catalystConfig}
      _legacy=${lib.escapeShellArg "${repo}/dotfiles/catalyst/config.yaml"}
      _op="${pkgs._1password-cli}/bin/op"
      _vault=${lib.escapeShellArg opVault}
      # HM activation runs with a nix-store-only PATH — no /usr/sbin, no /bin —
      # so `scutil`/`hostname` are NOT resolvable by name here (that mistake
      # aborted activation with exit 127). Absolute path, guarded by -x, and a
      # username fallback so this can never fail: ./home is shared with the
      # linux targets, where scutil does not exist at all.
      _host=${lib.escapeShellArg config.home.username}
      if [ -x /usr/sbin/scutil ]; then
        _h=$(/usr/sbin/scutil --get LocalHostName 2>/dev/null || true)
        [ -n "$_h" ] && _host="$_h"
      fi
      _item="${opConfigItemPrefix}-$_host"

      _fetch() { "$_op" document get "$_item" --vault "$_vault" --out-file "$1" --force >/dev/null 2>&1 && [ -s "$1" ]; }

      if [ ! -e "$_out" ]; then
        _tmp=$(mktemp)
        if _fetch "$_tmp"; then
          $DRY_RUN_CMD mkdir -p "$(dirname "$_out")"
          $DRY_RUN_CMD install -m 600 "$_tmp" "$_out"
          echo "catalyst: config.yaml seeded from 1Password"
        elif [ -f "$_legacy" ]; then
          # migration off the old in-repo symlink: adopt the repo copy rather
          # than come up with no config just because the document is unseeded
          $DRY_RUN_CMD mkdir -p "$(dirname "$_out")"
          $DRY_RUN_CMD install -m 600 "$_legacy" "$_out"
          echo "catalyst: config.yaml adopted from the old in-repo copy — it is now"
          echo "catalyst:   local only. Seed 1Password so other machines get it:"
          echo "catalyst:     just catalyst-config-push"
        else
          echo "catalyst: ✖ no config.yaml, and op document get failed"
          echo "catalyst:   (1Password locked, offline, or never seeded?)"
          echo "catalyst:   seed it once from a machine that has the file:"
          echo "catalyst:     just catalyst-config-push"
        fi
        rm -f "$_tmp"
      else
        # Drift check. Never destructive — the local file wins, we only report,
        # because catalyst may have written it since the last push.
        _tmp=$(mktemp)
        if _fetch "$_tmp"; then
          if ! cmp -s "$_out" "$_tmp"; then
            echo "catalyst: ⚠ config.yaml has DRIFTED from the 1Password copy"
            echo "catalyst:     local      $(wc -l <"$_out" | tr -d ' ') lines"
            echo "catalyst:     1Password  $(wc -l <"$_tmp" | tr -d ' ') lines"
            echo "catalyst:   push yours:   just catalyst-config-push"
            echo "catalyst:   or take theirs: just catalyst-config-pull"
          fi
        fi
        rm -f "$_tmp"
      fi
    '';

    # secrets.env: rendered from 1Password on every switch (op:// refs live in
    # the committed secrets.env.tpl; values only ever land in the 0600 file).
    # The installed binary loads it itself at startup, so catalyst
    # authenticates from any cwd — no direnv shell required. Degrades to a
    # warning (existing file kept) when op is locked, absent, or offline.
    home.activation.catalystSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      _tpl="${repo}/dotfiles/catalyst/secrets.env.tpl"
      _out="${config.home.homeDirectory}/.catalyst/secrets.env"
      _op="${pkgs._1password-cli}/bin/op"
      if [ -f "$_tpl" ]; then
        _tmp=$(mktemp)
        if "$_op" inject -f -i "$_tpl" -o "$_tmp" >/dev/null 2>&1; then
          $DRY_RUN_CMD mkdir -p "$(dirname "$_out")"
          $DRY_RUN_CMD install -m 600 "$_tmp" "$_out"
          echo "catalyst: secrets.env rendered from 1Password"
        else
          echo "catalyst: ✖ op inject failed (locked? offline?) — keeping existing secrets.env"
        fi
        rm -f "$_tmp"
      fi
    '';

    programs.zsh.initContent = lib.mkMerge [
      # fpath before compinit (HM emits it ~order 550; 400 matches zsh.nix's
      # vendored-completions pattern). Darwin's /etc/zshrc NIX_PROFILES loop
      # covers this too — the explicit line makes linux-generic identical.
      # compaudit-safe: the parent is a read-only store path.
      (lib.mkOrder 400 ''
        fpath=("${catalyst-cli}/share/zsh/site-functions" $fpath)
      '')

      # AFTER zsh.nix's mkAfter block (1500): needs compinit (compdef at
      # source time) AND init.zsh's `eval "$(fzf --zsh)"` so the widget's ^I
      # fallback capture chains to fzf-completion instead of burying it.
      # The file self-guards missing fzf/TTY/re-sourcing at runtime.
      (lib.mkOrder 1600 ''
        source ${catalyst-cli}/share/catalyst/catalyst-wrappers.zsh
      '')
    ];
  };
}
