---
description: "Remove branch ↔ card mapping."
allowed-tools: ["Bash"]
---

# /kanban-unlink

```bash
export NOTETAKER_LIB_DIR="${NOTETAKER_LIB_DIR:-$HOME/.claude/notetaker-kanban/lib}"
source "$NOTETAKER_LIB_DIR/config.sh"
[ -n "${KANBAN_URL:-}" ] && [ -n "${KANBAN_TOKEN:-}" ] || { echo "set KANBAN_URL and KANBAN_TOKEN"; exit 1; }
BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"
[ -n "$BRANCH" ] || { echo "detached HEAD"; exit 1; }
config_unset_card_id "$BRANCH"
echo "✓ branch $BRANCH unlinked"
```
