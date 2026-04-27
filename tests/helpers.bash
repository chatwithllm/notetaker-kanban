setup_temp_repo() {
  TMP_REPO="$(mktemp -d)"
  cd "$TMP_REPO"
  git init -q
  git config user.email t@t.local
  git config user.name t
}

teardown_temp_repo() {
  cd /
  rm -rf "$TMP_REPO"
}

# Source library files relative to repo root.
source_lib() {
  REPO_ROOT="${BATS_TEST_DIRNAME%/tests*}"
  source "$REPO_ROOT/lib/config.sh"
}
