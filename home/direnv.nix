# direnv — per-repo environments, plus the laptop half of the secrets story.
#
# Lives apart from zsh.nix because none of it is zsh: direnv evaluates .envrc
# in bash, and its helper library is bash source that wants to be a real file
# (IDE-highlighted, shellcheck'd, and testable) rather than a nix string.
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

  programs.zsh.initContent = lib.mkAfter ''
    # Renders in .direnv/op/ are keyed on template content, so a secret
    # rotated behind an unchanged template stays cached. This is the
    # invalidation for that — run it after rotating anything.
    op_cleanup() {
      local dir="''${PWD}/.direnv/op"
      if [[ ! -d "$dir" ]]; then
        print -u2 "op_cleanup: nothing cached for this repo ($dir)"
        return 0
      fi
      local -a cached=("$dir"/*(ND)) # D: the entries are .env.tpl, .npmrc.tpl…
      rm -rf -- "$dir" || return 1
      print -u2 "op_cleanup: cleared ''${#cached} file(s) from $dir"
      # rendered outputs are left alone — the reload overwrites each from a
      # fresh inject, so no tool ever finds its config file missing
      [[ -f .envrc ]] && direnv reload
    }

    # `use flake` makes direnv announce ~120 changed nix vars on every cd,
    # burying the lines that say something. 2.37 has no DIRENV_LOG_FILTER and
    # DIRENV_LOG_FORMAT is all-or-nothing, so filter its stderr here.
    if (( $+functions[_direnv_hook] )); then
      functions[_direnv_hook_verbose]=$functions[_direnv_hook]
      _direnv_hook() {
        # This hook runs before prompt_starship_precmd, so its return value is
        # what the prompt reads as the last command's status. direnv's own
        # ends on `trap - SIGINT` and always hands over 0; pass the truth.
        local __st=$?
        local err="''${TMPDIR:-/tmp}/direnv-stderr.$$" line
        # Redirection, not a pipe: the hook's job is to eval into THIS shell,
        # and a pipeline would subshell it and lose the environment.
        _direnv_hook_verbose 2>"$err"
        # zsh read, not grep: our log lines carry em-dashes and arrows, which
        # grep in a non-UTF-8 locale reports as "binary file matches" instead
        # of printing. Also saves a fork per prompt.
        if [[ -s "$err" ]]; then
          while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" == 'direnv: export '* ]] && continue
            print -ru2 -- "$line"
          done <"$err"
        fi
        rm -f -- "$err"
        return $__st
      }
    fi
  '';
}
