# lib/git.sh
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
hash -r 2>/dev/null || true
source "${BASH_SOURCE%/*}/tools.sh" 2>/dev/null || source "$(dirname "${(%):-%x}")/tools.sh" 2>/dev/null || true

git_current_branch() {
  local b
  b="$( "$GIT" symbolic-ref --quiet --short HEAD 2>/dev/null)" || return 0
  echo "$b"
}

git_branch_commits_since_main() {
  local main_branch="${1:-main}"
  local base
  base="$( "$GIT" merge-base HEAD "$main_branch" 2>/dev/null || true)"
  if [ -z "$base" ]; then
    "$GIT" log --oneline
    return 0
  fi
  "$GIT" log --oneline "${base}..HEAD"
}

git_branch_diffstat_since_main() {
  local main_branch="${1:-main}"
  local base
  base="$( "$GIT" merge-base HEAD "$main_branch" 2>/dev/null || true)"
  if [ -z "$base" ]; then
    "$GIT" diff --stat HEAD
    return 0
  fi
  "$GIT" diff --stat "${base}...HEAD"
}
