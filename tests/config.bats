#!/usr/bin/env bats
load helpers

setup() { setup_temp_repo; source_lib; }
teardown() { teardown_temp_repo; }

@test "config_init creates .kanban/config.json with project_key" {
  config_init "github.com/me/foo" "http://localhost:3001" "main"
  [ -f .kanban/config.json ]
  run jq -r '.project_key' .kanban/config.json
  [ "$output" = "github.com/me/foo" ]
  run jq -r '.kanban_url' .kanban/config.json
  [ "$output" = "http://localhost:3001" ]
  run jq -r '.main_branch' .kanban/config.json
  [ "$output" = "main" ]
  run jq -r '.version' .kanban/config.json
  [ "$output" = "1" ]
}

@test "config_init creates .kanban/local.json with empty branch_card_map" {
  config_init "k" "http://x" "main"
  [ -f .kanban/local.json ]
  run jq -e '.branch_card_map' .kanban/local.json
  [ "$status" -eq 0 ]
}

@test "config_init appends .kanban/local.json to .gitignore (idempotent)" {
  config_init "k" "http://x" "main"
  config_init "k" "http://x" "main"   # second run no-op
  count=$(grep -c '^\.kanban/local\.json$' .gitignore)
  [ "$count" -eq 1 ]
}

@test "config_get_card_id returns empty for unmapped branch" {
  config_init "k" "http://x" "main"
  run config_get_card_id "feat/foo"
  [ -z "$output" ]
}

@test "config_set_card_id then config_get_card_id round-trips" {
  config_init "k" "http://x" "main"
  config_set_card_id "feat/foo" "c_42"
  run config_get_card_id "feat/foo"
  [ "$output" = "c_42" ]
}

@test "config_init is idempotent — second run preserves branch_card_map" {
  config_init "k" "http://x" "main"
  config_set_card_id "feat/foo" "c_42"
  config_init "k" "http://x" "main"
  run config_get_card_id "feat/foo"
  [ "$output" = "c_42" ]
}
