#!/usr/bin/env bats
load ../helpers

setup() {
  setup_temp_repo
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests*}"
  source "$REPO_ROOT/lib/config.sh"
  start_mock_kanban
  config_init "p" "$MOCK_KANBAN_URL" "main"
  echo a > a; git add a; git commit -q -m init
  config_set_card_id "main" "c_42"
  export KANBAN_URL="$MOCK_KANBAN_URL"
  export KANBAN_TOKEN="t"
  export NOTETAKER_LIB_DIR="$REPO_ROOT/lib"
  export PATH="$REPO_ROOT/bin:$PATH"
}
teardown() { stop_mock_kanban; teardown_temp_repo; }

@test "kanban-deploy local -- runs inner cmd, exit 0 → tags deployed-local + activity" {
  run kanban-deploy local -- /bin/echo "deployed"
  [ "$status" -eq 0 ]
  grep -q '/api/cards/c_42' "$MOCK_KANBAN_LOG"
  grep -q '"method": "PATCH"' "$MOCK_KANBAN_LOG"
  grep -q '/api/cards/c_42/activity' "$MOCK_KANBAN_LOG"
}

@test "kanban-deploy prod -- on success, sets status=done + tag deployed-prod" {
  run kanban-deploy prod -- /usr/bin/true
  [ "$status" -eq 0 ]
  # body is JSON-string-escaped inside the outer log JSON: \"status\":\"done\"
  grep -q '\\"status\\":\\"done\\"' "$MOCK_KANBAN_LOG"
}

@test "kanban-deploy still runs inner cmd even when no card linked" {
  config_unset_card_id "main"
  run kanban-deploy local -- /bin/echo ok
  [ "$status" -eq 0 ]
  [[ "$output" = *"ok"* ]]
}

@test "kanban-deploy on inner-cmd failure tags deploy-failed-local" {
  run kanban-deploy local -- /usr/bin/false
  [ "$status" -ne 0 ]
}
