---
description: "Show project, branch, card, last flush, buffer size."
allowed-tools: ["Bash"]
---

# /kanban-status

```bash
export NOTETAKER_LIB_DIR="${NOTETAKER_LIB_DIR:-$HOME/.claude/notetaker-kanban/lib}"
source "$NOTETAKER_LIB_DIR/config.sh"
source "$NOTETAKER_LIB_DIR/buffer.sh"
BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"
CARD_ID="$(config_get_card_id "$BRANCH" 2>/dev/null || true)"
PROJECT="$(config_project_key 2>/dev/null || true)"
LAST_FLUSH="$(jq -r '.last_flush // "never"' "$(config_dir)/local.json" 2>/dev/null || echo "n/a")"
SIZE="$(buffer_size_bytes 2>/dev/null || echo 0)"
echo "project: ${PROJECT:-<none>}"
echo "branch:  ${BRANCH:-<detached>}"
echo "card:    ${CARD_ID:-<unlinked>}"
echo "last_flush: $LAST_FLUSH"
echo "buffer_bytes: $SIZE"
```
