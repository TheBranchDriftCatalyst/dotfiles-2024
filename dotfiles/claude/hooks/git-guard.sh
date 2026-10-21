#!/usr/bin/env bash
# Git safety guard — blocks destructive git commands and enforces commit policy
# Reads PreToolUse JSON from stdin (matcher: Bash)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | /usr/bin/jq -r '.tool_input.command // ""' 2>/dev/null)

# Fallback: if jq failed, COMMAND may be empty — skip checks
if [ -z "$COMMAND" ]; then
  exit 0
fi

# --- Block destructive git operations ---
# Allow --force-with-lease (safe force push) — only block bare --force
if echo "$COMMAND" | grep -qF -- '--force-with-lease'; then
  : # safe, skip force-push checks
elif echo "$COMMAND" | grep -qiE 'git push.*--force|push --force'; then
  echo "BLOCKED: Destructive git command detected ('force push'). Ask the user for explicit confirmation before running this command." >&2
  exit 2
fi

DANGEROUS_PATTERNS=(
  "git reset --hard"
  "reset --hard"
  "git clean -f"
  "git clean -fd"
  "git branch -D"
  "git checkout \."
  "git restore \."
  "git stash drop"
  "git stash clear"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCKED: Destructive git command detected ('$pattern'). Ask the user for explicit confirmation before running this command." >&2
    exit 2
  fi
done

# --- Enforce commit message policy ---
if echo "$COMMAND" | grep -qE 'git commit'; then
  # Extract only the commit message (-m argument), not paths or cd commands
  COMMIT_MSG=$(echo "$COMMAND" | grep -oP '(?<=-m\s["\x27]).*?(?=["\x27])' 2>/dev/null ||
    echo "$COMMAND" | sed -n 's/.*-m[[:space:]]*"\([^"]*\)".*/\1/p' 2>/dev/null)

  # -F/--file: read the actual message out of the file.
  #
  # This is the common case for a long message, and the old fallback got it badly wrong:
  # it scanned the WHOLE command string, paths included, so a message file living under a
  # path containing "claude" — which every Claude Code scratchpad does — was blocked for
  # "mentioning Claude" while the message itself was never looked at.
  if [ -z "$COMMIT_MSG" ]; then
    MSG_FILE=$(echo "$COMMAND" |
      grep -oE -- '(-F|--file)[[:space:]]*=?[[:space:]]*[^[:space:]]+' |
      head -1 |
      sed -E 's/^(-F|--file)[[:space:]]*=?[[:space:]]*//' |
      tr -d '"'\''')
    if [ -n "$MSG_FILE" ] && [ -r "$MSG_FILE" ]; then
      COMMIT_MSG=$(cat "$MSG_FILE")
    fi
  fi

  # Still nothing means an editor-driven commit, --amend --no-edit, or a heredoc on stdin:
  # the message is NOT on the command line, so there is nothing here to inspect. Scanning
  # the command string instead is exactly what produced the false positives on file paths,
  # and a missed check is better than blocking a correct commit over a word in a directory
  # name. A commit-msg hook is the right place to catch those.

  # Check for Co-Authored-By in the commit message
  if echo "$COMMIT_MSG" | grep -qi 'co-authored-by'; then
    echo "BLOCKED: Do not add Co-Authored-By lines to commit messages." >&2
    exit 2
  fi
  # Check for AI attribution in the commit message. The comment has always said
  # "not paths", but the check did not honour it: with `-F` there is no -m to
  # extract, so COMMIT_MSG falls back to the whole command line, and ANY path
  # containing the word matched. A commit touching home/claude.nix, or writing
  # the message to a file under a ~/.claude-... scratch dir, was refused for
  # naming its own files. Strip path-shaped tokens (anything containing a /)
  # before the word check — prose attribution never hides inside a path, so
  # intent is preserved and the false positives go away.
  COMMIT_MSG_PROSE=$(echo "$COMMIT_MSG" | tr '[:space:]' '\n' | grep -v '/' | tr '\n' ' ')
  if echo "$COMMIT_MSG_PROSE" | grep -qiE 'claude|anthropic|ai.generated|ai.assisted'; then
    echo "BLOCKED: Do not mention Claude, Anthropic, or AI in commit messages." >&2
    exit 2
  fi
  # Reminder (non-blocking)
  echo "COMMIT POLICY: Write commit messages as if the developer wrote them. No AI attribution, no Co-Authored-By."
fi

exit 0
