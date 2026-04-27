# lib/git.sh
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
hash -r 2>/dev/null || true

git_current_branch() {
  local b
  b="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" || return 0
  echo "$b"
}

git_branch_commits_since_main() {
  local main_branch="${1:-main}"
  local base
  base="$(git merge-base HEAD "$main_branch" 2>/dev/null || true)"
  if [ -z "$base" ]; then
    git log --oneline
    return 0
  fi
  git log --oneline "${base}..HEAD"
}

git_branch_diffstat_since_main() {
  local main_branch="${1:-main}"
  local base
  base="$(git merge-base HEAD "$main_branch" 2>/dev/null || true)"
  if [ -z "$base" ]; then
    git diff --stat HEAD
    return 0
  fi
  git diff --stat "${base}...HEAD"
}
