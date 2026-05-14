---
description: "AI-summarize what shipped on this branch since the last progress comment, post to the linked card."
allowed-tools: ["Bash", "AskUserQuestion"]
---

# /kanban-progress

Read recent commits + diffstat on the current branch, summarize them as a 2-3 sentence progress update, post to the linked card.

## Step 1 — Context

```bash
export NOTETAKER_LIB_DIR="${NOTETAKER_LIB_DIR:-$HOME/.claude/notetaker-kanban/lib}"
source "$NOTETAKER_LIB_DIR/config.sh" 2>/dev/null || { echo "ERR notetaker-kanban not installed"; exit 1; }
source "$NOTETAKER_LIB_DIR/api.sh"
[ -n "${KANBAN_URL:-}" ] && [ -n "${KANBAN_TOKEN:-}" ] || { echo "ERR set KANBAN_URL and KANBAN_TOKEN"; exit 1; }
BRANCH="$(git symbolic-ref --quiet --short HEAD)"
[ -n "$BRANCH" ] || { echo "ERR detached HEAD"; exit 1; }
CARD_ID="$(config_get_card_id "$BRANCH")"
[ -n "$CARD_ID" ] || { echo "ERR no card linked for $BRANCH — run /kanban first"; exit 1; }
echo "CARD_ID=$CARD_ID"
echo "BRANCH=$BRANCH"
```

Stop on `ERR`.

## Step 2 — Find the cutoff (since-time)

Query the card's timeline for the most recent progress comment (body starts with `🤖 progress:`). If found, use its `created_at`. Otherwise use merge-base with main.

```bash
SINCE="$(api_get_card "$CARD_ID" 2>/dev/null | \
  jq -r '[.events[]? | select(.entry_type=="system") | select((.details.body // "") | startswith("🤖 progress:"))] | last | .created_at // ""')"

if [ -z "$SINCE" ]; then
  MAIN="$(config_main_branch)"
  SINCE="$(git log -1 --format=%cI "$(git merge-base "$BRANCH" "$MAIN")" 2>/dev/null || true)"
fi
echo "SINCE=${SINCE:-<branch-start>}"
```

## Step 3 — Gather commits + diffstat

```bash
# Commits since cutoff, with author + subject + body
COMMITS="$(git log --since="$SINCE" --pretty=format:'%h | %s%n%b%n---' HEAD)"
# Files touched + stat
STAT="$(git log --since="$SINCE" --pretty=format:'' --shortstat HEAD | grep -v '^$' || true)"
# Diff summary by path
PATHS="$(git log --since="$SINCE" --name-only --pretty=format:'' | sort -u | grep -v '^$' | head -40)"
```

If both `COMMITS` and `PATHS` are empty, tell the user "Nothing new since the last progress note" and stop.

## Step 4 — Compose the summary (Claude does this)

Read `COMMITS`, `PATHS`, `STAT`. Write a single short paragraph (2-4 sentences max) that:

- Says what shipped (features/fixes/refactors) — group by intent, not file
- Mentions concrete numbers when meaningful (e.g. "12 files, +280/-90")
- Avoids commit-message rehash; this is a status update, not a changelog
- No bullet points; flowing prose
- No "I" / "we" — third-person factual

Prefix with `🤖 progress:` so the cutoff detection in Step 2 catches it next time.

Example shape: `🤖 progress: Mobile capture row now docks with a target-lane chip; sheet picker portals to body so all four lanes are reachable. Login redesigned to match the dark board look. 6 files, +566/-258.`

## Step 5 — Confirm + post

Show the summary to the user with `AskUserQuestion`:

- **Post as-is** — fire `api_post_activity "$CARD_ID" "comment" "$SUMMARY" '{}'`
- **Edit** — let the user paste a revised version, then post
- **Cancel** — drop without posting

After posting:

```bash
echo "✓ progress posted on $CARD_ID"
echo "  $KANBAN_URL"
```

## Notes

- Summary text size cap: 2000 chars (server enforces). Truncate if longer.
- Don't include URLs, secrets, or emails in the summary.
- The `🤖 progress:` prefix is load-bearing for the cutoff detection — don't drop it.
