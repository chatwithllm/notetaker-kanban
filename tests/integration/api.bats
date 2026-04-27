#!/usr/bin/env bats
load ../helpers

setup() {
  setup_temp_repo
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests*}"
  source "$REPO_ROOT/lib/config.sh"
  source "$REPO_ROOT/lib/api.sh"
  start_mock_kanban
  config_init "p1" "$MOCK_KANBAN_URL" "main"
  export KANBAN_TOKEN="test-token"
}
teardown() { stop_mock_kanban; teardown_temp_repo; }

@test "api_create_card sends Bearer header and returns id" {
  result="$(api_create_card '{"title":"hi","project":"p1"}')"
  [ "$result" = "c_mock" ]
  grep -q "Bearer test-token" "$MOCK_KANBAN_LOG"
}

@test "api_post_activity hits /activity endpoint" {
  api_post_activity "c_42" "session_summary" "edited 3 files" '{"files":3}'
  grep -q '/api/cards/c_42/activity' "$MOCK_KANBAN_LOG"
}

@test "api_add_tags reads + unions + PATCHes" {
  api_add_tags "c_mock" "deployed-local" "blocked"
  sleep 0.1
  # mock server returns tags=["a","b"]; verify a PATCH was sent containing the merged set
  grep -q '"method": "PATCH"' "$MOCK_KANBAN_LOG"
  # the request body should contain the union (order-insensitive)
  grep '"method": "PATCH"' "$MOCK_KANBAN_LOG" | tail -1 | jq -e '.body | fromjson | .tags | sort == ["a","b","blocked","deployed-local"]'
}

@test "api_remove_tag drops a tag from the array" {
  # mock returns tags=["a","b"]; remove "a"
  api_remove_tag "c_mock" "a"
  sleep 0.1
  grep '"method": "PATCH"' "$MOCK_KANBAN_LOG" | tail -1 | jq -e '.body | fromjson | .tags == ["b"]'
}
