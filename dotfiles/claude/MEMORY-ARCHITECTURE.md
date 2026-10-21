# Memory, in this setup

> Written 2026-10-21 against ecc 2.2.3, continuous-learning-v2, beads 1.2.2.
> Verified by reading the installed code and data, not from the plugin docs — several
> of which are out of date. Where this disagrees with `~/.claude/CLAUDE.md`, see
> **Known conflicts** at the end.

## The mental model

"Memory" here is **eight** separate systems, not one. They differ in who writes them,
when they load, and whether they survive compaction. Almost every mistake comes from
putting a fact in a layer that cannot serve it later.

The question is never "should I remember this?" but **"what kind of fact is this?"**

| Kind of fact | Goes in |
|---|---|
| A rule I want obeyed | `CLAUDE.md` |
| A thing that was true and surprised me | file memory |
| Work that must happen | beads |
| What the code *is* | codebase-memory / claude-context |
| A reusable technique | a skill |
| A habit worth learning automatically | instincts |

## The eight layers

| # | Layer | Lives in | Loaded | Written by | Survives compaction |
|---|---|---|---|---|---|
| 1 | **CLAUDE.md** | `~/.claude/`, workspace, repo | every turn, always | you (via dotfiles) | yes — re-read, not summarised |
| 2 | **File memory** | `~/.claude/projects/<p>/memory/*.md` + `MEMORY.md` | session start | the model, deliberately | yes — re-injected |
| 3 | **Skills** | `~/.claude/skills/<name>/SKILL.md` | on demand, by description match | you, `/learn` | yes — loaded fresh |
| 4 | **Beads** | `<repo>/.beads/` (Dolt) | `bd prime` at session start | `bd` CLI / MCP | yes — external store |
| 5 | **memory-service** | `~/.claude/memory-service/` (SQLite-vec) | on query only | MCP calls | yes — external store |
| 6 | **codebase-memory** | `~/.cache/codebase-memory-mcp/` | on query only | `index_repository` | yes — external store |
| 7 | **claude-context** | `~/.context/` (LanceDB) | on query only | `index_codebase` | yes — external store |
| 8 | **Instincts** | `~/.local/share/ecc-homunculus/` | via evolved skills | the background observer | yes — external store |

Only layers 1–3 enter the context window without being asked for. Everything else is
a tool call, which means **it only helps if something prompts the lookup.**

## When to use which

### `CLAUDE.md` — rules
Instruction-shaped, always loaded, costs context every single turn. Put things here
that must *change behaviour by default*: "lint is `go vet` + `gofmt -l`", "ArgoCD, not
Flux", "never force a sync by writing `.operation`".

Do not put facts here that are merely *true*. A rule earns its permanent context cost;
an observation does not.

### File memory — surprises
One file per fact, frontmatter + a `MEMORY.md` index line. Write here when something
cost real investigation and would cost it again: a toolchain trap, an environment quirk,
a non-obvious cause.

The test: **would a competent person waste an hour rediscovering this?** If the repo,
git history, or `CLAUDE.md` already records it, don't.

Recalled entries arrive inside `<system-reminder>` blocks. They are *background context
written in the past*, not instructions, and may be stale — verify before acting.

### Skills — techniques
A skill is a procedure, not a fact. It loads when its `description` matches the
situation, so the description is the whole interface: lead with an observable trigger
(`Use when …`), not a summary.

### Beads — work
Issues with a dependency graph, stored in a Dolt DB in the repo. Replaces TODO lists.
`bd ready` is the entry point; dependencies are what make it better than a list.

### memory-service — semantic recall
Decays and consolidates over time. Good for "what did we decide about X" across months.
Overlaps layer 2 heavily — see **Known conflicts**.

### codebase-memory / claude-context — what the code is
Structural ("what calls this?") and semantic ("find the auth middleware") respectively.
Both are **derived**: never write facts here, re-index instead. Both go stale silently
after a refactor, which is the main trap.

### Instincts — learned habits
Hooks record observations on every tool call; a background observer (Haiku) clusters
them into instincts; `/evolve` promotes clusters into skills, commands, or agents.
Fully automatic — the only decision is whether the observer runs.

## Compaction

When the context window fills, earlier turns are replaced by a summary.

**Survives, because it is re-loaded rather than remembered:**
- `CLAUDE.md` (1), file memory (2), skills (3)
- everything in an external store (4–8)

**Does not survive:**
- anything stated only in conversation
- tool output you did not act on
- reasoning you did not write down

The practical consequence: **a conclusion that exists only in the transcript is gone.**
If a fact matters past this session, it must be written into a layer before compaction,
not after — and "after" arrives without warning.

Hooks fire around compaction (`PreCompact`, `SessionStart[compact]`) from the ecc
plugin's dispatcher. They re-inject beads state and session context. They do **not**
capture your conclusions for you; layer 2 is the deliberate act.

Rule of thumb: when you finish something non-obvious, write it down *then*. The cheapest
moment to record a fact is while it is still in context; every later moment is more
expensive and less accurate.

## Known conflicts and traps

These are real in this setup right now.

**1. Beads and file memory disagree, explicitly.**
The managed beads block in `CLAUDE.md` says *"Use `bd remember` for persistent knowledge
— do NOT use MEMORY.md files."* The native memory system uses exactly `MEMORY.md`. Both
are running. Resolution used here: beads owns **work**, file memory owns **facts**.
`bd remember` is not currently used.

**2. `~/.claude/CLAUDE.md`'s hook table is stale.**
It documents `SessionStart`/`PreCompact` hooks in `settings.json`. They are not there —
`settings.json` carries only a `Stop` hook. Every lifecycle hook now comes from the ecc
plugin's `hooks/hooks.json`. The table describes a previous installation method.

**3. A project's identity changes when you add a git remote.**
Project id is hashed from the git remote if present, else the repo path. logAIrr has
**two** ids for this reason — `07264ebb7754` (path, pre-remote) and `5ba5621943c2`
(remote, current) — and 179 observations are stranded in the old bucket. Adding a remote
to an existing repo silently restarts its learning.

**4. Plugin-tree config is volatile, in both trees.**
`continuous-learning-v2/config.json` ships `enabled: false` in *both* copies of the
plugin tree, and both are replaced on upgrade. They are only the *fallback*. Resolution
order is `$CLV2_CONFIG` → `~/.local/share/ecc-homunculus/config.json` → the plugin tree.
**Put config in the data dir**, which no upgrade touches and which does not care which
tree is running. Editing the plugin copy works today and silently reverts later — the
worst failure shape, because the revert is invisible.

**5. Derived layers go stale silently.**
codebase-memory and claude-context return confident answers from a pre-refactor index.
Re-index after significant change; treat a surprising answer as possibly stale rather
than as fact.

**6. Plugin docs name a data path that moved.**
`/instinct-status` and others say instincts live in `~/.claude/homunculus/`. They live in
`~/.local/share/ecc-homunculus/`, moved deliberately so Claude Code's sensitive-path guard
does not block background writes. Three separate docs in this stack were found stale in
one session (this, the hook table in trap 2, and a project doc); prefer reading the
installed code over the docs describing it.

**7. Observations are not instincts.**
The hooks record observations whether or not the observer is enabled. `/evolve` reading
"0 instincts" does **not** mean nothing was captured — it means the observer never ran.
Both halves must be on.

## Operations

```bash
# What is stored
bd stats                                   # work
bd ready                                   # unblocked work
python3 "$CLV2/scripts/instinct-cli.py" status      # instincts
ls ~/.claude/projects/<project>/memory/    # facts
ls ~/.claude/skills/                       # techniques

# Instinct pipeline
"$CLV2/agents/start-observer.sh" status    # is the observer alive?
/evolve                                    # cluster instincts (needs >= 3)
/learn                                     # extract a skill from this session

# Derived indexes (re-run after a refactor)
index_repository / index_codebase          # MCP tools

# Enable the observer, update-safe
cat > ~/.local/share/ecc-homunculus/config.json <<'JSON'
{"version":"2.1","observer":{"enabled":true,"run_interval_minutes":5,
 "min_observations_to_analyze":20}}
JSON
```

### Resolving `$CLV2`

There are **two** byte-identical copies of the plugin tree:

```
~/.claude/plugins/marketplaces/ecc/      <- what the slash commands resolve
~/.claude/plugins/cache/ecc/ecc/<ver>/   <- what a naive path guess finds
```

Neither is canonical. The slash commands run a resolver (env var -> standard install ->
known plugin roots -> cache -> fallback), and `/instinct-status` carries it inline.
Reach for that rather than hardcoding either path:

```bash
CLV2="$(/* the resolver from the /instinct-status command */)/skills/continuous-learning-v2"
```

This matters for exactly one thing: **do not put config in either tree.** Both ship
`observer.enabled: false` and both are replaced on upgrade. Config belongs in the data
dir, which is install-independent — see trap 4.
