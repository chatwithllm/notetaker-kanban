# lib/buffer.sh
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
hash -r 2>/dev/null || true
source "${BASH_SOURCE%/*}/tools.sh" 2>/dev/null || source "$(dirname "${(%):-%x}")/tools.sh" 2>/dev/null || true
# Atomic JSONL append helpers and redaction utilities.

buffer_truncate() {
  local s="$1"
  local max="${2:-500}"
  printf '%.*s' "$max" "$s"
}

buffer_redact() {
  local input="$1"
  echo "$input" | sed -E 's/([A-Za-z_]*(TOKEN|SECRET|KEY|PASSWORD|API_KEY)[A-Za-z_]*)=[^[:space:]]+/\1=<redacted>/g'
}

buffer_append() {
  local event="$1"
  local branch="$2"
  local card_id="$3"
  local payload_json="$4"

  local root
  root="$( "$GIT" rev-parse --show-toplevel 2>/dev/null)" || return 0
  local dir="$root/.kanban"
  [ -d "$dir" ] || return 0

  local buffile="$dir/buffer.jsonl"
  local lockfile="$dir/buffer.lock"

  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local line
  line="$( "$JQ" -cn \
    --arg ts "$ts" \
    --arg event "$event" \
    --arg branch "$branch" \
    --arg card_id "$card_id" \
    --argjson payload "$payload_json" \
    '{ts:$ts, event:$event, branch:$branch, card_id:$card_id, payload:$payload}')"

  # Write to a per-process temp file first, then append under an advisory lock
  # so concurrent subshells don't interleave partial writes.
  local tmp
  tmp="$(mktemp "$dir/.buf.XXXXXX")"
  printf '%s\n' "$line" > "$tmp"

  # lockf(1) is available on macOS/BSD; it serialises the append step.
  if command -v lockf >/dev/null 2>&1; then
    lockf -s "$lockfile" sh -c "cat '$tmp' >> '$buffile'"
  else
    # Fallback: spin on a lock directory (mkdir is atomic on POSIX).
    local lockdir="$dir/buffer.lockdir"
    local waited=0
    until mkdir "$lockdir" 2>/dev/null; do
      sleep 0.05
      waited=$(( waited + 1 ))
      [ "$waited" -lt 200 ] || break   # give up after 10 s
    done
    cat "$tmp" >> "$buffile"
    rmdir "$lockdir" 2>/dev/null || true
  fi

  rm -f "$tmp"
}

buffer_size_bytes() {
  local root
  root="$( "$GIT" rev-parse --show-toplevel 2>/dev/null)" || { echo 0; return; }
  local f="$root/.kanban/buffer.jsonl"
  if [ -f "$f" ]; then
    wc -c < "$f" | tr -d ' '
  else
    echo 0
  fi
}

buffer_truncate_file() {
  local root
  root="$( "$GIT" rev-parse --show-toplevel 2>/dev/null)" || return 1
  : > "$root/.kanban/buffer.jsonl"
}
