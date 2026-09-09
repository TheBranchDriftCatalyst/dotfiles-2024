# git — replaces dotfiles/.gitconfig.
#
# The old file carried a plaintext PAT in a url.insteadOf rewrite and an
# employer email on a personal machine. Neither belongs in a public repo:
# identity is split by directory below, and credentials go through the
# system keychain / gh, never a config file.
{ pkgs, lib, config, ... }:

let id = config.catalyst.identity; in

{
  programs.git = {
    enable = true;
    lfs.enable = true;



    # The includeIf condition is what keeps identities separated per-repo;
    # the persona options only supply the VALUES. work.email = null turns
    # the split off entirely on single-identity machines.
    includes = lib.optional (id.work.email != null) {
      condition = "gitdir:${id.work.dir}";
      contents.user.email = id.work.email;
    };


    ignores = [
      ".DS_Store"
      "*.swp"
      ".direnv/"
      "**/.claude/settings.local.json"
    ];

    # HM renamed userName/userEmail/extraConfig into `settings`.
    settings = {
      user.name = id.name;
      user.email = id.email;   # persona-defined (home/theme.nix options)
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
