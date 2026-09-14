# devspace wiring — owns DEV_SPACE_ROOT and the catalyst CLI itself.
# The devspace root is ~/devspace on EVERY machine; organizations are
# directories under it (teak/, catalyst/, …) and identity is org-scoped in
# contexts.nix. No more machine-flavored root names.
# catalyst-cli owns its packaging (its own flake); this module only consumes
# packages.${system}.default — binary + cy symlink + completions + widget.
# It also provisions ~/.catalyst: config.yaml as a LIVE symlink into this repo
# (catalyst writes config.yaml — repo add/set — and its atomic writer resolves
# symlinks, so edits land back here), and secrets.env rendered from 1Password.
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
  };

  config = {
    home.sessionVariables.DEV_SPACE_ROOT = devspace;

    home.packages = [ catalyst-cli ];

    # Live symlink: catalyst writes config.yaml (repo add/set) THROUGH the
    # link into this repo — same lane as vscode/claude. Never a store path:
    # a read-only config would break every catalyst write.
    home.file.".catalyst/config.yaml".source =
      config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/catalyst/config.yaml";

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
