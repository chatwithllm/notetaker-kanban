# lib/config.sh
# Helpers for reading and writing the per-repo .kanban/ config files.

config_dir() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
  echo "$root/.kanban"
}

config_init() {
  local project_key="$1"
  local kanban_url="$2"
  local main_branch="${3:-main}"
  local dir
  dir="$(config_dir)" || { echo "not a git repo" >&2; return 1; }
  mkdir -p "$dir"

  if [ ! -f "$dir/config.json" ]; then
    jq -n \
      --arg pk "$project_key" \
      --arg ku "$kanban_url" \
      --arg mb "$main_branch" \
      '{ version: 1, project_key: $pk, kanban_url: $ku, main_branch: $mb }' \
      > "$dir/config.json"
  fi

  if [ ! -f "$dir/local.json" ]; then
    jq -n \
      '{
        branch_card_map: {},
        last_flush: null,
        flush: { auto_on_stop: true, max_buffer_lines: 5000, max_buffer_bytes: 10485760 },
        redact: { env_var_patterns: ["TOKEN","SECRET","KEY","PASSWORD","API_KEY"] }
      }' > "$dir/local.json"
  fi

  local gi
  gi="$(git rev-parse --show-toplevel)/.gitignore"
  touch "$gi"
  for line in ".kanban/local.json" ".kanban/buffer.jsonl" ".kanban/buffer.errors.log" ".kanban/flush.log" ".kanban/pending-milestones.jsonl"; do
    if ! grep -qxF "$line" "$gi"; then
      echo "$line" >> "$gi"
    fi
  done
}

config_project_key() {
  local dir; dir="$(config_dir)" || return 1
  if [ -f "$dir/config.json" ]; then
    local pk
    pk="$(jq -r '.project_key // empty' "$dir/config.json")"
    if [ -n "$pk" ]; then echo "$pk"; return 0; fi
  fi
  local git_pk
  git_pk="$(git config --get notetaker.project 2>/dev/null)"
  if [ -n "$git_pk" ]; then echo "$git_pk"; return 0; fi
  local origin
  origin="$(git config --get remote.origin.url 2>/dev/null)"
  if [ -n "$origin" ]; then
    echo "$origin" | sed -E 's|^[a-z]+://||; s|^git@||; s|:|/|; s|\.git$||' | tr '[:upper:]' '[:lower:]'
    return 0
  fi
  basename "$(git rev-parse --show-toplevel)"
}

config_get_card_id() {
  local branch="$1"
  local dir; dir="$(config_dir)" || return 1
  jq -r --arg b "$branch" '.branch_card_map[$b] // empty' "$dir/local.json"
}

config_set_card_id() {
  local branch="$1"
  local card_id="$2"
  local dir; dir="$(config_dir)" || return 1
  local tmp="$dir/local.json.tmp.$$"
  jq --arg b "$branch" --arg c "$card_id" \
    '.branch_card_map[$b] = $c' \
    "$dir/local.json" > "$tmp"
  mv "$tmp" "$dir/local.json"
}

config_unset_card_id() {
  local branch="$1"
  local dir; dir="$(config_dir)" || return 1
  local tmp="$dir/local.json.tmp.$$"
  jq --arg b "$branch" 'del(.branch_card_map[$b])' \
    "$dir/local.json" > "$tmp"
  mv "$tmp" "$dir/local.json"
}

config_kanban_url() { jq -r '.kanban_url' "$(config_dir)/config.json"; }
config_main_branch() { jq -r '.main_branch' "$(config_dir)/config.json"; }
