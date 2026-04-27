#!/usr/bin/env bats
load helpers

setup() {
  setup_temp_repo
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests*}"
  source "$REPO_ROOT/lib/git.sh"
}
teardown() { teardown_temp_repo; }

@test "git_current_branch returns checked-out branch" {
  echo x > a; git add a; git commit -q -m init
  git checkout -q -b feat/foo
  run git_current_branch
  [ "$output" = "feat/foo" ]
}

@test "git_current_branch returns empty on detached HEAD" {
  echo x > a; git add a; git commit -q -m init
  local sha; sha="$(git rev-parse HEAD)"
  git checkout -q "$sha"
  run git_current_branch
  [ -z "$output" ]
}

@test "git_branch_commits_since_main returns commits on branch only" {
  echo a > a; git add a; git commit -q -m "first on main"
  git checkout -q -b feat/work
  echo b > b; git add b; git commit -q -m "feat: add b"
  echo c > c; git add c; git commit -q -m "feat: add c"
  run git_branch_commits_since_main "main"
  [[ "$output" = *"feat: add b"* ]]
  [[ "$output" = *"feat: add c"* ]]
  [[ "$output" != *"first on main"* ]]
}
