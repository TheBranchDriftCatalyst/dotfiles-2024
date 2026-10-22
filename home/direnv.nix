# direnv — per-repo environments, plus the laptop half of the secrets story.
#
# Lives apart from zsh.nix because direnv itself isn't zsh: .envrc evaluates
# in bash, and its helper library (./direnv/lib/onepassword.sh) wants to be a
# real bash file — IDE-highlighted, shellcheck'd, testable — rather than a
# nix string. The zsh-side conveniences (op_cleanup/op_rotate, the
# _direnv_hook noise filter) are real files too, ./direnv/zsh-hooks.zsh, for
# the editor/zsh -n half of that same contract even though shellcheck itself
# can't read zsh.
{ config, lib, ... }:

let
  p = config.catalyst.palette;

  # #rrggbb → the r;g;b of an ANSI truecolor SGR. The hooks print in the
  # machine's LIVERY, same source as LS_COLORS and starship, so the box you
  # are on is readable from the secret lines too.
  rgb =
    hex:
    let
      c = i: toString (lib.fromHexString (builtins.substring i 2 hex));
    in
    "${c 1};${c 3};${c 5}";

  # Prepended to the installed copy rather than interpolated into the repo
  # file: ./direnv/lib/onepassword.sh stays pure bash that an editor,
  # shellcheck, and test/direnv/run.sh can all read unmodified — this is the
  # whole contract between the two halves.
  livery = ''
    # ── palette, rendered from catalyst.palette at build time ──────────────
    _OP_OK=$'\033[38;2;${rgb p.glow}m'     # sigil, success
    _OP_BAD=$'\033[38;2;${rgb "#f82a5d"}m' # sigil, failure (ghostty ANSI red)
    _OP_SUBJ=$'\033[38;2;${rgb p.accent}m' # the template being acted on
    _OP_NUM=$'\033[38;2;${rgb p.sunTop}m'  # counts, modes
    _OP_DIM=$'\033[2m'
    _OP_OFF=$'\033[0m'

  '';
in

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
  #
  # `.text`, not `.source`: the installed copy gets the palette-derived
  # colour codes prepended ahead of the repo file's own content.
  xdg.configFile."direnv/lib/onepassword.sh".text = livery + builtins.readFile ./direnv/lib/onepassword.sh;

  # op_cleanup/op_rotate + the _direnv_hook noise filter: a real file
  # (./direnv/zsh-hooks.zsh), not a nix string — shellcheck has no zsh
  # dialect, but an editor and `zsh -n` can still read it directly, and it's
  # free of nix's ''${...} interpolation-escaping noise.
  programs.zsh.initContent = lib.mkAfter ''
    source ${./direnv/zsh-hooks.zsh}
  '';
}
