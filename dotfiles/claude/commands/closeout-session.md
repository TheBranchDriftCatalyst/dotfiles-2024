---
description: Append this session to SESSION_STATUS.md, roll old entries to the archive, and update the pointers
---

Close out the current working session by updating `SESSION_STATUS.md` at the repo root.

This file is the human-facing index someone reads cold — either to resume this repo, or to
scan several sibling repos side by side and see what each was last doing. Optimise for that
reader, not for completeness.

## 1. Gather what actually happened

Do not ask the user to recall it; derive it:

- **Commits this session** — `git log --since="<session start>" --oneline`. If the session
  spans a date boundary, use the real start, not midnight.
- **Tickets filed and closed** — from the tracker this repo uses (beads `bd`, or whatever
  `SESSION_STATUS.md`'s header names). Capture IDs, not summaries.
- **What is carried** — open tickets that this session touched or created and did not finish.
- **Scope** — which directories the work actually landed in.

If the session produced no commits and no ticket movement, say so and stop. An entry that
records nothing is worse than no entry: it dilutes the index.

## 2. Write the session entry

Insert **at the top** of the `<!-- closeout:sessions -->` block:

```markdown
### <YYYY-MM-DD> — <short title: what this session was about>

**Commits:** N · **Scope:** <dirs>

**Filed:** `ID`, `ID`, ...
**Closed:** `ID`, `ID`, ...
**Carried:** `ID` (why it matters)

<2–5 short paragraphs: what landed, what was learned, what it cost.>
```

Write it for someone who was not here. Lead with what changed, not with process narrative.
Include anything that was **found rather than built** — silent failures, wrong assumptions,
things that turned out not to work — those are the highest-value lines in the whole file.

State costs and mistakes plainly. A log that only records wins trains the next reader to
trust work that has not earned it.

## 3. Roll the index (retention)

The index keeps the **last 10** session entries.

- If there are now more than 10, move the oldest out of `SESSION_STATUS.md` and append it to
  `docs/session-archive.md`, newest-first there too. Create that file if missing.
- **Distil before archiving.** Before an entry leaves the index, check whether it taught a
  durable lesson. If so, lift it into the `<!-- closeout:gotchas -->` list _first_, phrased as
  an invariant ("X is not Y — check Z") rather than as a story. Episodes age out; invariants
  must not. This is the step that makes the file a knowledge base instead of a diary.
- Never delete an entry outright.

## 4. Update the pointers

- `<!-- closeout:header -->` — refresh **Updated**, **Pick up here** (the single ticket or epic
  a returning reader should open), and any **deadline item** with a real date.
- `<!-- closeout:next -->` — rewrite the Now/next table. Put anything time-boxed first with its
  deadline. Include an **explicitly not next** row when there is work someone would plausibly
  pick up but shouldn't; saying why is as valuable as the recommendation.

## 5. Rules to enforce while writing

- **Decisions and direction, never live health.** "We chose X because Y" ages well; "component
  Z is currently failing" is wrong within a day and misleads the next person debugging. Health
  belongs in alerts and dashboards.
- **Link to tickets, don't restate them.** Ticket bodies are the source of truth.
- **Keep the whole index near one screen.** If it does not fit, the fix is archiving and
  tighter prose — not smaller type.
- **Preserve the `<!-- closeout:* -->` anchors and the header shape.** They are what let this
  be scanned across repos and edited programmatically later.

## 6. If `SESSION_STATUS.md` does not exist

Bootstrap it for this repo using the structure above: header block, 30-second orientation,
Now/next, Sessions, Standing gotchas, and a "How this file is maintained" section. Keep the
header fields identical to sibling repos (`Kind`, `Tracker`, `Updated`, `Pick up here`) — the
cross-repo scan is the main reason this file exists.

## 7. Finish

Show the user the diff summary: entry added, entries archived, pointers changed. Then commit
it with the rest of the session's work if the tree is otherwise clean, or leave it staged and
say so. Do not push unless the user asked.
