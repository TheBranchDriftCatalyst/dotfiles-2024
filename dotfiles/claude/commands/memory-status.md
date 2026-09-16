---
description: Report status of all 3 memory architecture layers (semantic search, code graph, agent memory) with cleanup/dreaming recommendations
allowed-tools:
  [
    'mcp__memory-service__memory_health',
    'mcp__memory-service__memory_stats',
    'mcp__memory-service__memory_list',
    'mcp__memory-service__memory_search',
    'mcp__memory-service__memory_quality',
    'mcp__memory-service__memory_consolidate',
    'mcp__memory-service__memory_cleanup',
    'mcp__codebase-memory__index_status',
    'mcp__codebase-memory__get_architecture',
    'mcp__codebase-memory__list_projects',
    'mcp__codebase-memory__detect_changes',
    'mcp__claude-context__get_indexing_status',
  ]
model: haiku
---

# Memory Architecture Status Report

Run a full status check across all 3 memory layers and present a unified report. Call all tools in parallel where possible.

## Step 1: Gather Data (parallel calls)

Make these calls simultaneously:

1. **claude-context**: `get_indexing_status` for the current project directory
2. **codebase-memory**: `index_status` for the current project
3. **codebase-memory**: `get_architecture` with aspects `['languages', 'packages']`
4. **codebase-memory**: `list_projects` to show all indexed projects
5. **memory-service**: `memory_health`
6. **memory-service**: `memory_stats`
7. **memory-service**: `memory_list` with `page_size: 5` (most recent memories)

## Step 2: Present Report

Format as a unified status dashboard:

```
## Memory Architecture Status

### Layer 1: Semantic Search (claude-context)
| Metric | Value |
|--------|-------|
| Status | Ready / Indexing (N%) / Not Indexed |
| Path   | ... |

### Layer 2: Code Graph (codebase-memory)
| Metric | Value |
|--------|-------|
| Status       | ready / indexing / not found |
| Nodes        | N (functions, classes, modules) |
| Edges        | N (calls, imports, references) |
| Last indexed | ISO timestamp |
| Index type   | initial / incremental |
| Languages    | top languages from architecture |
| Top packages | top 5 packages by connectivity |

**All Indexed Projects:**
- project-name (N nodes, N edges, last indexed: ...)

### Layer 3: Agent Memory (memory-service)
| Metric | Value |
|--------|-------|
| Status          | healthy / degraded |
| Total memories  | N |
| DB size         | N MB |
| Embedding model | ... |
| Cache hit rate  | N% |
| Integrity       | healthy / N auto-repairs |

**Recent Memories (last 5):**
For each memory, show a compact summary:
- [type] **first 80 chars of content...** (tags: tag1, tag2) — created: relative time
```

## Step 3: Recommend Maintenance Actions

After the dashboard, append a **Maintenance** section that surfaces actionable cleanup / dreaming opportunities. Use the heuristics below — only list a recommendation when its threshold is hit.

### Layer 1 (claude-context) — Re-indexing

- **Stale index** (snapshot `lastUpdated` > 14 days old): suggest `index_codebase(force: true)`
- **Not indexed**: suggest `index_codebase(path)` for the current project
- **After major refactor / branch switch**: note that incremental updates are automatic, but `force: true` rebuilds embeddings if drift is suspected

### Layer 2 (codebase-memory) — Graph hygiene

- Call `detect_changes` if the index is older than 24h — surface number of changed files; suggest `index_repository` if non-zero
- **Orphaned projects**: any entries in `list_projects` with `nodes: 0` or empty `root_path` → suggest `delete_project(name)`
- **Duplicate-looking roots** (e.g. `~/foo` vs `~/foo/subdir`): flag as candidates for consolidation

### Layer 3 (memory-service) — Dreaming & cleanup

The memory service uses dream-inspired progressive consolidation: active → dormant → archived, with compression of older memories. Recommend on these thresholds:

| Condition                                         | Recommended action                                   | Tool                                          |
| ------------------------------------------------- | ---------------------------------------------------- | --------------------------------------------- |
| Total memories > 1000 and no consolidation in 7d  | Run weekly consolidation (compress dormant memories) | `memory_consolidate(time_horizon: "weekly")`  |
| Total memories > 5000                             | Run monthly consolidation (archive + compress)       | `memory_consolidate(time_horizon: "monthly")` |
| DB size > 50 MB                                   | Run cleanup pass (dedupe + archive)                  | `memory_cleanup`                              |
| Recent memories show duplicates / near-duplicates | Run dedupe                                           | `memory_cleanup(dedupe: true)`                |
| Quality score available and < 0.7                 | Run quality audit                                    | `memory_quality`                              |
| Daily heavy use (> 50 stores/day)                 | Run daily consolidation                              | `memory_consolidate(time_horizon: "daily")`   |
| Critical decisions in last 5 untagged             | Suggest tagging + `preserve` flag to resist decay    | `memory_update`                               |

**Dreaming cadence (best practice):**

- **Daily** (`time_horizon: "daily"`): light compression of yesterday's memories — keep cheap and frequent
- **Weekly** (`time_horizon: "weekly"`): merge similar memories within the week, promote critical ones
- **Monthly** (`time_horizon: "monthly"`): archive dormant memories, summarize themes, prune duplicates
- **On-demand**: after a long working session with many `memory_store` calls, run a daily consolidation before closing

**Cleanup best practices:**

- Always run `memory_health` before bulk operations — abort if integrity check fails
- Tag memories at write-time (`[project, type, topic]`) so consolidation can group semantically
- Use `memory_quality` quarterly to find low-signal memories worth deleting
- Mark `decision` and `gotcha` memories with `preserve: true` so consolidation doesn't compress them away
- Don't manually delete memories the service can decay — let dormant→archived flow handle it

## Rules

- Keep it concise — tables and bullet points only
- Flag anything unhealthy or missing with a warning prefix
- Show relative timestamps for recent memories (e.g., "2 hours ago", "yesterday")
- If any layer is not initialized, suggest the initialization command
- Do NOT explain what each layer does — the user knows
- Only show maintenance recommendations whose thresholds are actually hit — don't dump the full table every time
