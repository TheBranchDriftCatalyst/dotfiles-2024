#!/usr/bin/env bash
# PARKED — not wired in dotfiles/claude/settings.json. The briefing it demands
# calls memory_search + bd (beads) + codebase graph, none installed here yet.
# Wire as SessionStart hook once those return; else delete.
# Outputs a directive for the agent to produce a workstream briefing
# Runs on every SessionStart (startup, resume, compact)

cat <<'BRIEFING'
# WORKSTREAM BRIEFING REQUIRED

Your FIRST action before responding to the user MUST be to produce a workstream briefing.

Steps:
1. Call memory_search with query "recent decisions learnings progress" (n_results: 5)
2. Summarize beads status from the bd prime output above (open/blocked/ready issues)
3. Note indexed projects from the codebase graph output above

Output a concise briefing:

## Workstream Briefing
**Recent context:** [1-2 sentence summary per relevant memory, with relative timestamps]
**Active work (beads):** [open/blocked/ready issues]
**Indexed projects:** [list]

Then ask: What would you like to work on?

Rules:
- Keep it 10-15 lines max
- Skip sections with no data
- Use relative timestamps ("yesterday", "2 days ago")
- If the user already gave a task in their first message, skip the briefing and do the task
BRIEFING
