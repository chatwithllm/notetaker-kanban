# lib/tools.sh — locate jq/curl/git absolute paths once. Sourced by every other lib.
for _d in /opt/homebrew/bin /usr/local/bin /usr/bin /bin; do
  [ -z "${JQ:-}" ]   && [ -x "$_d/jq" ]   && JQ="$_d/jq"
  [ -z "${CURL:-}" ] && [ -x "$_d/curl" ] && CURL="$_d/curl"
  [ -z "${GIT:-}" ]  && [ -x "$_d/git" ]  && GIT="$_d/git"
done
JQ="${JQ:-jq}"
CURL="${CURL:-curl}"
GIT="${GIT:-git}"
export JQ CURL GIT
unset _d
