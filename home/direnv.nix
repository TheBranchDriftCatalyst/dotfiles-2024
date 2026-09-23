# direnv — per-repo environments, plus the laptop half of the secrets story.
#
# Lives apart from zsh.nix because none of it is zsh: direnv evaluates .envrc
# in bash, and its helper library is bash source that wants to be a real file
# (IDE-highlighted, shellcheck'd, and testable) rather than a nix string.
_:

{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    # stdlib (~/.config/direnv/direnvrc) is deliberately left empty. direnv
    # sources every ~/.config/direnv/lib/*.sh first, which is the extension
    # point that takes real files — see ./direnv/lib below.
  };

  # ── the direnv helper library ────────────────────────────────────────────
  # direnv sources these for EVERY .envrc evaluation, before direnvrc and
  # before the .envrc itself. Each file defines functions and prints nothing;
  # see the contract at the top of onepassword.sh. Tested by test/direnv/.
  xdg.configFile."direnv/lib/onepassword.sh".source = ./direnv/lib/onepassword.sh;
}
