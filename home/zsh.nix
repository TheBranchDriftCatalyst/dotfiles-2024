# zsh — single-mechanism init: home-manager owns the whole story.
#
# History: afx sourced ~/.zsh/[0-9]*.zsh; the first migration re-implemented
# that loop inside initContent ("the afx replacement"), leaving two layered
# init systems. This module is the melt: settings live here declaratively,
# authored commands live in ./zsh/*.zsh (store paths, sourced by name below,
# commented-out until used — see the curation contract in those files).
# There is no ~/.zsh directory and no sourcing loop anymore.
#
# Machine-local secrets: the old loop picked up gitignored *secret*.zsh
# drop-ins. That escape hatch is gone — secrets belong in @secrets/sops-nix,
# not shell files.
{
  pkgs,
  lib,
  config,
  ...
}:

{
  # Payload configs the old dotbot base profile linked; static one-shot
  # provisioning, so settings live as Nix data and YAML renders at build time.
  # gh-dash reads config.yml, not .yaml.
  xdg.configFile."gh-dash/config.yml".source = (pkgs.formats.yaml { }).generate "gh-dash-config.yml" {
    prSections = [
      {
        title = "My Pull Requests";
        filters = "is:open author:@me";
      }
      {
        title = "Needs My Review";
        filters = "is:open review-requested:@me";
      }
      {
        title = "Involved";
        filters = "is:open involves:@me -author:@me";
      }
    ];
    issuesSections = [
      {
        title = "My Issues";
        filters = "is:open author:@me";
      }
      {
        title = "Assigned";
        filters = "is:open assignee:@me";
      }
      {
        title = "Involved";
        filters = "is:open involves:@me -author:@me";
      }
    ];
    defaults = {
      preview = {
        open = true;
        width = 50;
      };
      prsLimit = 20;
      issuesLimit = 20;
      view = "prs";
      layout = {
        prs = {
          updatedAt.width = 7;
          repo.width = 15;
          author.width = 15;
          assignees = {
            width = 20;
            hidden = true;
          };
          base = {
            width = 15;
            hidden = true;
          };
          lines.width = 16;
        };
        issues = {
          updatedAt.width = 7;
          repo.width = 15;
          creator.width = 10;
          assignees = {
            width = 20;
            hidden = true;
          };
        };
      };
      refetchIntervalMinutes = 30;
    };
    keybindings = {
      issues = [ ];
      prs = [ ];
    };
    repoPaths = { };
    pager.diff = "";
  };

  # gomi (the `rm` below) — same treatment.
  xdg.configFile."gomi/config.yaml".source = (pkgs.formats.yaml { }).generate "gomi-config.yaml" {
    core = {
      trash = {
        strategy = "auto";
        home_fallback = true;
      };
      restore = {
        confirm = true;
        verbose = true;
      };
      permanent_delete.enable = false;
      trash_dir = "";
    };
    ui = {
      density = "compact";
      exit_message = "later alligator!";
      preview = {
        syntax_highlight = true;
        directory_command = "ls -GF -1 -A --color=always";
        # themes: https://xyproto.github.io/splash/docs/index.html
        colorscheme = "dracula";
      };
      paginator_type = "dots";
    };
    history = {
      include.within_days = 365;
      exclude = {
        files = [ ".DS_Store" ];
        patterns = [ ];
        globs = [ "*cache*" ];
        size = {
          min = "0KB";
          max = "20GB";
        };
      };
    };
    logging = {
      enabled = true;
      level = "debug";
      rotation = {
        max_size = "10MB";
        max_files = 3;
      };
    };
  };

  programs.zsh = {
    enable = true;

    # HM emits compinit as part of its completion block, which lands BEFORE
    # initContent. That ordering is load-bearing: ./zsh/functions.zsh calls
    # `compdef` (when uncommented), which does not exist until compinit runs.
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 1000000;
      save = 1000000;
      path = "${config.xdg.dataHome}/zsh/history";
      extended = true; # extended_history
      ignoreDups = true; # hist_ignore_dups
      ignoreSpace = true; # hist_ignore_space
      expireDuplicatesFirst = true;
      share = true; # share_history
    };

    # zsh-abbr via its first-class HM module (below), not a manual plugin —
    # the old ~/.config/zsh/abbreviations file was functionally orphaned
    # (nothing set ABBR_USER_ABBREVIATIONS_FILE after afx retired).
    zsh-abbr = {
      enable = true;
      abbreviations = {
        cf = "conftest";
        tf = "terraform";
        k8 = "kubectl";
      };
    };

    plugins = [
      {
        name = "zsh-history-search-multi-word";
        src = pkgs.zsh-history-search-multi-word;
        file = "share/zsh/zsh-history-search-multi-word/history-search-multi-word.plugin.zsh";
      }
    ];

    initContent = lib.mkMerge [
      # fpath must be extended BEFORE compinit runs (HM emits compinit around
      # order 550; mkOrder 400 lands ahead of it). Only vendored completion
      # left is _gomi — gomi ships none and can't generate one.
      #
      # NESTED one level on purpose: a bare "${./zsh/completions}" imports as
      # a TOP-LEVEL store path, and compaudit audits an fpath dir's parent —
      # which would be /nix/store itself, group-writable under Determinate
      # Nix (drwxrwxr-t root:nixbld) → "insecure directories" prompt on every
      # shell. Nesting makes the parent a read-only store path instead.
      (lib.mkOrder 400 ''
        fpath=("${
          pkgs.runCommand "zsh-vendored" { } ''
            mkdir -p $out
            cp -r ${./zsh/completions} $out/completions
          ''
        }/completions" $fpath)

        # Generated-at-build-time completions for tools whose package ships
        # no _file but can emit one (audit 2026-09: only act). Never stale:
        # regenerates whenever the package bumps.
        fpath=("${
          pkgs.runCommand "zsh-generated-completions" { } ''
            mkdir -p $out/completions
            HOME=$TMPDIR ${pkgs.act}/bin/act completion zsh > $out/completions/_act
          ''
        }/completions" $fpath)
      '')

      (lib.mkAfter ''
        # ── the curated command library (see the contract in each file) ────
        source ${./zsh/aliases.zsh}
        source ${./zsh/functions.zsh}
        source ${./zsh/fzf-git.zsh}

        # LS_COLORS is rendered at BUILD time by vivid (neon-cyberpunk theme,
        # matches the livery) — replaces the 2012 .dir_colors relic and its
        # per-shell dircolors eval. Exported BEFORE init.zsh, whose list-colors
        # zstyle reads it (that zstyle was a silent no-op for years — nothing
        # set LS_COLORS). Livery followup: generate the theme from the palette.
        export LS_COLORS="$(<${
          pkgs.runCommand "ls-colors-cyberdream" { } "${pkgs.vivid}/bin/vivid generate cyberdream > $out"
        })"

        # ── ACTIVE runtime settings: setopts, zstyles, keybindings, core
        # aliases — pure zsh, so it lives as a real file (IDE-highlighted).
        source ${./zsh/init.zsh}

        # ── dynamic devshell completions ─────────────────────────────────
        # direnv swaps PATH per-repo but never fpath, so flake devshell
        # tools (tilt, uv, pnpm, kubectl…) silently lose completions. On
        # every PATH change, find each /nix/store/*/bin's sibling
        # share/zsh/site-functions and ADDITIVELY register its #compdef
        # headers. Deliberately never re-runs compinit: a re-run reads the
        # stale dump (new dirs wouldn't register) and drops runtime
        # compdefs (functions.zsh's git_dbranch, zsh-abbr). fpath only
        # grows within a session — store paths are read-only and eternal,
        # so stale entries are harmless. Cost only on actual PATH change.
        typeset -g  __ds_path_cache=""
        typeset -ga __ds_seen=()
        _devshell_completion_sync() {
          [[ "$PATH" == "$__ds_path_cache" ]] && return
          __ds_path_cache="$PATH"
          (( $+functions[compdef] )) || return   # headless shell: compinit never ran
          local p d f line
          local -a words
          for p in ''${(s.:.)PATH}; do
            [[ "$p" == /nix/store/*/bin ]] || continue
            d="''${p%/bin}/share/zsh/site-functions"
            [[ -d "$d" ]] || continue
            (( ''${__ds_seen[(Ie)$d]} )) && continue
            __ds_seen+=("$d")
            fpath=("$d" "''${fpath[@]}")
            for f in "$d"/_*(N); do
              IFS= read -r line < "$f" || continue
              [[ "$line" == '#compdef '* ]] || continue
              words=(''${=line#\#compdef })
              [[ "''${words[1]}" == -* ]] && continue  # skip -P/-k directives
              autoload -Uz "''${f:t}"
              compdef "''${f:t}" "''${words[@]}"
            done
          done
        }
        autoload -Uz add-zsh-hook
        add-zsh-hook precmd _devshell_completion_sync
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
      "--height 75%"
      "--multi"
      "--reverse"
      "--margin=0,1"
      "--marker=+"
      "--pointer=▶"
      "--prompt=❯ "
      "--no-separator"
    ];
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;

    # ESO-for-dev: the cluster syncs secrets via external-secrets-operator +
    # 1Password Connect; this is the laptop-side mirror. Repos commit an
    # .env.tpl of op:// references (never values) and call `use_onepassword`
    # from .envrc — entering the repo materializes them as env vars.
    # Requires the 1Password app's "Integrate with CLI" toggle for biometrics.
    # TODO i like this but think we need to move this to a template that gets
    #read we might want to create a lightweight direnv hooks utils system we can use
    # and big inline strings are ugly

    stdlib = ''
      # use_onepassword [template] — render op:// refs into exported env.
      # Degrades to a warning (never a broken shell) when op is missing,
      # signed out, or the template is absent.
      use_onepassword() {
        local tpl="''${1:-.env.tpl}"
        if [[ ! -f "$tpl" ]]; then
          log_error "use_onepassword: no $tpl in $PWD — skipping"
          return 0
        fi
        watch_file "$tpl"
        if ! has op; then
          log_error "use_onepassword: op CLI not on PATH — secrets NOT loaded"
          return 0
        fi
        # render to a real temp file: dotenv <(…) loses the fd before
        # direnv's binary opens it and silently loads nothing (mktemp is
        # 0600; secrets touch disk only for the ms between render and rm)
        local tmp
        tmp="$(mktemp -t op-env.XXXXXXXX)"
        # >/dev/null: op prints the -o path to stdout. And do NOT use the
        # stdlib dotenv() here — it watch_files its input; watching a
        # deleted temp file makes direnv reload on EVERY prompt. The
        # template (watched above) is the only correct reload trigger.
        if op inject -f -i "$tpl" -o "$tmp" >/dev/null 2>"$tmp.err"; then
          eval "$("''${direnv:-direnv}" dotenv bash "$tmp")"
          log_status "1password: loaded $(grep -c '^[A-Za-z_][A-Za-z0-9_]*=' "$tmp") secret(s) from $tpl"
        else
          log_error "use_onepassword: op inject failed: $(head -1 "$tmp.err" 2>/dev/null) — secrets NOT loaded"
        fi
        rm -f "$tmp" "$tmp.err"
      }
    '';
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
