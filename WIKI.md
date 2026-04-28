# notetaker-kanban — slash command wiki

Plain-English reference for every slash command this bridge ships. Use
this when you're not sure what a command does, when to use it, or how
it interacts with your kanban card.

---

## Kanban columns (the lifecycle)

Cards live in one of four columns. Slash commands either move them or
tag them.

```
Backlog → Today → In Progress → Done
(idea)   (plan)   (working)    (shipped)
```

Tags (`#blocked`, `#deployed-local`, `#has-feedback`, etc.) are stickers
on the card. They do **not** move it. **Status changes** do move it.

---

## Story: a typical day

Walk through the bridge as you'd actually use it.

### Morning — start fresh

You start work on a feature.

```
/kanban-start
```

Reads your branch's git commits, summarizes via LLM, creates a card
titled e.g. `Voice control for tiles`, lands it in **Today**, links
your branch ↔ card forever.

After this, hooks track every prompt + edit + bash you do. Buffer grows
silently in `.kanban/buffer.jsonl`.

### Begin actual work

```
/kanban-doing
```

Moves card from **Today** → **In Progress**. Says "actively working on
this now."

(`/kanban-today` is similar but parks card in Today — used when planning,
not yet doing.)

### Hit a wall

You're waiting on review or external info.

```
/kanban-block waiting on PR review from alice
```

Adds `#blocked` tag and writes the reason as a comment. Card stays in
**In Progress** (you didn't stop, you're just waiting). Mirror tile
shows an amber bar so the household knows.

When unblocked:

```
/kanban-unblock
```

Removes the tag.

### Test locally

You build + deploy to your dev machine.

```
/kanban-deployed-local
```

Adds `#deployed-local` tag. Card stays in **In Progress**. Mirror tile
shows a green dot meaning "deployed locally, not prod yet".

Or wrap your deploy command — bridge auto-tags on success/fail:

```
kanban-deploy local -- ./scripts/deploy-local.sh
```

### Someone gives feedback

```
/kanban-feedback wake word fails on whispers, threshold too high
```

Adds `#has-feedback` tag and writes the feedback as comment. Card stays
where it is. Mirror tile pulses to remind you.

### End of session — flush activity

Claude's hooks logged your prompts/edits/bash silently. Push them to
the card:

```
/kanban-flush
```

Drains buffer → writes ONE summary entry to the card's activity log.
Either raw stats (no `OPENROUTER_API_KEY`) or LLM bullets. Doesn't move
the card.

(Auto-fires when you exit Claude session via the `Stop` hook. You
rarely run it manually.)

### Ship to production

Wrap your deploy:

```
kanban-deploy prod -- ./scripts/deploy-prod.sh
```

Or manual after deploying:

```
/kanban-deployed-prod
```

Adds `#deployed-prod` tag and **moves card to Done**. Done because
shipping = done. If you need to revisit (bug fix), make a new card.

---

## Cheat sheet

| Command | Moves card? | Adds tag? | When to use |
|---|---|---|---|
| `/kanban-start` | yes → Today | optional via LLM | starting work |
| `/kanban-today` | yes → Today | — | planning today's work |
| `/kanban-doing` | yes → In Progress | — | starting active work |
| `/kanban-done` | yes → Done | — | manual mark complete |
| `/kanban-block` | no | `#blocked` | hit wall, waiting |
| `/kanban-unblock` | no | removes `#blocked` | unblocked |
| `/kanban-deployed-local` | no | `#deployed-local` | tested on dev box |
| `/kanban-deployed-prod` | yes → Done | `#deployed-prod` | shipped to prod |
| `/kanban-feedback` | no | `#has-feedback` | someone reported issue |
| `/kanban-comment` | no | — | leave a free-form note |
| `/kanban-flush` | no | — | end of session (auto) |
| `/kanban-buffer` | no | — | debug — peek buffer |
| `/kanban-status` | no | — | sanity check wiring |
| `/kanban-list` | no | — | what's in flight |
| `/kanban-pull` | no | — | read another card |
| `/kanban-link` | no | — | wire branch to existing card |
| `/kanban-unlink` | no | — | disconnect branch ↔ card |

---

## Per-command reference

### Lifecycle

#### `/kanban-start`

**What**: bootstraps kanban tracking for the current branch.

**When**: first thing on a new branch (or to retroactively wire a
branch you've already been working on).

**Effect**: reads git history since merge-base with main, LLM-summarizes,
proposes a card. After confirmation, posts to kanban with status
**Today**, links branch ↔ card_id in `.kanban/local.json`.

**Example**:
```
/kanban-start
# → reads commits, proposes:
#   {title: "Voice control for tiles",
#    description: "Wake word detector + TileBus wiring + tests",
#    tags: ["smartmirror", "voice"],
#    status: "today"}
# → confirm → card created
```

#### `/kanban-link <card_id>`

**What**: bind your current branch to an existing card.

**When**: card was created elsewhere (web UI, telegram bot) and you
want hooks to track it.

**Example**: `/kanban-link c_42`

#### `/kanban-unlink`

**What**: remove the branch ↔ card mapping.

**When**: stop tracking. Card stays on kanban; hooks just stop appending
to it.

#### `/kanban-status`

**What**: prints project_key, current branch, mapped card_id, last
flush timestamp, buffer size.

**When**: sanity check. "Is the bridge actually wired?"

### State transitions (move the card)

#### `/kanban-today`

**What**: card → **Today** column.

**When**: you've planned to work on it today but haven't started.

#### `/kanban-doing`

**What**: card → **In Progress** column.

**When**: you're starting active work right now. Most common transition.

#### `/kanban-done`

**What**: card → **Done** column.

**When**: manually mark complete. Usually you'd let `/kanban-deployed-prod`
or a wrapped prod deploy mark it done.

### Tags (don't move the card)

#### `/kanban-block <reason>`

**What**: adds `#blocked` tag, posts reason as comment.

**When**: stuck on something external (review, dep, info). Card stays
in In Progress because you'd resume the moment unblocked.

**Example**: `/kanban-block waiting on PR review from alice`

#### `/kanban-unblock`

**What**: removes `#blocked` tag, posts an "unblocked" activity entry.

**When**: the blocker cleared.

#### `/kanban-deployed-local`

**What**: adds `#deployed-local` tag, posts a timestamped activity entry.

**When**: you deployed to your local dev environment for testing. Card
stays In Progress because the work isn't shipped yet.

#### `/kanban-deployed-prod`

**What**: adds `#deployed-prod` tag, **moves card to Done**.

**When**: shipped to production. Card lifecycle ends.

#### `/kanban-feedback <text>`

**What**: adds `#has-feedback` tag, writes the feedback as comment.

**When**: someone (spouse, coworker, you reading later) reports an
issue. Card stays where it is. Mirror tile pulses to surface this.

**Example**: `/kanban-feedback whisper detection misses, threshold too high`

### Activity / notes

#### `/kanban-comment <text>`

**What**: appends a free-form comment to the card's activity log.

**When**: leave a sticky note. No tag, no move.

**Example**: `/kanban-comment found root cause in line 42 of foo.ts`

#### `/kanban-flush`

**What**: drains `.kanban/buffer.jsonl` → posts one summary entry as
card activity.

**When**: end of session or before switching branches. Usually
auto-fires when you exit Claude session.

#### `/kanban-buffer`

**What**: cats the current buffer JSONL.

**When**: debugging. "What did the hooks record since last flush?"

### Discovery

#### `/kanban-list`

**What**: lists in-flight cards (status `today` + `in_progress`) for
the current project.

**When**: "what am I working on across this project?"

#### `/kanban-pull <card_id>`

**What**: prints full card detail (title, description, tags, status,
activity timeline).

**When**: read another card you didn't create.

---

## Common confusion cleared up

### "Why do I need both `/kanban-doing` AND `/kanban-deployed-local`?"

- `doing` is a **column move** ("this is what I'm working on right now").
  Once you flip to In Progress, you stay there until shipped.
- `deployed-local` is a **tag** ("I tested this on my machine"). Card
  stays In Progress because the work isn't shipped yet.

### "What's the difference between `/kanban-today` and `/kanban-doing`?"

- `today` = "I plan to do this today". Card waits in **Today** column.
- `doing` = "I'm doing this NOW". Card in **In Progress** column.

Multiple cards in Today is fine (your plan). Usually one card in In
Progress (focus).

### "Why does `/kanban-deployed-prod` auto-mark Done?"

Shipping to prod = the work is shipped. Card lifecycle ends. If you
need to revisit (bug fix), make a new card via `/kanban-start` on a
fix branch.

### "I forgot `/kanban-doing` and just ran `/kanban-deployed-local`. Now what?"

Card might say **Today** with `#deployed-local` tag — weird but harmless.
Run `/kanban-doing` to move it to In Progress.

### "What if I want to put a card back in Backlog?"

Bridge doesn't have a `/kanban-backlog` (yet). Edit the card via the
SmartKanban web UI or use `/kanban-pull <id>` first to verify, then
PATCH manually if needed.

### "I want to track the same branch on a different card."

Run `/kanban-unlink` then `/kanban-start` (creates new) or
`/kanban-link <other-card-id>` (binds to existing).

### "Hooks add bash commands to the card. What about secrets?"

Bridge redacts environment-variable assignments matching
`(TOKEN|SECRET|KEY|PASSWORD|API_KEY)` from bash command logs before
buffering. File contents are never logged — only file paths.

---

## See also

- [README.md](README.md) — install, setup, architecture
- [Design spec](https://github.com/chatwithllm/SmartMirror/blob/main/docs/superpowers/specs/2026-04-27-notetaker-kanban-design.md)
- SmartKanban one-click installer:
  ```
  curl -fsSL https://raw.githubusercontent.com/chatwithllm/SmartKanban/main/scripts/install.sh | bash
  ```
- Wiki on demand:
  ```
  curl -fsSL https://raw.githubusercontent.com/chatwithllm/SmartKanban/main/scripts/install.sh | bash -s -- explain
  ```
