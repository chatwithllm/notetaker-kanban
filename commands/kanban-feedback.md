---
description: "Append feedback comment + tag #has-feedback."
allowed-tools: ["Bash"]
---

# /kanban-feedback

```bash
export NOTETAKER_LIB_DIR="${NOTETAKER_LIB_DIR:-$HOME/.claude/notetaker-kanban/lib}"
source "$NOTETAKER_LIB_DIR/config.sh"
source "$NOTETAKER_LIB_DIR/api.sh"
[ -n "${KANBAN_URL:-}" ] && [ -n "${KANBAN_TOKEN:-}" ] || { echo "set KANBAN_URL and KANBAN_TOKEN"; exit 1; }
BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"
CARD_ID="$(config_get_card_id "$BRANCH")"
[ -n "$CARD_ID" ] || { echo "no card linked for branch $BRANCH; run /kanban-start"; exit 1; }
TEXT="$*"
[ -n "$TEXT" ] || { echo "usage: /kanban-feedback <text>"; exit 1; }
api_add_tags "$CARD_ID" "has-feedback" >/dev/null
api_post_activity "$CARD_ID" "feedback" "$TEXT" '{}'
echo "✓ feedback recorded on $CARD_ID"
```
