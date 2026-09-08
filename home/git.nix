# git — replaces dotfiles/.gitconfig.
#
# The old file carried a plaintext PAT in a url.insteadOf rewrite and an
# employer email on a personal machine. Neither belongs in a public repo:
# identity is split by directory below, and credentials go through the
# system keychain / gh, never a config file.
{ pkgs, lib, config, ... }:

{
  programs.git = {
    enable = true;
    lfs.enable = true;

    userName = "DJ Daniels";
    userEmail = "djdanielsh@gmail.com";

    # Work identity applies only inside the work tree — no global override,
    # so a personal repo can never be committed with the employer address.
    includes = [{
      condition = "gitdir:~/catalyst-devspace/";
      contents.user.email = "h.daniels@protecht.com";
    }];

    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "OneHalfDark";
      };
    };

    ignores = [
      ".DS_Store"
      "*.swp"
      ".direnv/"
      "**/.claude/settings.local.json"
    ];

    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      fetch.prune = true;
      diff.colorMoved = "default";
      merge.conflictStyle = "zdiff3";
      rerere.enabled = true;
      # ssh rewriting is fine; token rewriting is not.
      url."ssh://git@github.com/".insteadOf = "https://github.com/";
    };
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
    extensions = with pkgs; [ gh-dash ];
  };
}
