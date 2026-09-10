# tmux — one of the two tools that made pure-afx impossible: it publishes
# source tarballs only, no prebuilt binaries for any platform. nixpkgs builds
# it, which is precisely why this migration works.
#
# 2026-09: the old dotfiles/.tmux.conf was ORPHANED by the first migration —
# nothing linked it, so its bindings (prefix C-t, path-preserving splits,
# hjkl panes) had silently reverted to tmux defaults. This module now carries
# the deliberate parts of that config. Dropped from the old file: tpm (HM
# owns plugins), solarized colours (livery owns colour), reattach-to-user-
# namespace (set-clipboard covers it), the gte/gtj translate binds (functions
# long gone), and the kube/gcp/wifi/battery status segments (those scripts
# aren't packaged yet — README "known gaps").
{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    historyLimit = 50000;
    escapeTime = 10;
    keyMode = "emacs";       # status/prompt keys; copy-mode is vi below
    mouse = true;
    baseIndex = 1;
    prefix = "C-t";          # the old muscle memory — C-b is unbound

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank                   # owns `y` in copy-mode → system clipboard
      resurrect
      continuum
      fzf-tmux-url           # prefix-u: fzf-pick a URL from the pane
    ];

    # Nix-interpolated lines stay here; everything else is a real .conf file
    # (IDE-highlighted) in ./dotfiles (the store payload set).
    extraConfig = ''
      # The old .tmux.conf hardcoded `default-shell /bin/zsh`, which under Nix
      # points at the system zsh rather than the one this config manages.
      set -g default-shell ${pkgs.zsh}/bin/zsh

    '' + builtins.readFile ./dotfiles/tmux.conf;
  };
}
