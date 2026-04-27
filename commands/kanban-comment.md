---
description: "Append free-form comment to card."
allowed-tools: ["Bash"]
---

# /kanban-comment

```bash
export NOTETAKER_LIB_DIR="${NOTETAKER_LIB_DIR:-$HOME/.claude/notetaker-kanban/lib}"
source "$NOTETAKER_LIB_DIR/config.sh"
source "$NOTETAKER_LIB_DIR/api.sh"
[ -n "${KANBAN_URL:-}" ] && [ -n "${KANBAN_TOKEN:-}" ] || { echo "set KANBAN_URL and KANBAN_TOKEN"; exit 1; }
BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"
CARD_ID="$(config_get_card_id "$BRANCH")"
[ -n "$CARD_ID" ] || { echo "no card linked for branch $BRANCH; run /kanban-start"; exit 1; }
TEXT="$*"
[ -n "$TEXT" ] || { echo "usage: /kanban-comment <text>"; exit 1; }
api_post_activity "$CARD_ID" "comment" "$TEXT" '{}'
echo "✓ commented on $CARD_ID"
```
