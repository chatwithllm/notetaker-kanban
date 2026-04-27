---
description: "Tag active card #deployed-local."
allowed-tools: ["Bash"]
---

# /kanban-deployed-local

```bash
export NOTETAKER_LIB_DIR="${NOTETAKER_LIB_DIR:-$HOME/.claude/notetaker-kanban/lib}"
source "$NOTETAKER_LIB_DIR/config.sh"
source "$NOTETAKER_LIB_DIR/api.sh"
[ -n "${KANBAN_URL:-}" ] && [ -n "${KANBAN_TOKEN:-}" ] || { echo "set KANBAN_URL and KANBAN_TOKEN"; exit 1; }
BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"
CARD_ID="$(config_get_card_id "$BRANCH")"
[ -n "$CARD_ID" ] || { echo "no card linked for branch $BRANCH; run /kanban-start"; exit 1; }
api_add_tags "$CARD_ID" "deployed-local" >/dev/null
api_post_activity "$CARD_ID" "deployed_local" "deployed locally at $(date -u +%FT%TZ)" '{}'
echo "✓ $CARD_ID deployed-local"
```
