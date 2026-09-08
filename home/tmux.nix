# tmux — one of the two tools that made pure-afx impossible: it publishes
# source tarballs only, no prebuilt binaries for any platform. nixpkgs builds
# it, which is precisely why this migration works.
{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    historyLimit = 50000;
    escapeTime = 10;
    keyMode = "emacs";
    mouse = true;
    baseIndex = 1;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
      continuum
    ];

    extraConfig = ''
      # The old .tmux.conf hardcoded `default-shell /bin/zsh`, which under Nix
      # points at the system zsh rather than the one this config manages.
      set -g default-shell ${pkgs.zsh}/bin/zsh

      set -g renumber-windows on
      set -g set-clipboard on
      setw -g pane-base-index 1
    '';
  };
}
