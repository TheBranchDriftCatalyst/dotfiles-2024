# ─────────────────────────────────────────────────────────────────────────────
# functions.zsh :: fzf-powered search tools — sourced (ACTIVE) by home/zsh.nix
#
# All deps (rg, fzf, bat, git) are in home/packages.nix. compinit has already
# run by the time this is sourced (programs.zsh.enableCompletion emits it
# before initContent), so the compdef below is safe.
# ─────────────────────────────────────────────────────────────────────────────

# ── ffind: fuzzy file finder with preview ─────────────────────────────────
# note: `ffind [query]` — rg file list → fzf → bat preview.
ffind() {
    rg --files | fzf \
        --preview 'bat --style=numbers --color=always {}' \
        --preview-window=right:70% \
        --query="$1" \
        --header="📁 Find Files"
}

# ── tfind: fuzzy content search with context preview ──────────────────────
# note: `tfind [path] <term>` — word-regexp rg → fzf, ±10-line bat preview.
tfind() {
    local search_path="${1:-.}"
    local search_term="$2"
    if [[ -z "$search_term" ]]; then
        echo "❌ Usage: tfind [path] <search_term>"
        echo "   Example: tfind . 'function'"
        return 1
    fi
    rg --column --line-number --with-filename --no-heading --color=always \
        --case-sensitive --word-regexp \
        --glob '!**/{.git,node_modules,target,build,dist}/**' \
        --glob '!**/{yarn.lock,package-lock.json,Cargo.lock}' \
        "$search_term" "$search_path" | \
    fzf --ansi \
        --header="🔍 Text Search Results" \
        --preview 'echo {} | awk -F: '\''
            {
                file=$1; line=$2;
                start=line-10; if(start<0) start=1;
                end=line+10;
                cmd="bat --style=numbers --color=always --decorations=always --line-range "start":"end" --highlight-line "line" \""file"\"";
                system(cmd)
            }'\'''
}

# ── glog: fuzzy git log browser ───────────────────────────────────────────
# note: `glog [query]` — oneline log → fzf → full diff preview via bat.
glog() {
    git log --oneline --decorate --color=always --no-merges | \
    fzf --ansi \
        --query="$1" \
        --header="📜 Git Log Search" \
        --preview 'echo {} | grep -o "^[a-f0-9]\+" | xargs -I {} git show --color=always {} | bat --style=full --color=always --language=diff' \
        --preview-window=right:70%
}

# ── git_dbranch: delete a branch locally AND on origin, with guardrails ───
# note: `git_dbranch <branch>` — refuses current branch, reports each step.
git_dbranch() {
    if [[ -z "$1" ]]; then
        echo "❌ Usage: git_dbranch <branch_name>"
        return 1
    fi
    local branch="$1"
    local deleted_any=false
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ Not in a git repository"
        return 1
    fi
    local current_branch=$(git branch --show-current)
    if [[ "$branch" == "$current_branch" ]]; then
        echo "❌ Cannot delete current branch: $branch"
        return 1
    fi
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        if git branch -d "$branch" 2>/dev/null || git branch -D "$branch" 2>/dev/null; then
            echo "✅ Deleted local branch: $branch"
            deleted_any=true
        else
            echo "❌ Failed to delete local branch: $branch"
        fi
    else
        echo "ℹ️  Local branch '$branch' does not exist"
    fi
    if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
        if git push origin --delete "$branch" 2>/dev/null; then
            echo "✅ Deleted remote branch: $branch"
            deleted_any=true
        else
            echo "❌ Failed to delete remote branch: $branch"
        fi
    else
        echo "ℹ️  Remote branch '$branch' does not exist"
    fi
    [[ "$deleted_any" == true ]] && echo "🎉 Branch cleanup complete!"
}
_git_dbranch_autocomplete() {
    local branches
    branches=($(git for-each-ref --format="%(refname:short)" refs/heads/ 2>/dev/null | grep -v "^origin/"))
    _values "branches" "${branches[@]}"
}
# guarded: compdef only exists once compinit has run (it can abort headless)
(( $+functions[compdef] )) && compdef _git_dbranch_autocomplete git_dbranch

# ── git_search: unified commits/files/added/deleted picker ────────────────
# note: `git_search` — one fzf over recent commits, current files, and
#       recently added/deleted paths, typed previews for each.
git_search() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ Not in a git repository"
        return 1
    fi
    local selection
    selection=$( (
        git log --pretty=format:'[COMMIT] %C(yellow)%h %C(magenta)%ad %C(cyan)%s' --date=short -20
        git log --diff-filter=A --name-only --pretty=format:'%C(black)%C(bold)' -10 | \
            sed '/^$/d' | sed 's/^/[ADDED] /'
        git log --diff-filter=D --name-only --pretty=format:'%C(black)%C(bold)' -10 | \
            sed '/^$/d' | sed 's/^/[DELETED] /'
        git ls-tree -r HEAD --name-only | sed 's/^/[FILE] /'
    ) | fzf --ansi \
        --height=80% \
        --reverse \
        --prompt="🔍 Git Search > " \
        --header="📝 COMMITS | 📁 FILES | ➕ ADDED | ➖ DELETED" \
        --preview='
            type=$(echo {} | awk "{print \$1}");
            value=$(echo {} | cut -d" " -f2);
            case $type in
                "[COMMIT]")
                    git show --stat --color=always "$value" | head -50
                    ;;
                "[FILE]"|"[ADDED]"|"[DELETED]")
                    echo "📄 File: $value"
                    echo "📅 Last modified:"
                    git log -n 3 --pretty=format:"%h %ad %s" --date=short -- "$value"
                    echo ""
                    echo "📝 Content preview:"
                    if git cat-file -e HEAD:"$value" 2>/dev/null; then
                        git show HEAD:"$value" | bat --color=always --style=numbers -l auto
                    else
                        echo "File not found in current HEAD"
                    fi
                    ;;
            esac
        ' \
        --preview-window=right:60% \
        --bind="ctrl-d:preview-page-down,ctrl-u:preview-page-up"
    )
    [[ -z "$selection" ]] && return
    local type=$(echo "$selection" | awk '{print $1}')
    local value=$(echo "$selection" | cut -d' ' -f2)
    case "$type" in
        "[COMMIT]")
            echo "📝 Selected commit: $value"
            git show "$value"
            ;;
        "[FILE]"|"[ADDED]"|"[DELETED]")
            echo "📁 Selected file: $value"
            local commit_hash=$(git log -n 1 --pretty=format:"%h" -- "$value")
            echo "🔗 Latest commit: $commit_hash"
            ;;
    esac
}
