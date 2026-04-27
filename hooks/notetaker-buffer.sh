#!/usr/bin/env bash
# hooks/notetaker-buffer.sh — invoked by Claude Code hooks.
# Always exits 0. Errors written to .kanban/buffer.errors.log.
set -u
event_type="${1:-unknown}"

# Read full hook event JSON from stdin (Claude provides it).
hook_input="$(cat)"

# Find repo root; bail if not in git.
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

# Bail if .kanban not bootstrapped.
[ -d "$repo_root/.kanban" ] || exit 0
[ -f "$repo_root/.kanban/local.json" ] || exit 0

LIB_DIR="${NOTETAKER_LIB_DIR:-$HOME/.claude/notetaker-kanban/lib}"
# shellcheck disable=SC1091
source "$LIB_DIR/buffer.sh" 2>/dev/null || exit 0
# shellcheck disable=SC1091
source "$LIB_DIR/config.sh" 2>/dev/null || exit 0

errlog="$repo_root/.kanban/buffer.errors.log"
log_err() { echo "[$(date -u +%FT%TZ)] $*" >> "$errlog" 2>/dev/null || true; }

branch="$(git -C "$repo_root" symbolic-ref --quiet --short HEAD 2>/dev/null)" || exit 0
[ -n "$branch" ] || exit 0
card_id="$(cd "$repo_root" && jq -r --arg b "$branch" '.branch_card_map[$b] // empty' .kanban/local.json 2>/dev/null)"
[ -n "$card_id" ] || exit 0

cd "$repo_root"

case "$event_type" in
  user_prompt)
    prompt="$(echo "$hook_input" | jq -r '.user_prompt // .prompt // ""' 2>/dev/null | head -c 500)"
    cwd="$(echo "$hook_input" | jq -r '.cwd // ""' 2>/dev/null)"
    payload="$(jq -cn --arg p "$prompt" --arg c "$cwd" '{prompt:$p, cwd:$c}')"
    buffer_append "user_prompt" "$branch" "$card_id" "$payload" 2>>"$errlog" || log_err "user_prompt append failed"
    ;;
  file_edit)
    tool="$(echo "$hook_input" | jq -r '.tool_name // .tool // ""' 2>/dev/null)"
    file="$(echo "$hook_input" | jq -r '.tool_input.file_path // .file_path // .params.file_path // ""' 2>/dev/null)"
    payload="$(jq -cn --arg t "$tool" --arg f "$file" '{tool:$t, file:$f}')"
    buffer_append "file_edit" "$branch" "$card_id" "$payload" 2>>"$errlog" || log_err "file_edit append failed"
    ;;
  bash_run)
    cmd="$(echo "$hook_input" | jq -r '.tool_input.command // .params.command // ""' 2>/dev/null | head -c 200)"
    cmd="$(buffer_redact "$cmd")"
    code="$(echo "$hook_input" | jq -r '.tool_response.exit_code // 0' 2>/dev/null)"
    payload="$(jq -cn --arg c "$cmd" --argjson e "$code" '{cmd:$c, exit_code:$e}')"
    buffer_append "bash_run" "$branch" "$card_id" "$payload" 2>>"$errlog" || log_err "bash_run append failed"
    ;;
  session_stop)
    buffer_append "session_stop" "$branch" "$card_id" '{}' 2>>"$errlog" || log_err "session_stop append failed"
    auto="$(jq -r '.flush.auto_on_stop // true' .kanban/local.json 2>/dev/null)"
    if [ "$auto" = "true" ]; then
      ( "$LIB_DIR/../bin/notetaker-flush" --background >/dev/null 2>&1 & disown ) || true
    fi
    ;;
  *)
    log_err "unknown event type: $event_type"
    ;;
esac

# Force flush if buffer too big.
size="$(buffer_size_bytes)"
max="$(jq -r '.flush.max_buffer_bytes // 10485760' .kanban/local.json 2>/dev/null || echo 10485760)"
if [ "$size" -gt "$max" ]; then
  ( "$LIB_DIR/../bin/notetaker-flush" --background >/dev/null 2>&1 & disown ) || true
fi

exit 0
