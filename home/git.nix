# git — replaces dotfiles/.gitconfig.
#
# The old file carried a plaintext PAT in a url.insteadOf rewrite and an
# employer email on a personal machine. Neither belongs in a public repo:
# identity is split by directory below, and credentials go through the
# system keychain / gh, never a config file.
{ pkgs, lib, config, ... }:

let g = config.catalyst.git; in

{
  programs.git = {
    enable = true;
    lfs.enable = true;



    # One includeIf per declared context — identity follows the DIRECTORY,
    # never the machine. The mechanism is git's own conditional include;
    # contexts.nix only supplies the values.
    includes = lib.mapAttrsToList (_: c: {
      condition = "gitdir:${c.dir}";
      contents = { user.email = c.email; } // c.extraConfig;
    }) g.contexts;


    ignores = [
      ".DS_Store"
      "*.swp"
      ".direnv/"
      "**/.claude/settings.local.json"
    ];

    # HM renamed userName/userEmail/extraConfig into `settings`.
    settings = {
      user.name = g.name;
      user.email = g.email;   # base identity (home/contexts.nix)
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      fetch.prune = true;
      diff.colorMoved = "default";
      merge.conflictStyle = "zdiff3";
      rerere.enabled = true;
      help.autocorrect = 1;
      commit.template = "~/.gitmessage";

      # ported from the old .gitconfig — `unadd` is load-bearing
      # (fzf_git_unadd in dotfiles/.zsh/60_fzf.zsh calls it)
      alias = {
        st = "status";
        co = "checkout";
        ci = "commit";
        br = "switch";
        lo = "log --color=always --max-count=15 --oneline";
        ll = "lla --first-parent";
        lla = "log --graph --date=human --format='%C(#e3c78a)%h%C(#ff5454)%d%C(reset) - %C(#36c692)(%ad)%C(reset) %s %C(#80a0ff){%an}%C(reset)'";
        graph = "log --graph --date-order --all --pretty=format:'%h %Cred%d %Cgreen%ad %Cblue%cn %Creset%s' --date=short";
        unadd = "restore --staged";
        review = "diff origin/HEAD...";
        rvf = "diff origin/HEAD... --name-only";
        rvc = "log --oneline ...origin/HEAD";
        delete-merged-branches = "!git branch --merged | grep -v '\\*' | xargs -I % git branch -d %";
      };
      # ssh rewriting is fine; token rewriting is not.
      url."ssh://git@github.com/".insteadOf = "https://github.com/";
    };
  };

  # HM renamed programs.git.delta.* to a top-level module.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      syntax-theme = "OneHalfDark";
    };
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
    extensions = with pkgs; [ gh-dash ];
  };
}
