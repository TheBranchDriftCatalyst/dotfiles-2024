# devspace wiring — owns DEV_SPACE_ROOT and the catalyst CLI itself.
# The devspace root is ~/devspace on EVERY machine; organizations are
# directories under it (teak/, catalyst/, …) and identity is org-scoped in
# contexts.nix. No more machine-flavored root names.
# catalyst-cli owns its packaging (its own flake); this module only consumes
# packages.${system}.default — binary + cy symlink + completions + widget.
{
  lib,
  config,
  inputs,
  system,
  ...
}:

let
  cfg = config.catalyst.devspace;
  devspace = "${config.home.homeDirectory}/${cfg.root}";
  catalyst-cli = inputs.catalyst-cli.packages.${system}.default;
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
