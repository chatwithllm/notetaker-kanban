#!/usr/bin/env bash
# uninstall.sh — surgical removal: deletes our hook entries, slash commands, hook script, symlink, PATH line.
set -u
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS" ]; then
  TMP="$(mktemp)"
  jq '
    .hooks.UserPromptSubmit //= [] | .hooks.PostToolUse //= [] | .hooks.Stop //= [] |
    .hooks.UserPromptSubmit |= map(select(._notetaker_kanban != true)) |
    .hooks.PostToolUse      |= map(select(._notetaker_kanban != true)) |
    .hooks.Stop             |= map(select(._notetaker_kanban != true))
  ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
fi

rm -f "$CLAUDE_DIR/commands/kanban-"*.md
rm -f "$CLAUDE_DIR/hooks/notetaker-buffer.sh"
rm -f "$CLAUDE_DIR/notetaker-kanban"

PATH_LINE='export PATH="$HOME/.claude/notetaker-kanban/bin:$PATH"'
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  grep -vF "$PATH_LINE" "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
done

echo "✓ Uninstalled. Per-repo .kanban/ directories are left in place — delete manually if desired."
