---
description: "Show full card detail by id."
allowed-tools: ["Bash"]
---

# /kanban-pull

```bash
export NOTETAKER_LIB_DIR="${NOTETAKER_LIB_DIR:-$HOME/.claude/notetaker-kanban/lib}"
source "$NOTETAKER_LIB_DIR/config.sh"
source "$NOTETAKER_LIB_DIR/api.sh"
[ -n "${KANBAN_URL:-}" ] && [ -n "${KANBAN_TOKEN:-}" ] || { echo "set KANBAN_URL and KANBAN_TOKEN"; exit 1; }
ID="$1"
[ -n "$ID" ] || { echo "usage: /kanban-pull <card_id>"; exit 1; }
api_get_card "$ID" | jq .
```
