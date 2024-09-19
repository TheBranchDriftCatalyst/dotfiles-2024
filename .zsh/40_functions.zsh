# find file
ffind() {
    rg --files | fzf --preview 'bat --style=numbers --color=always {}' --preview-window=right:70% --query="$1"
}

# Find text in a files
tfind() {
    local search_path=$1
    rg --column --line-number --with-filename --no-heading --color=always \
        --case-sensitive --word-regexp \
        --glob '!**/(.git|node_modules)/**' --glob '!**/(yarn\.lock)' \
        "$2" "$search_path" | fzf --ansi \
        --preview 'echo {} | awk -F: '\''{start=$2-10; if(start<0) start=0; end=$2+10; print "--style=numbers --color=always --decorations=always --line-range "start":"end" --highlight-line "$2" "$1}'\'' | xargs bat'
}


gcf() {
  # Build the list of refs
  local refs=$( (
    git for-each-ref --format='[local] %(refname:short)' refs/heads/
    git for-each-ref --format='[remote] %(refname:short)' refs/remotes/
    git stash list --format='[stash] %gd: %gs'
  ) | fzf --height 40% --reverse --prompt="Select source> " \
       --preview='
         ref=$(echo {} | sed "s/^\[[^]]*\] \([^:]*\).*/\1/");
         git diff --name-only HEAD..."$ref"')

  [ -z "$refs" ] && return

  # Extract the ref name
  local ref=$(echo "$refs" | sed 's/^\[[^]]*\] \([^:]*\).*/\1/')

  # Export ref for use in the preview command
  export FZF_PREVIEW_REF="$ref"

  # Get the list of files in the ref
  local file=$(git ls-tree -r --name-only "$ref" | fzf --height 40% --reverse --prompt="Select file> " \
      --preview='
        git show "$FZF_PREVIEW_REF":"{}" | bat --style=numbers --color=always --pager=never')

  [ -z "$file" ] && return

  git checkout "$ref" -- "$file"
}

gcb() {
  # Build the list of local and remote branches
  local branches=$( (
    git for-each-ref --format='[local] %(refname:short):%(refname)' refs/heads/
    git for-each-ref --format='[remote] %(refname:lstrip=3):%(refname)' refs/remotes/
  ) )

  # Use fzf to select a branch
  local selection=$(echo "$branches" | fzf --height 40% --reverse --prompt="Select branch> " \
    --with-nth=1 \
    --delimiter=":" \
    --preview='
      ref=$(echo {} | awk -F ":" "{print \$2}");
      git_log=$(git log --color=always --oneline --graph --decorate HEAD.."$ref");
      if [ -z "$git_log" ]; then
        echo "No differences between HEAD and $(git rev-parse --abbrev-ref "$ref")";
      else
        echo "$git_log" | bat --style=plain --color=always --pager=never;
      fi
    ')

  [ -z "$selection" ] && return

  # Extract the full refname
  local ref=$(echo "$selection" | awk -F ":" '{print $2}')

  # Check if it's a remote branch and needs tracking
  if echo "$selection" | grep -q '^\[remote\]'; then
    git checkout --track "${ref#refs/remotes/}"
  else
    git checkout "${ref#refs/heads/}"
  fi
}

dexec() {
  # List running containers and select one
  local container
  container=$(docker ps --format '{{.Names}}' | fzf --height 40% --reverse --border --prompt='Select container: ')
  [ -z "$container" ] && return 1  # Exit if no container selected

  # Attempt to detect the shell in the container
  local shell
  if docker exec "$container" sh -c 'command -v bash' &>/dev/null; then
    shell='bash'
  elif docker exec "$container" sh -c 'command -v sh' &>/dev/null; then
    shell='sh'
  elif docker exec "$container" sh -c 'command -v ash' &>/dev/null; then
    shell='ash'
  else
    echo "No common shell found in container '$container'."
    return 1
  fi

  # Execute the shell in the container
  docker exec -it "$container" "$shell"
}

function glog() {
  git log --pretty=format:"%C(auto)%h %s" --no-merges |
  fzf --query="$1" --preview 'echo {} | grep -o "^[a-f0-9]\+" | xargs git show --color=always | bat --style=full --paging=always --color=always'
}

git_search() {
  # Step 1: Build a list of logs, files, and file contents
  local selections=$(
    (
      git log --pretty=format:'[log] %h %s' --date=short
      git ls-tree -r HEAD --name-only | sed 's/^/[file] /'
      git grep -I --name-only '' | sed 's/^/[content] /'
    ) | fzf --height 40% --reverse --prompt="Select source> " \
       --preview='
         type=$(echo {} | awk "{print \$1}");
         value=$(echo {} | awk "{print \$2}");

         if [ "$type" = "[log]" ]; then
           git show --name-only "$value";
         elif [ "$type" = "[file]" ] || [ "$type" = "[content]" ]; then
           git log -n 1 --pretty=format:"%h %ad" --date=short -- "$value";
         fi'
  )

  [ -z "$selections" ] && return

  # Extract the type and value (either commit hash or filename)
  local type=$(echo "$selections" | awk '{print $1}')
  local value=$(echo "$selections" | awk '{print $2}')

  # Step 2: Handle the selection based on type
  if [ "$type" = "[log]" ]; then
    # Return commit hash
    echo "$value"
  elif [ "$type" = "[file]" ] || [ "$type" = "[content]" ]; then
    # Get the commit hash for the file or content
    local commit_hash=$(git log -n 1 --pretty=format:"%h" -- "$value")
    echo "$commit_hash"
  fi
}
