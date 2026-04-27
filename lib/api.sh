# lib/api.sh
# curl-based kanban API client.
# Requires: config.sh sourced (for config_kanban_url).
# Env: KANBAN_TOKEN — Bearer token sent with every request.

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

api_token() {
  echo "${KANBAN_TOKEN:-}"
}

# _api_curl <method> <path> [body-json]
# Performs the HTTP request and writes the response body to stdout.
# Exits non-zero if curl fails or the server returns 4xx/5xx.
_api_curl() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local base_url
  base_url="$(config_kanban_url)"
  local token
  token="$(api_token)"

  local args=(
    -s
    -S
    -X "$method"
    -H "Authorization: Bearer $token"
    -H "Content-Type: application/json"
    -H "Accept: application/json"
    --fail-with-body
  )

  if [ -n "$body" ]; then
    args+=(-d "$body")
  fi

  curl "${args[@]}" "${base_url}${path}"
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# api_create_card <json-body>
# POST /api/cards — creates a new card and returns its id.
api_create_card() {
  local body="$1"
  local response
  response="$(_api_curl POST /api/cards "$body")" || return 1
  echo "$response" | jq -r '.id'
}

# api_get_card <card-id>
# GET /api/cards/<id> — returns the full card JSON.
api_get_card() {
  local card_id="$1"
  _api_curl GET "/api/cards/${card_id}"
}

# api_patch_card <card-id> <json-patch-body>
# PATCH /api/cards/<id> — partial update; returns updated card JSON.
api_patch_card() {
  local card_id="$1"
  local body="$2"
  _api_curl PATCH "/api/cards/${card_id}" "$body"
}

# api_post_activity <card-id> <type> <summary> [metadata-json]
# POST /api/cards/<id>/activity — appends an activity entry.
api_post_activity() {
  local card_id="$1"
  local activity_type="$2"
  local summary="$3"
  local metadata="${4}"
  [ -z "$metadata" ] && metadata='{}'

  local body
  body="$(jq -n \
    --arg t "$activity_type" \
    --arg s "$summary" \
    --argjson m "$metadata" \
    '{ type: $t, summary: $s, metadata: $m }')"

  _api_curl POST "/api/cards/${card_id}/activity" "$body"
}
