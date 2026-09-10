#!/usr/bin/env bash
# PARKED — not wired in dotfiles/claude/settings.json. The recovery
# instructions it emits assume the memory-service + beads MCP servers from the
# old hdaniels setup. Wire as PreCompact hook once those return; if they never
# do, delete this.
# Pre-compaction context preservation
# Reads the session transcript from stdin JSON and extracts key state
# This output gets included in the context BEFORE compaction summarizes it
# so the compacted summary retains critical session knowledge

INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')

echo "# SESSION STATE SNAPSHOT (pre-compaction)"
echo ""

# Extract what files were modified this session
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  # Files edited/written
  EDITED_FILES=$(grep -o '"file_path":"[^"]*"' "$TRANSCRIPT_PATH" 2>/dev/null | sort -u | sed 's/"file_path":"//;s/"//' | head -20)
  if [ -n "$EDITED_FILES" ]; then
    echo "## Files touched this session:"
    echo "$EDITED_FILES" | while read -r f; do echo "- $f"; done
    echo ""
  fi

  # Git commits made
  COMMITS=$(grep -o 'git commit[^"]*' "$TRANSCRIPT_PATH" 2>/dev/null | head -10)
  if [ -n "$COMMITS" ]; then
    echo "## Commits made:"
    echo "$COMMITS" | while read -r c; do echo "- $c"; done
    echo ""
  fi

  # Errors encountered (look for common error patterns)
  ERRORS=$(grep -oE '"(Error|error|FAIL|BLOCKED|failed)[^"]{0,200}"' "$TRANSCRIPT_PATH" 2>/dev/null | head -5)
  if [ -n "$ERRORS" ]; then
    echo "## Errors/issues encountered:"
    echo "$ERRORS" | while read -r e; do echo "- $e"; done
    echo ""
  fi
fi

# Current git state
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
if [ -n "$CWD" ] && [ -d "$CWD/.git" ]; then
  echo "## Git state ($CWD):"
  BRANCH=$(git -C "$CWD" symbolic-ref --short HEAD 2>/dev/null)
  echo "- Branch: ${BRANCH:-detached}"
  DIRTY=$(git -C "$CWD" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  echo "- Uncommitted changes: $DIRTY files"
  LAST_COMMIT=$(git -C "$CWD" log --oneline -1 2>/dev/null)
  echo "- Last commit: $LAST_COMMIT"
  echo ""
fi

echo "## Post-compaction recovery instructions:"
echo "- Use memory_search to recall decisions and context for the current task"
echo "- Check beads for active issues (bd ready, bd stats)"
echo "- Re-read any files listed above that you were actively editing"
