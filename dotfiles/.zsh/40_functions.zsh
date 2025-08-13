# 🔍 Enhanced File Finder with fuzzy search and preview
ffind() {
    rg --files | fzf \
        --preview 'bat --style=numbers --color=always {}' \
        --preview-window=right:70% \
        --query="$1" \
        --header="📁 Find Files"
}

# 🗑️ Smart Git Branch Deletion (local + remote)
git_dbranch() {
    if [[ -z "$1" ]]; then
        echo "❌ Usage: git_dbranch <branch_name>"
        return 1
    fi

    local branch="$1"
    local deleted_any=false

    # Check if we're in a git repo
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ Not in a git repository"
        return 1
    fi

    # Prevent deletion of current branch
    local current_branch=$(git branch --show-current)
    if [[ "$branch" == "$current_branch" ]]; then
        echo "❌ Cannot delete current branch: $branch"
        return 1
    fi

    # Delete local branch
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

    # Delete remote branch
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

# Autocomplete for git_dbranch
_git_dbranch_autocomplete() {
    local branches
    branches=($(git for-each-ref --format="%(refname:short)" refs/heads/ 2>/dev/null | grep -v "^origin/"))
    _values "branches" "${branches[@]}"
}

compdef _git_dbranch_autocomplete git_dbranch

# 🔎 Smart Text Search with preview
tfind() {
    local search_path="${1:-.}"  # Default to current directory
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

# 📜 Enhanced Git Log Search
glog() {
    git log --oneline --decorate --color=always --no-merges | \
    fzf --ansi \
        --query="$1" \
        --header="📜 Git Log Search" \
        --preview 'echo {} | grep -o "^[a-f0-9]\+" | xargs -I {} git show --color=always {} | bat --style=full --color=always --language=diff' \
        --preview-window=right:70%
}

# 🕵️ Comprehensive Git Search (logs, files, content)
git_search() {
    # Check if we're in a git repo
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ Not in a git repository"
        return 1
    fi

    local selection
    selection=$( (
        # Recent commits
        git log --pretty=format:'[COMMIT] %C(yellow)%h %C(magenta)%ad %C(cyan)%s' --date=short -20
        
        # Recently added files
        git log --diff-filter=A --name-only --pretty=format:'%C(black)%C(bold)' -10 | \
            sed '/^$/d' | sed 's/^/[ADDED] /'
        
        # Recently deleted files  
        git log --diff-filter=D --name-only --pretty=format:'%C(black)%C(bold)' -10 | \
            sed '/^$/d' | sed 's/^/[DELETED] /'
        
        # Current files
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

    # Exit if nothing selected
    [[ -z "$selection" ]] && return

    # Extract type and value
    local type=$(echo "$selection" | awk '{print $1}')
    local value=$(echo "$selection" | cut -d' ' -f2)

    # Return appropriate result
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
