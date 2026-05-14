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

Read `COMMITS`, `PATHS`, `STAT`. Write a short human-voiced update:

- **Bullet form.** Use `- ` (dash + space) bullets, one per shipped thing. 3–7 bullets total.
- **Group by intent**, not by file. "Bot polling now survives stale callbacks" beats "patched server/src/telegram/bot.ts".
- **Human voice.** Read like a teammate reporting in. Past-tense, plain language, no jargon dump. Avoid "shipped X", "implemented Y" — say what it does for the user.
- **Skip the file count line** unless the diffs are unusually large (5k+ lines or 50+ files); if you include it, make it the last bullet.
- **No commit-message rehash.** Refer to *what now works* not *which commit landed*.
- Avoid "I" / "we" — phrase as facts about the work itself.

Start with the header line `🤖 progress:` on its own line, then bullets below. The prefix is required for the cutoff detection in Step 2.

Example shape:

```
🤖 progress:
- Mobile capture bar now sits docked at the bottom and lets you save to any lane from one tap
- Login page got the same dark look as the board, with a violet logo mark and softer focus rings
- iOS keyboard no longer pushes the send arrow off-screen
- Telegram bot survives stale buttons — polling kept dying after the first error before
- Brainstorm has 30s of room instead of 10s, so it stops aborting under load
- Card IDs are now copyable from the edit dialog header on both web and mobile
```

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
