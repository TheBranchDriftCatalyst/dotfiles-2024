# fzf helper functions — salvaged verbatim from the retired afx config
# (fzf-cli.yaml snippet block) before deleting it. fzf itself, its key
# bindings, and FZF_* env are managed by programs.fzf in home/zsh.nix.

fzf_find_edit() {
  local file=$(
    fzf --query="$1" --no-multi --select-1 --exit-0 \
        --preview 'bat --color=always --line-range :500 {}'
    )
  if [[ -n $file ]]; then
    $EDITOR "$file"
  fi
}
fzf_git_add() {
  local selections=$(
    git status --porcelain | \
    fzf --ansi \
        --preview 'if (git ls-files --error-unmatch {2} &>/dev/null); then
                     git diff --color=always {2} | delta
                   else
                     bat --color=always --line-range :500 {2}
                   fi'
    )
  if [[ -n $selections ]]; then
    local files=$(echo "$selections" | cut -c 4- | tr '\n' ' ')
    git add --verbose $files
  fi
}
fzf_git_log() {
  local command='ll'
  if [[ "$1" == "all" ]]; then
    command='lla'
  fi
  shift # Consume the first argument of this function
  local selections=$(
    git $command --color=always "$@" |
      fzf --ansi --no-sort --no-height \
          --preview "echo {} | grep -o '[a-f0-9]\{7\}' | head -1 |
                     xargs -I@ sh -c 'git show --color=always @' |
                     delta"
    )
  if [[ -n $selections ]]; then
    local commits=$(echo "$selections" | sed 's/^[* |]*//' | awk '{print $1}' | tr '\n' ' ')
    git show $commits
  fi
}
fzf_git_unadd() {
  local files=$(git diff --name-only --cached | fzf --ansi)
  if [[ -n $files ]]; then
    git unadd $files
  fi
}
