#!/usr/bin/env bash
# install.sh — copies commands + hook script into ~/.claude/, registers hooks in settings.json.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

for cmd in jq curl git; do
  command -v "$cmd" >/dev/null || { echo "ERROR: $cmd not found. Install it first."; exit 1; }
done

CLAUDE_DIR="$HOME/.claude"
COMMANDS_DIR="$CLAUDE_DIR/commands"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
LIB_LINK="$CLAUDE_DIR/notetaker-kanban"

mkdir -p "$COMMANDS_DIR" "$HOOKS_DIR"

[ -L "$LIB_LINK" ] || ln -s "$REPO_ROOT" "$LIB_LINK"

cp -v "$REPO_ROOT/commands/"*.md "$COMMANDS_DIR/"

cp -v "$REPO_ROOT/hooks/notetaker-buffer.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/notetaker-buffer.sh"

RC_FILE="$HOME/.zshrc"
[ -f "$RC_FILE" ] || RC_FILE="$HOME/.bashrc"
PATH_LINE='export PATH="$HOME/.claude/notetaker-kanban/bin:$PATH"'
grep -qF "$PATH_LINE" "$RC_FILE" 2>/dev/null || echo "$PATH_LINE" >> "$RC_FILE"

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

TMP="$(mktemp)"
jq '
  .hooks //= {} |
  .hooks.UserPromptSubmit //= [] |
  .hooks.PostToolUse //= [] |
  .hooks.Stop //= [] |
  .hooks.UserPromptSubmit |=
    (map(select(._notetaker_kanban != true)) +
     [{ "_notetaker_kanban": true, "matcher": "*", "hooks": [{"type":"command","command":"~/.claude/hooks/notetaker-buffer.sh user_prompt"}] }]) |
  .hooks.PostToolUse |=
    (map(select(._notetaker_kanban != true)) +
     [
       { "_notetaker_kanban": true, "matcher": "Edit|Write|MultiEdit", "hooks": [{"type":"command","command":"~/.claude/hooks/notetaker-buffer.sh file_edit"}] },
       { "_notetaker_kanban": true, "matcher": "Bash",                  "hooks": [{"type":"command","command":"~/.claude/hooks/notetaker-buffer.sh bash_run"}] }
     ]) |
  .hooks.Stop |=
    (map(select(._notetaker_kanban != true)) +
     [{ "_notetaker_kanban": true, "matcher": "*", "hooks": [{"type":"command","command":"~/.claude/hooks/notetaker-buffer.sh session_stop"}] }])
' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"

echo
echo "✓ Installed."
echo "Now set in your shell rc (e.g. ~/.zshrc):"
echo "  export KANBAN_URL=http://localhost:3001"
echo "  export KANBAN_TOKEN=<from SmartKanban Settings → API tokens>"
echo
echo "Then in any git repo, run /kanban-start in a Claude session."
