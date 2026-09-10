#!/usr/bin/env bash
# PARKED — not wired in dotfiles/claude/settings.json. Depends on
# memory-service + beads + codebase-memory-mcp from the old hdaniels setup.
# Wire as SessionStart(matcher: compact) once those return; else delete.
# Runs as SessionStart hook with matcher "compact"
# Re-injects persistent context after compaction so the agent can recover

echo "# Post-Compaction Context Recovery"
echo ""
echo "Context was just compacted. To recover session state:"
echo "1. Use memory_search with keywords related to your current task to recall relevant decisions"
echo "2. Check beads for active issues (bd prime already ran)"
echo "3. Re-read any files you were actively editing before compaction"
echo ""

# Show codebase graph status
echo "## Indexed Codebases"
codebase-memory-mcp list-projects 2>/dev/null | head -10 || echo "codebase-memory: unavailable"
