# zsh — the highest-risk part of this migration.
#
# Under the old setup, afx's `local` package is what sourced ~/.zsh/[0-9]*.zsh.
# Remove afx without replacing that loop and you get a shell with zero aliases
# and zero functions, silently. This module IS that replacement.
{ pkgs, lib, config, dotfilesRepo, ... }:

let
  # Live path into the working checkout, so `.zsh/*.zsh` stays editable without
  # a rebuild. This is the deliberate hybrid: config you tinker with is live,
  # everything else is a pure store path.
  repo = "${config.home.homeDirectory}/${dotfilesRepo}";
  mkLive = config.lib.file.mkOutOfStoreSymlink;
in
{
  # Payload configs the old dotbot base profile linked; static, so pure store.
  xdg.configFile."gomi".source = ../dotfiles/.config/gomi;
  xdg.configFile."enhancd".source = ../dotfiles/.config/enhancd;
  xdg.configFile."gh-dash".source = ../dotfiles/.config/gh-dash;
  xdg.configFile."zsh".source = ../dotfiles/.config/zsh;   # zsh-abbr abbreviations

  # Link each file INDIVIDUALLY so ~/.zsh stays a real directory — HM itself
  # installs plugins under ~/.zsh/plugins/, and a whole-directory symlink made
  # those writes land outside $HOME (same failure shape as the old afx#40 bug).
  # builtins.readDir keeps this in sync with the repo automatically.
  home.file = lib.mapAttrs' (name: _:
    lib.nameValuePair ".zsh/${name}" {
      source = mkLive "${repo}/dotfiles/.zsh/${name}";
    }
  ) (builtins.readDir ../dotfiles/.zsh);

  programs.zsh = {
    enable = true;

    # HM emits compinit as part of its completion block, which lands BEFORE
    # initContent. That ordering is load-bearing: 40_functions.zsh calls
    # `compdef`, which does not exist until compinit has run. The old .zshrc
    # got this wrong (compinit ran three times, all too late).
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 1000000;
      save = 1000000;
      path = "${config.xdg.dataHome}/zsh/history";
      extended = true;          # extended_history
      ignoreDups = true;        # hist_ignore_dups
      ignoreSpace = true;       # hist_ignore_space
      expireDuplicatesFirst = true;
      share = true;             # share_history
    };

    plugins = [
      {
        name = "zsh-abbr";
        src = pkgs.zsh-abbr;
        file = "share/zsh/zsh-abbr/zsh-abbr.zsh";
      }
      {
        name = "zsh-history-search-multi-word";
        src = pkgs.zsh-history-search-multi-word;
        file = "share/zsh/zsh-history-search-multi-word/history-search-multi-word.plugin.zsh";
      }
    ];

    initContent = lib.mkMerge [
      # fpath must be extended BEFORE compinit runs (HM emits compinit around
      # order 550; mkOrder 400 lands ahead of it). These are the vendored
      # completions (_gomi, _gist, _iap_curl …) the old .zshenv exposed.
      (lib.mkOrder 400 ''
        fpath=("$HOME/.zsh/Completion" $fpath)
      '')

      (lib.mkAfter ''
      # ── the afx replacement ────────────────────────────────────────────
      # Source every numbered config file, in order. 00_guards.zsh defines
      # has()/src()/try_eval()/try_comp() and MUST sort first — everything
      # after it depends on those helpers.
      for _f in "$HOME"/.zsh/[0-9]*.zsh(N); do
        source "$_f"
      done
      unset _f

      # ── setopts not covered by programs.zsh.history ────────────────────
      setopt auto_cd auto_pushd pushd_ignore_dups pushd_to_home
      setopt extended_glob glob_dots no_case_glob mark_dirs
      setopt interactive_comments no_beep no_list_beep no_hist_beep
      setopt complete_in_word always_last_prompt auto_menu auto_param_slash
      setopt long_list_jobs notify no_flow_control
      setopt no_clobber rm_star_wait print_exit_value
      setopt hist_verify hist_reduce_blanks hist_no_store hist_no_functions

      # only record commands that actually resolve to something
      zshaddhistory() { whence ''${''${(z)1}[1]} >| /dev/null || return 1 }

      # ── aliases ported from afx plugin.env/snippet blocks ──────────────
      # These lived only in ~/.config/afx/*.yaml, not in 30_aliases.zsh —
      # verified no collisions. exa aliases carried over onto eza.
      alias ls='eza'
      alias l='eza -1'
      alias ll='eza -l --git'
      alias la='eza -a'
      alias lla='eza -la --git'
      alias lt='eza --tree --level=2'
      alias lta='eza --tree --level=2 -a'
      alias cat='bat'
      alias rm='gomi'
      alias g='lazygit'
      alias jq='jq -C'
      alias diff='colordiff -u'
      export BAT_PAGER='less -RF'

      # fzf integration — guard on a real terminal, not [[ -o zle ]]; key
      # bindings are meaningless without one and the eval errors headlessly.
      if has fzf && [[ -t 0 ]]; then
        eval "$(fzf --zsh)"
      fi
      '')
    ];
  };

  # fzf: the old setup had THREE competing configurations (.zprofile's
  # FZF_DEFAULT_OPTS, afx's fzf-cli.yaml, and `eval "$(fzf --zsh)"` in .zshrc).
  # This is the single source of truth.
  programs.fzf = {
    enable = true;
    # HM's integration evals fzf's key-bindings unguarded; in a shell with no
    # real terminal that prints "can't change option: zle" (verified on the
    # old setup too). We do it ourselves below, guarded on an actual TTY.
    enableZshIntegration = false;
    defaultCommand = "fd --type f";
    changeDirWidget = {
      command = "fd --type d";
      options = [ "--preview 'tree -C {} | head -100'" ];
    };
    fileWidget = {
      command = "rg --files --hidden --follow --glob '!.git/*'";
      options = [
        "--preview 'bat --color=always --style=header,grid --line-range :100 {}'"
      ];
    };
    defaultOptions = [
      "--height 75%" "--multi" "--reverse" "--margin=0,1"
      "--marker=+" "--pointer=▶" "--prompt=❯ " "--no-separator"
    ];
  };

  programs.bat = {
    enable = true;
    config.theme = "OneHalfDark";
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
