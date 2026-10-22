# direnv/zsh-hooks.zsh :: interactive-shell helpers for direnv + the
# 1Password library (home/direnv/lib/onepassword.sh) — sourced by
# programs.zsh.initContent (home/direnv.nix). A real file, not a nix string,
# so an editor and `zsh -n` can read it: shellcheck itself has no zsh
# dialect (bash/dash/ksh/sh only), so unlike onepassword.sh this doesn't get
# shellcheck — syntax-checked in test/direnv/run.sh instead.

# Renders in .direnv/op/ are keyed on a content watermark, so a secret
# rotated behind an unchanged input stays cached. This is the invalidation
# for that — run it after rotating anything. One pattern backs all three
# 1Password helpers (home/direnv/lib/onepassword.sh): in-folder cache files
# (use_onepassword's own .env) are wiped with the directory; out-of-folder
# rendered files (use_onepassword_tpl/_file's .npmrc, a materialized
# kubeconfig, …) are found via .manifest and removed too, so nothing a
# helper wrote survives a cleanup, wherever it landed.
op_cleanup() {
  local dir="${PWD}/.direnv/op"
  if [[ ! -d "$dir" ]]; then
    print -u2 "op_cleanup: nothing cached for this repo ($dir)"
    return 0
  fi
  local -a cached=("$dir"/*(ND)) # D: the entries are .env.tpl, .npmrc.tpl…
  local -a tracked=()
  [[ -f "$dir/.manifest" ]] && tracked=("${(@f)$(<"$dir/.manifest")}")
  local -i removed=0
  local f
  for f in "${tracked[@]}"; do
    [[ -n "$f" && -f "$f" ]] || continue
    rm -f -- "$f" && removed+=1
  done
  rm -rf -- "$dir" || return 1
  print -u2 "op_cleanup: cleared ${#cached} cache file(s) + $removed tracked output(s) from $dir"
  # No reload here, deliberately: direnv doesn't notice .direnv/op/ changing
  # on its own (it only re-evaluates on cd, a watched-file change, or an
  # explicit `direnv reload`/`direnv allow`), so a tracked output stays
  # GONE — not re-rendered — until you trigger that yourself.
}

# `use flake` makes direnv announce ~120 changed nix vars on every cd,
# burying the lines that say something. 2.37 has no DIRENV_LOG_FILTER and
# DIRENV_LOG_FORMAT is all-or-nothing, so filter its stderr here.
if (($+functions[_direnv_hook])); then
  functions[_direnv_hook_verbose]=$functions[_direnv_hook]
  _direnv_hook() {
    # This hook runs before prompt_starship_precmd, so its return value is
    # what the prompt reads as the last command's status. direnv's own
    # ends on `trap - SIGINT` and always hands over 0; pass the truth.
    local __st=$?
    local err="${TMPDIR:-/tmp}/direnv-stderr.$$" line
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
