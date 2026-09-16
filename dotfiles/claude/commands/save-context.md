---
description: Persist important decisions, discoveries, and learnings from this session to memory-service
allowed-tools:
  [
    'mcp__memory-service__memory_store',
    'mcp__memory-service__memory_search',
    'mcp__memory-service__memory_list',
  ]
---

# Save Session Context

Review the conversation so far and persist important learnings to memory-service.

## Steps

1. Scan the conversation for:
   - Decisions made (architecture, library choices, approach changes)
   - Bugs fixed or debugging insights (root causes, gotchas, workarounds)
   - Codebase patterns discovered (conventions, structure, relationships)
   - User preferences or workflow patterns expressed
   - Error resolutions (what failed, what fixed it)

2. For each item found, check `memory_search` to avoid duplicating existing memories.

3. Store each unique item via `memory_store`:
   - **content**: Concise, factual, under 500 chars. Lead with the key fact.
   - **memory_type**: `"reference"` for facts/patterns, `"decision"` for choices made, `"task_note"` for debugging insights
   - **tags**: Always include the project name + relevant topic tags (e.g., `["debugging", "auth", "talos-homelab"]`)

4. Report what was saved:

```
## Session Context Saved
- [type] brief description (tags: ...)
- [type] brief description (tags: ...)
Total: N new memories stored
```

## Rules

- If nothing noteworthy has happened, say so — don't store empty or trivial memories
- Don't store sensitive data (API keys, passwords, tokens)
- Don't duplicate memories that already exist — check first
- Keep each memory self-contained — it should make sense without conversation context
- Max 5 memories per save — consolidate related items
