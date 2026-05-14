---
description: "Bind branch to existing card_id."
allowed-tools: ["Bash"]
---

# /kanban-link

```bash
export NOTETAKER_LIB_DIR="${NOTETAKER_LIB_DIR:-$HOME/.claude/notetaker-kanban/lib}"
source "$NOTETAKER_LIB_DIR/config.sh"
source "$NOTETAKER_LIB_DIR/api.sh"
[ -n "${KANBAN_URL:-}" ] && [ -n "${KANBAN_TOKEN:-}" ] || { echo "set KANBAN_URL and KANBAN_TOKEN"; exit 1; }
BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"
[ -n "$BRANCH" ] || { echo "detached HEAD"; exit 1; }
ID="$1"
[ -n "$ID" ] || { echo "usage: /kanban-link <card_id>"; exit 1; }
config_set_card_id "$BRANCH" "$ID"
api_announce_branch_link "$ID" "$BRANCH"
echo "✓ branch $BRANCH linked to card $ID"
```
