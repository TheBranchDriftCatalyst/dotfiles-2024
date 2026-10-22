# Claude Code config — who owns what, and why

This folder is one of **three** places Claude Code configuration lives. The split is not
taste; it falls out of one mechanical fact and one bad experience. Read the decider below
before adding anything here.

> **Status (2026-10-22):** mid-migration. `settings.json` and `hooks/git-guard.sh` are
> still present but on their way out — see [Migration status](#migration-status). The
> ownership rules below are the target and are already binding on new files.

## The decider

**Does Claude Code itself ever write the file?**

- **Yes → nix must not own it.** Not a symlink, not a seeded copy, not tracked.
  Claude Code saves files with temp-file + `rename(2)`, which **replaces the directory
  entry** at that path. It does not follow a symlink and write through it. So a
  home-manager link there is destroyed the first time the app records anything, and
  home-manager's `checkLinkTargets` then aborts the next `switch` because it finds a
  regular file where it owns a link. Anthropic's docs say the same from the other side:
  *"If you can't write to that file, for example because another tool generates it or
  links it to a read-only copy, the change applies to the current session and is gone in
  the next one."*
- **No → nix can own it declaratively**, either as a live out-of-store symlink (if you
  want to edit it without a rebuild) or as generated store content.

Files the app **writes**: `~/.claude/settings.json`, `.claude/settings.local.json`,
`~/.claude.json`.
Files the app **never writes**: managed settings, project `.claude/settings.json`.

## The three homes

Settings precedence, highest first. A key set higher wins; **list** keys
(`permissions.allow`, `hooks`) *merge* across levels instead of overriding, which is why
declarative entries don't block app-side approvals.

| # | Layer | Path | Owner | Carries |
|---|---|---|---|---|
| 1 | Managed | `/Library/Application Support/ClaudeCode/managed-settings.d/` | **nix** (`darwin/claude.nix`) | `statusLine`, `env`, `permissions`, `extraKnownMarketplaces`, `enabledPlugins`, `pluginConfigs`, `autoMode`, `git` |
| 2 | CLI | `--settings` | — | one-session overrides |
| 3 | Project local | `.claude/settings.local.json` | **app** | permission approvals ("don't ask again") |
| 4 | Project | `.claude/settings.json` | repo | per-project keys |
| 5 | User | `~/.claude/settings.json` | **app**, untracked | `theme`, `tui`, `effortLevel`, `agentPushNotifEnabled`, `skipWorkflowUsageWarning` |

Plus a fourth, non-settings home: **plugins** (see below), which supply `hooks`, agents,
commands, skills and MCP servers.

Managed settings is written to a `managed-settings.d/` drop-in rather than
`managed-settings.json` on purpose: this machine is Addigy-MDM managed and MDM writes that
filename, so owning a drop-in means the two never contend for one inode. Drop-ins also
merge last, so they still get the final word.

## What belongs in this folder

This folder is the **live payload**: files reached by an out-of-store symlink, so edits
take effect immediately with no rebuild. That is the whole reason a file is here rather
than generated into the store.

| File | Why it's here |
|---|---|
| `CLAUDE.md` | Global prompt. The app writes it (`/memory`, `#`), so it must be a live link, and it's prose you iterate on constantly. |
| `agents/`, `commands/` | `/agents` and `/commands` create files in them. App-written → live link. |
| `hooks/statusline.sh` | A `statusLine` command. **Cannot** live in a plugin (see below), and it's a script you tune by eye. |
| `ecc-homunculus-config.json` | Read-only to the plugin — `observe.sh` only ever `json.load`s it. Must sit in the data dir, because the plugin tree has two byte-identical copies that are both replaced on upgrade. |
| `MEMORY-ARCHITECTURE.md` | Documentation. |

**What does not belong here:** anything the app never writes and you don't hand-edit —
that is policy, and it goes to `darwin/claude.nix` via `claude/policy.nix`. And anything a
plugin can supply — that goes to the plugin.

## What the plugins are for

Hooks, agents, commands, skills, and MCP servers are **distributed as plugins**, from
[`catalyst-agentic-sdlc`](https://github.com/TheBranchDriftCatalyst/catalyst-agentic-sdlc)
(the `catalyst` marketplace) and ECC. A plugin is a unit you version, test and ship —
`git-guard.sh` lives in `catalyst-meta` next to its own 89-assertion suite, gated by that
repo's lefthook.

**What a plugin cannot supply.** A plugin's `settings` key honors **only** `agent` and
`subagentStatusLine`; every other key is dropped at load. So:

- `statusLine` — **no.** Stays in a settings file. (`subagentStatusLine` is a different key.)
- `env` — **no.** Stays in a settings file.
- `hooks` — **yes**, via `hooks/hooks.json` or the manifest `hooks` key.

Plugin identity (`enabledPlugins`, `extraKnownMarketplaces`, `pluginConfigs`) stays
declarative in managed settings, because it is the one app-written thing a fresh machine
cannot rediscover on its own.

## How we got into the dual-management state — and the rule that prevents it

**What went wrong.** One file, `settings.json`, mixed declarative config (hooks,
statusLine, marketplaces) with app-owned churn (theme, effortLevel, plugin enables). Since
nix couldn't symlink it (the `rename(2)` fact above), the repo kept a *second copy* and a
130-line bidirectional merge script, `claude-settings-sync.sh`, ran from a `Stop` hook
after every turn to reconcile them.

What that actually bought:

- The script could **corrupt the tracked file** — its final write was
  `cat "$tmp" > "$REPO_FILE"`, a truncate-in-place rather than an atomic `mv`.
- It **structurally could not detect deletions**, so the repo silently accumulated stale
  keys forever.
- It had a **TOCTOU window** on `--push`, racing the app's own atomic rename.
- Worst, it **propagated one machine's state to another**: `autoMode` rules embed literal,
  never-expanded paths, so catalystM5's `/Users/panda/.dotfiles` rules were copied onto a
  host where `$HOME` is `/Users/dj`. Three of five `allow` rules were dead there and
  nobody noticed.

The same shape showed up a second time with hooks: `git-guard.sh` existed in **both** this
repo and the `catalyst-meta` plugin, both ran on every Bash call, and the plugin's copy was
a months-old fork that still had a bug this repo had already fixed.

**The rule, stated once:**

> **Never write a script that keeps two copies of the same file in step.**
> If you are tempted to, the file is in the wrong layer. Move it up or down the
> precedence chain until exactly one writer owns it.

And its corollary: **one artifact, one home.** If a hook, script, or config exists in two
places, they will drift, and you will debug the stale one.

### Before you add anything here, answer these

1. **Does the app write it?** Yes → it cannot be nix-owned. Untracked, app's own file.
2. **Can a plugin supply it?** Yes → put it in the plugin, with its test. Not here.
   (Remember `statusLine` and `env` cannot.)
3. **Is it policy you want enforced and reproducible?** → `claude/policy.nix` →
   managed settings. Not here.
4. **Is it prose or a script you iterate on, that the app may also write?** → here, as a
   live out-of-store symlink.
5. **Would keeping this correct require syncing two copies?** → stop. Re-answer 1–3.

## Migration status

| Item | State |
|---|---|
| `git-guard.sh` + its test suite | Moved into `catalyst-meta`. The copy here is **pending deletion** — it must not go until the new plugin version is actually installed, or the stale cached copy becomes the only guard. |
| `pre-compact.sh`, `post-compact-context.sh`, `workstream-briefing.sh`, `HOOKS-LIFECYCLE.md` | Deleted here; the plugin's copies are now the only ones. Still PARKED (they need the beads/memory-service MCPs). |
| `settings.json` | **Pending deletion.** Declarative keys move to `claude/policy.nix`; churn keys become untracked app state. |
| `claude-settings-sync.sh` + its `Stop` hook | **Pending deletion**, replaced by managed settings. |
| `darwin/claude.nix` + `claude/policy.nix` | Not yet written. |

Tracking: `dotfiles-ew4`, `dotfiles-gyy`, `dotfiles-r5y`, `dotfiles-hr4`, `dotfiles-9c3`.

One nix trap worth knowing when `darwin/claude.nix` lands:
`system.activationScripts.<anyName>.text` **evaluates and builds but never runs** — the
activate script is an explicit concatenation of named phases, and only `preActivation`,
`extraActivation` and `postActivation` are user-writable. Use `extraActivation`, which also
runs before home-manager (spliced into `postActivation`) and therefore before the ECC
installer.
