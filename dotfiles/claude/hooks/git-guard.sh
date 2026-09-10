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
if echo "$COMMAND" | grep -qE '\-\-force-with-lease'; then
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
  COMMIT_MSG=$(echo "$COMMAND" | grep -oP '(?<=-m\s["\x27]).*?(?=["\x27])' 2>/dev/null || \
               echo "$COMMAND" | sed -n 's/.*-m[[:space:]]*"\([^"]*\)".*/\1/p' 2>/dev/null)

  # If we couldn't extract the message, fall back to checking only the git commit portion
  if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG=$(echo "$COMMAND" | grep -o 'git commit.*')
  fi

  # Check for Co-Authored-By in the commit message
  if echo "$COMMIT_MSG" | grep -qi 'co-authored-by'; then
    echo "BLOCKED: Do not add Co-Authored-By lines to commit messages." >&2
    exit 2
  fi
  # Check for Claude/AI attribution in the commit message (not paths)
  if echo "$COMMIT_MSG" | grep -qiE 'claude|anthropic|ai.generated|ai.assisted'; then
    echo "BLOCKED: Do not mention Claude, Anthropic, or AI in commit messages." >&2
    exit 2
  fi
  # Reminder (non-blocking)
  echo "COMMIT POLICY: Write commit messages as if the developer wrote them. No AI attribution, no Co-Authored-By."
fi

exit 0
