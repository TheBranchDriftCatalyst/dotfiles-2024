# Claude Code AI System Configuration

This document describes the AI-assisted development system, its memory architecture, configuration files, and how the components work together.

## System Architecture

The system uses a **three-layer memory architecture** for Claude Code, each serving a distinct purpose:

```
┌─────────────────────────────────────────────────────┐
│                  Claude Code Agent                   │
│                                                      │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │   claude-    │  │  codebase-   │  │   memory-   │ │
│  │   context    │  │   memory     │  │   service   │ │
│  │  (vectors)   │  │  (kg graph)  │  │  (agent mem)│ │
│  └──────┬──────┘  └──────┬───────┘  └──────┬──────┘ │
│         │                │                  │        │
│    Semantic         Structural         Persistent    │
│    Code Search      Code Graph         Agent Memory  │
│   (LanceDB +       (SQLite +          (SQLite-vec + │
│    OpenAI)          tree-sitter)       ONNX/local)   │
└─────────────────────────────────────────────────────┘
```

### Layer 1: Semantic Code Search (`claude-context`)

- **Purpose**: "Find code that does X" — natural language search across the codebase
- **Technology**: LanceDB vector DB + OpenAI `text-embedding-3-small` embeddings
- **How it works**: AST-based chunking splits code into semantic units, embeds them, and stores in LanceDB. Hybrid search combines BM25 full-text + dense vector with RRF reranking.
- **Data location**: `~/.context/` (LanceDB files + snapshot metadata)
- **Tools**: `index_codebase`, `search_code`, `clear_index`, `get_indexing_status`
- **Requires**: OpenAI API key (for embeddings)
- **Package**: `@dannyboy2042/claude-context-mcp` (npm, fork of zilliztech/claude-context)

### Layer 2: Structural Code Graph (`codebase-memory`)

- **Purpose**: "What calls this function?" — navigate code structure via knowledge graph
- **Technology**: tree-sitter parsing → SQLite knowledge graph with Cypher-like queries
- **How it works**: Parses source code into functions, classes, modules, and their relationships (CALLS, IMPORTS, REFERENCES). Persists across sessions. Incremental re-indexing on file changes.
- **Data location**: `~/.cache/codebase-memory-mcp/` (SQLite graph DB)
- **Tools**: `index_repository`, `search_graph`, `trace_call_path`, `query_graph`, `search_code`, `get_code_snippet`, `get_architecture`, `manage_adr`, `detect_changes`, `get_graph_schema`, `list_projects`, `delete_project`
- **Requires**: Nothing (single Go binary, zero deps)
- **Binary**: `/Users/panda/.local/bin/codebase-memory-mcp` (v0.4.6)
- **Query example**: `MATCH (f:Function)-[:CALLS]->(g) WHERE f.name = 'main' RETURN g.name`

### Layer 3: Persistent Agent Memory (`memory-service`)

- **Purpose**: "Remember that we decided to use Zod" — persistent learnings, decisions, gotchas across sessions
- **Technology**: SQLite-vec + local sentence-transformers (all-mpnet-base-v2, 768 dims, no API key needed)
- **How it works**: Stores text memories with semantic search, causal knowledge graph edges (`causes`, `fixes`, `contradicts`), and dream-inspired progressive consolidation:
  - Memories naturally **decay** over time (active → dormant → archived)
  - Old memories get **compressed** while preserving essentials
  - Critical memories can be "preserved" to resist decay
  - LLM-powered summarization on schedule (daily/weekly/monthly)
- **Data location**: `/Users/panda/.claude/memory-service/` (SQLite + vec index)
- **Tools**: 24 total including `store_memory`, `retrieve_memory`, `recall_memory`, `search_by_tag`, `delete_memory`, `cleanup_duplicates`, `check_database_health`, and more
- **Requires**: Nothing (local ONNX embeddings, no API key)
- **Package**: `mcp-memory-service` (pip/uv, v10.26.0)

## Configuration Files

### `~/.mcp.json` — Global MCP Server Configuration

Defines all MCP servers available to Claude Code across all projects. Contains:

- `claude-context` — semantic code search (requires `OPENAI_API_KEY`)
- `codebase-memory` — structural code graph (Go binary)
- `memory-service` — persistent agent memory (Python)

### `~/.claude/settings.json` — Claude Code Settings

Global Claude Code settings including:

- `permissions.allow` — pre-approved tool patterns
- `enableAllProjectMcpServers` — auto-trust project `.mcp.json` files
- `hooks` — shell commands triggered on events (SessionStart, PreCompact)
- `statusLine` — custom status bar command
- `enabledPlugins` — marketplace plugins (beads, context7, frontend-design, etc.)

### `~/.claude/CLAUDE.md` — This File

Global instructions loaded into every Claude Code session. Overrides defaults.

### `<project>/.mcp.json` — Project-Level MCP Servers

Per-project MCP servers (e.g., Notion, project-specific tools). Auto-trusted when `enableAllProjectMcpServers: true`.

### `<project>/CLAUDE.md` — Project-Level Instructions

Per-project instructions for Claude Code. Loaded when working in that directory.

### `~/.claude/plugins/` — Installed Plugins

Plugin cache and registry. Managed by Claude Code's plugin marketplace.

### `~/.claude/projects/` — Session History

Per-project session transcripts and settings. Keyed by absolute path.

## When to Use Which Memory Layer

| Question                                    | Layer           | Tool               |
| ------------------------------------------- | --------------- | ------------------ |
| "Find the auth middleware"                  | claude-context  | `search_code`      |
| "What functions call `validateToken`?"      | codebase-memory | `trace_call_path`  |
| "What did we decide about the DB schema?"   | memory-service  | `retrieve_memory`  |
| "Show me the API route structure"           | codebase-memory | `get_architecture` |
| "Find code similar to this pattern"         | claude-context  | `search_code`      |
| "Remember: this API paginates with cursors" | memory-service  | `store_memory`     |
| "What broke last time we changed auth?"     | memory-service  | `recall_memory`    |
| "Index this new project"                    | codebase-memory | `index_repository` |

## Quick Reference

```bash
# Check what MCP servers are running
# In Claude Code: /mcp

# Manually test memory service
memory status
memory server  # starts MCP server on stdio

# Manually test codebase-memory
codebase-memory-mcp --version

# Memory service data
ls ~/.claude/memory-service/

# Code graph data
ls ~/.cache/codebase-memory-mcp/

# Semantic search data
ls ~/.context/

# All config
cat ~/.mcp.json
cat ~/.claude/settings.json
```

## Quick Start: Bootstrapping a New Repository

When starting work on a new codebase, run these steps to fully index it:

### 1. Index the Code Structure (codebase-memory)

```
Use tool: index_repository with the absolute path
```

This builds the knowledge graph (functions, classes, call paths, routes) in seconds. Incremental re-indexing happens automatically on file changes.

### 2. Index for Semantic Search (claude-context)

```
Use tool: index_codebase with the absolute path
```

This generates vector embeddings for all code files. Takes longer (calls OpenAI API for embeddings). Use `get_indexing_status` to check progress. Use `force: true` to re-index.

### 3. Store Key Context (memory-service)

```
Use tool: store_memory to save important decisions, gotchas, architecture notes
```

Example memories to store early:

- "This project uses [framework] with [pattern]"
- "The API returns paginated results using cursor-based pagination"
- "Tests require Docker to be running for integration tests"
- "Deploy via `task deploy` — never push directly to main"

### Common Operations

```
# Semantic code search
search_code: "authentication middleware" → finds relevant code chunks

# Structural graph query
search_graph: "handleAuth" → finds function and all callers/callees
trace_call_path: from "main" to "validateToken" → shows full call chain
query_graph: "MATCH (f:Function)-[:CALLS]->(g) RETURN f.name, g.name LIMIT 10"
get_architecture: → generates full project architecture summary

# Memory operations
store_memory: "We decided to use Zod for validation because..."
retrieve_memory: "validation library decision" → finds relevant memories
recall_memory: "what broke last time" → searches with semantic similarity
search_by_tag: "architecture" → finds tagged memories

# Maintenance
get_indexing_status: check if semantic indexing is complete
clear_index: remove semantic index (forces full re-index)
delete_project: remove a project from the code graph
check_database_health: verify memory service integrity
cleanup_duplicates: deduplicate similar memories
```

### Re-indexing After Major Changes

If you refactor significantly or switch branches:

```
1. index_repository (force) → rebuilds code graph (~6s for large codebases)
2. index_codebase (force: true) → rebuilds vector embeddings (slower, API calls)
```

The memory service does NOT need re-indexing — it accumulates over time and consolidates automatically.

## Installed Plugins (via Claude Code Marketplace)

- **beads** — Issue tracking with dependency graphs (replaces TodoWrite)
- **context7** — Library documentation lookup
- **frontend-design** — Production-grade UI generation
- **gopls-lsp** — Go language server integration
- **ralph-loop** — Iterative refinement loops

## Session Hooks

Configured in `~/.claude/settings.json` under `hooks`:

| Event        | Matcher | Hook                                   | Purpose                                                  |
| ------------ | ------- | -------------------------------------- | -------------------------------------------------------- |
| SessionStart | startup | `bd prime`                             | Load beads issue tracker context                         |
| SessionStart | startup | `memory status`                        | Show memory service health                               |
| SessionStart | startup | `codebase-memory-mcp list-projects`    | Show indexed codebases                                   |
| SessionStart | resume  | `bd prime`                             | Re-inject beads on resume                                |
| SessionStart | compact | `bd prime` + `post-compact-context.sh` | Recover context after compaction                         |
| PreCompact   | —       | `bd prime` + `pre-compact.sh`          | Preserve context + instruct memory saving                |
| PreToolUse   | Bash    | `git-guard.sh`                         | Block destructive git ops + no AI attribution in commits |
| Stop         | —       | macOS notification                     | Notify when Claude finishes                              |

Hook scripts live at `~/.claude/hooks/`.

## Workstream Briefing (Session Start Behavior)

**On every new session (not resume), proactively produce a workstream briefing BEFORE asking the user what they want to do.** This is your first action — do it without being asked.

Steps:

1. Call `memory_search` with query "recent decisions learnings progress" (n_results: 5)
2. Check beads for open/blocked/ready issues (bd prime output from SessionStart hook already provides this)
3. Note which codebases are indexed (from SessionStart hook output)

Then output a concise briefing:

```
## Workstream Briefing

**Recent context:**
- [1-2 sentence summary of each relevant recent memory]

**Active work (beads):**
- [open issues, what's in progress, what's blocked, what's ready]

**Indexed projects:**
- [list of projects from codebase-memory]

What would you like to work on?
```

Rules:

- Keep it short — 10-15 lines max
- Skip any section that has no data
- Use relative timestamps ("yesterday", "2 days ago")
- Do NOT run this on resume or post-compact — only fresh sessions
- If the user jumps straight into a task, skip the briefing and get to work

## Continuous Memory Persistence

Do NOT wait for compaction to save important context. **Save to memory-service as you go:**

- After making a key decision → `memory_store` with tags `[decision, <project>]`
- After resolving a tricky bug → `memory_store` with tags `[debugging, gotcha, <project>]`
- After discovering a codebase pattern → `memory_store` with tags `[pattern, <project>]`
- After user states a preference → `memory_store` with tags `[preference, workflow]`

Keep memories concise (under 500 chars), factual, and tagged. This ensures nothing is lost when compaction happens — the PreCompact hook captures session state, but memories you've already persisted are the real safety net.

## External MCP Integrations (via claude.ai)

- **GitHub** — PR, issue, and code search
- **Notion** — Page search and editing
- **Hugging Face** — Model/dataset/paper search
- **Playwright** — Browser automation and testing
