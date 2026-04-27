# lib/tools.sh — locate jq/curl absolute paths once, expose as $JQ and $CURL.
# Sourced by every other lib so the bridge works in shells with stripped PATH.
for _d in /opt/homebrew/bin /usr/local/bin /usr/bin /bin; do
  [ -z "${JQ:-}" ]   && [ -x "$_d/jq" ]   && JQ="$_d/jq"
  [ -z "${CURL:-}" ] && [ -x "$_d/curl" ] && CURL="$_d/curl"
done
JQ="${JQ:-jq}"
CURL="${CURL:-curl}"
export JQ CURL
unset _d
