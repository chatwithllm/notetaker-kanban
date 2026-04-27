#!/usr/bin/env bats
load ../helpers

setup() {
  setup_temp_repo
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests*}"
  source "$REPO_ROOT/lib/config.sh"
  source "$REPO_ROOT/lib/buffer.sh"
  start_mock_kanban
  config_init "p" "$MOCK_KANBAN_URL" "main"
  echo a > a; git add a; git commit -q -m init
  config_set_card_id "main" "c_42"
  export KANBAN_TOKEN="test-token"
  export NOTETAKER_LIB_DIR="$REPO_ROOT/lib"
  export NOTETAKER_NO_LLM=1
}
teardown() { stop_mock_kanban; teardown_temp_repo; }

@test "notetaker-flush posts activity entries and truncates the buffer" {
  buffer_append "user_prompt" "main" "c_42" '{"prompt":"add wake word"}'
  buffer_append "file_edit"   "main" "c_42" '{"tool":"Edit","file":"src/wake.ts"}'
  buffer_append "file_edit"   "main" "c_42" '{"tool":"Edit","file":"src/wake.ts"}'
  buffer_append "bash_run"    "main" "c_42" '{"cmd":"npm test","exit_code":0}'
  buffer_append "session_stop" "main" "c_42" '{}'

  run "$REPO_ROOT/bin/notetaker-flush"
  [ "$status" -eq 0 ]

  size="$(wc -c < .kanban/buffer.jsonl | tr -d ' ')"
  [ "$size" = "0" ]

  grep -q '/api/cards/c_42/activity' "$MOCK_KANBAN_LOG"
}

@test "notetaker-flush handles empty buffer gracefully" {
  : > .kanban/buffer.jsonl
  run "$REPO_ROOT/bin/notetaker-flush"
  [ "$status" -eq 0 ]
}
