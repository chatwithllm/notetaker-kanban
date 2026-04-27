#!/usr/bin/env bats
load helpers

setup() {
  setup_temp_repo
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests*}"
  source "$REPO_ROOT/lib/config.sh"
  source "$REPO_ROOT/lib/buffer.sh"
  config_init "p" "http://x" "main"
  echo a > a; git add a; git commit -q -m init
  config_set_card_id "main" "c_1"
}
teardown() { teardown_temp_repo; }

@test "buffer_append writes one JSON line" {
  buffer_append "user_prompt" "main" "c_1" '{"prompt":"hello"}'
  run wc -l < .kanban/buffer.jsonl
  [ "$(echo $output | tr -d ' ')" = "1" ]
}

@test "buffer_append output is valid JSON with required keys" {
  buffer_append "user_prompt" "main" "c_1" '{"prompt":"hello"}'
  run jq -r '.event' .kanban/buffer.jsonl
  [ "$output" = "user_prompt" ]
  run jq -r '.branch' .kanban/buffer.jsonl
  [ "$output" = "main" ]
  run jq -r '.card_id' .kanban/buffer.jsonl
  [ "$output" = "c_1" ]
  run jq -r '.payload.prompt' .kanban/buffer.jsonl
  [ "$output" = "hello" ]
}

@test "buffer_append concurrent writes preserve all lines" {
  for i in $(seq 1 50); do
    buffer_append "x" "main" "c_1" "{\"i\":$i}" &
  done
  wait
  run wc -l < .kanban/buffer.jsonl
  [ "$(echo $output | tr -d ' ')" = "50" ]
  while read -r line; do
    echo "$line" | jq . > /dev/null || return 1
  done < .kanban/buffer.jsonl
}

@test "buffer_size_bytes reports current size" {
  buffer_append "x" "main" "c_1" '{}'
  run buffer_size_bytes
  [ "$output" -gt 0 ]
}
