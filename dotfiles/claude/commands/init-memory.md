---
description: Initialize all 3 memory layers (semantic search, code graph + ADR, agent memory) for a project
argument-hint: [path] [--force]
allowed-tools: ["mcp__claude-context__index_codebase", "mcp__claude-context__get_indexing_status", "mcp__codebase-memory__index_repository", "mcp__codebase-memory__index_status", "mcp__codebase-memory__list_projects", "mcp__codebase-memory__get_architecture", "mcp__codebase-memory__manage_adr", "mcp__codebase-memory__query_graph", "mcp__memory-service__memory_health", "mcp__memory-service__memory_stats", "mcp__memory-service__memory_store", "mcp__memory-service__memory_list", "Read", "Glob", "Grep", "Bash"]
model: claude-sonnet-4-5-20250929
---

# Initialize All Memory Layers

Initialize the full 3-layer memory architecture for a project. Target path is `$1` (defaults to the current working directory if not provided).

If `--force` appears in the arguments, re-index even if already indexed.

## Phase 1: Pre-flight Status Check

Run these calls in parallel to assess current state:

1. `get_indexing_status` for the target path
2. `index_status` for the project
3. `list_projects` to see what's already indexed
4. `memory_health` to verify Layer 3 is operational

Present a brief pre-flight summary showing what needs initialization.

## Phase 2: Layer 2 — Code Graph (codebase-memory)

This layer must be initialized FIRST because it produces architecture data used by later steps.

1. Call `index_repository` with the target path
   - Use `force: true` if `--force` was specified or if the index is stale (>24h old)
2. Wait for indexing to complete
3. Call `get_architecture` with aspects `["languages", "packages", "routes", "patterns"]`
4. Call `manage_adr` with action `generate` to create/update the Architecture Decision Record
   - This captures languages, frameworks, patterns, and structural decisions

Report: node count, edge count, top languages, and whether ADR was created.

## Phase 3: Layer 1 — Semantic Search (claude-context)

1. Call `index_codebase` with the target path
   - Use `force: true` if `--force` was specified
2. Check `get_indexing_status` to confirm indexing has started
   - Note: This runs in the background using OpenAI embeddings. It may take several minutes for large codebases.

Report: indexing status (started/already running/complete).

## Phase 4: Layer 3 — Agent Memory (memory-service)

1. Confirm `memory_health` is healthy (from Phase 1 results)
2. Using the architecture data gathered in Phase 2, store foundational project memories:

   Store **one memory per category** below. Before storing, check `memory_list` to avoid duplicating existing memories about this project.

   **a) Project Overview** (tags: `project-overview`, `architecture`, `<project-name>`)
   - Project name, path, primary purpose
   - Main languages and frameworks (from get_architecture)
   - Repo structure summary (top-level directories and their purpose)

   **b) Tech Stack & Dependencies** (tags: `dependencies`, `tech-stack`, `<project-name>`)
   - Key dependencies and their versions (from package.json, pyproject.toml, go.mod, etc.)
   - Build tools, task runners, package managers
   - Runtime requirements

   **c) Development Patterns** (tags: `patterns`, `conventions`, `<project-name>`)
   - Code organization patterns detected (from architecture analysis)
   - Testing frameworks and conventions
   - Notable architectural patterns (monorepo, microservices, etc.)

   Skip any category if a substantially similar memory already exists.

3. Store each memory with `memory_type: "reference"` and appropriate tags.

Report: number of memories stored, total memory count.

## Phase 5: Final Report

Present a unified initialization summary:

```
## Memory Initialization Complete

### Layer 1: Semantic Search (claude-context)
- Status: Indexing in background / Complete
- Path: /path/to/project

### Layer 2: Code Graph (codebase-memory)
- Nodes: N | Edges: N
- Languages: lang1, lang2, ...
- ADR: Created / Updated / Already exists
- Index time: Ns

### Layer 3: Agent Memory (memory-service)
- Health: healthy
- Memories stored: N new (M total)
- Categories: overview, tech-stack, patterns

### Next Steps
- Run `/memory-status` to check indexing progress
- Use `search_code` for semantic search (after indexing completes)
- Use `search_graph` or `query_graph` for structural queries
- Use `retrieve_memory` to recall stored context
```

## Rules

- Always index Layer 2 first — its output feeds Layer 3
- Never duplicate existing memories — check before storing
- Use the project's directory name as the project identifier in tags
- If any layer fails, continue with the remaining layers and report the failure
- Keep memories concise — max 500 chars each, focus on facts not prose
- Do NOT store sensitive data (API keys, passwords, secrets) in memories
