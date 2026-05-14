---
description: "One-stop kanban command. Detects context, shows interactive menu, routes to start/comment/move/tag/info actions. Replaces the 17 separate /kanban-* commands for the common case."
allowed-tools: ["Bash", "AskUserQuestion"]
---

# /kanban

Single entry-point for the notetaker-kanban bridge. Show the user a menu of what they can do right now, then execute their pick. No need to remember 17 separate slash commands.

## Step 1 — Detect context

Run this and read the output. Do not show this to the user; it informs which menu to render.

```bash
export NOTETAKER_LIB_DIR="${NOTETAKER_LIB_DIR:-$HOME/.claude/notetaker-kanban/lib}"
source "$NOTETAKER_LIB_DIR/config.sh" 2>/dev/null || { echo "ERR notetaker-kanban not installed"; exit 1; }
[ -n "${KANBAN_URL:-}" ] && [ -n "${KANBAN_TOKEN:-}" ] || { echo "ERR set KANBAN_URL and KANBAN_TOKEN in your shell rc"; exit 1; }
git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "ERR not in a git repo"; exit 1; }
BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"
[ -n "$BRANCH" ] || { echo "ERR detached HEAD"; exit 1; }
CARD_ID="$(config_get_card_id "$BRANCH" 2>/dev/null || true)"
echo "BRANCH=$BRANCH"
echo "CARD_ID=${CARD_ID:-NONE}"
```

If output starts with `ERR`, print the message and stop. Otherwise extract `BRANCH` and `CARD_ID`.

## Step 2 — Pick menu based on context

### A. No card linked yet (`CARD_ID=NONE`)

Use `AskUserQuestion` with these options:

- **Start a card for this branch** — bootstrap a card from git history (runs the `/kanban-start` flow inline)
- **Link to an existing card** — bind this branch to a card ID the user already knows
- **Status** — show project + branch + recent activity
- **List recent cards** — show in-progress cards so the user can pick one to link

### B. Card already linked

Use `AskUserQuestion` with these options:

- **Progress** — AI-summarize commits + diffs since last progress note, post to card (delegates to `/kanban-progress`)
- **Move card** → sub-menu (Today / In Progress / Done)
- **Comment** — append a free-form note to the card
- **More** → sub-menu (Tag deployed-local/-prod/blocked/feedback/unblock, Flush, Status, Pull, Unlink)

## Step 3 — Execute the chosen action

Each action below assumes the lib is already sourced. If the user picks a sub-menu, ask a follow-up `AskUserQuestion` for the leaf choice.

### Start a card (no card linked)

Defer to the full `/kanban-start` instructions: read git history, propose JSON, confirm with user, POST to kanban, save mapping.

### Link to existing card

```bash
source "$NOTETAKER_LIB_DIR/api.sh"
# Prompt the user for the card UUID, then:
config_set_card_id "$BRANCH" "$CARD_ID_FROM_USER"
api_announce_branch_link "$CARD_ID_FROM_USER" "$BRANCH"
echo "✓ Bound branch $BRANCH to card $CARD_ID_FROM_USER"
```

### List recent cards

```bash
source "$NOTETAKER_LIB_DIR/api.sh"
api_list_cards | jq -r '.[] | select(.status=="today" or .status=="in_progress") | "\(.id) [\(.status)] \(.title)"'
```

If user then says "link to #2" or similar, run the link step above with the matching id.

### Move card (sub-menu)

```bash
source "$NOTETAKER_LIB_DIR/api.sh"
# STATUS = today | in_progress | done (from sub-menu)
api_patch_card "$CARD_ID" "$(jq -cn --arg s "$STATUS" '{status:$s}')" >/dev/null
api_post_activity "$CARD_ID" "state_change" "moved to $STATUS" '{}'
echo "✓ $CARD_ID → $STATUS"
```

### Comment

Ask the user for the comment text (free-text input), then:

```bash
source "$NOTETAKER_LIB_DIR/api.sh"
api_post_activity "$CARD_ID" "comment" "$TEXT" '{}'
echo "✓ commented on $CARD_ID"
```

### Tag (sub-menu)

For deployed-local / deployed-prod / blocked / unblock / feedback, run the same body as the corresponding `/kanban-<tag>` command. Keep it short — they're all 5-10 lines of bash that touch tags or post activity.

### Flush

Run the body of `/kanban-flush` (drain buffer, summarize, post activity).

### Status

```bash
source "$NOTETAKER_LIB_DIR/api.sh"
echo "Project: $(config_project_key)"
echo "Branch:  $BRANCH"
echo "Card:    ${CARD_ID:-(none)}"
[ -n "$CARD_ID" ] && api_get_card "$CARD_ID" | jq -r '"Title: \(.title)\nStatus: \(.status)\nTags: \(.tags | join(\", \"))"'
```

### Pull

Ask the user for a card id (default to current `CARD_ID`), then:

```bash
source "$NOTETAKER_LIB_DIR/api.sh"
api_get_card "$CARD_ID" | jq .
```

### Unlink

```bash
config_unset_card_id "$BRANCH"
echo "✓ Unlinked branch $BRANCH from its card"
```

## Notes

- Always run inside the user's git repo (cd is implicit; the lib reads `.kanban/`).
- After every action, print a one-line success message ending in `✓`.
- Do not chain unrelated actions in one invocation — finish the chosen action and stop.
- The 17 individual `/kanban-*` commands still exist as power-user shortcuts; this one is the recommended path.
