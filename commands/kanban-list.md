---
description: "List in-progress cards for current project."
allowed-tools: ["Bash"]
---

# /kanban-list

```bash
export NOTETAKER_LIB_DIR="${NOTETAKER_LIB_DIR:-$HOME/.claude/notetaker-kanban/lib}"
source "$NOTETAKER_LIB_DIR/config.sh"
source "$NOTETAKER_LIB_DIR/api.sh"
[ -n "${KANBAN_URL:-}" ] && [ -n "${KANBAN_TOKEN:-}" ] || { echo "set KANBAN_URL and KANBAN_TOKEN"; exit 1; }
PROJECT="${1:-$(config_project_key)}"
curl -sSf "$KANBAN_URL/api/cards?scope=personal&project=$PROJECT" \
  -H "$(api_auth_header)" \
  | jq -r '.[] | select(.status == "in_progress" or .status == "today") | "\(.status)\t\(.id)\t\(.title)"'
```
