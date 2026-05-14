---
description: "Bootstrap or resume kanban tracking for the current branch. Reads git history, summarizes via LLM, creates a card."
allowed-tools: ["Bash", "Read", "Edit", "Write"]
---

# /kanban-start

You are about to bootstrap kanban tracking for the current branch in this repo (or resume tracking on an existing card if already linked).

## Steps you must follow exactly:

1. Source the bridge libs:
   ```bash
   export NOTETAKER_LIB_DIR="${NOTETAKER_LIB_DIR:-$HOME/.claude/notetaker-kanban/lib}"
   source "$NOTETAKER_LIB_DIR/config.sh"
   source "$NOTETAKER_LIB_DIR/git.sh"
   source "$NOTETAKER_LIB_DIR/api.sh"
   ```

2. Verify environment:
   ```bash
   [ -n "${KANBAN_URL:-}" ]   || { echo "Set KANBAN_URL in your shell rc"; exit 1; }
   [ -n "${KANBAN_TOKEN:-}" ] || { echo "Set KANBAN_TOKEN in your shell rc (Settings → API tokens)"; exit 1; }
   git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "not in a git repo"; exit 1; }
   ```

3. Detect current branch. If detached HEAD, abort.
   ```bash
   BRANCH="$(git_current_branch)"
   [ -n "$BRANCH" ] || { echo "detached HEAD — checkout a branch first"; exit 1; }
   ```

4. If `.kanban/config.json` doesn't exist, bootstrap:
   ```bash
   if [ ! -f "$(config_dir)/config.json" ]; then
     PK="$(config_project_key)"
     config_init "$PK" "$KANBAN_URL" "main"
     mkdir -p "$HOME/.notetaker-kanban"
     REG="$HOME/.notetaker-kanban/repos.json"
     [ -f "$REG" ] || echo '{"repos":[]}' > "$REG"
     ROOT="$(git rev-parse --show-toplevel)"
     jq --arg p "$ROOT" --arg pk "$PK" --arg ts "$(date -u +%FT%TZ)" \
       '.repos += [{path:$p, project_key:$pk, added:$ts}] | .repos |= unique_by(.path)' \
       "$REG" > "$REG.tmp" && mv "$REG.tmp" "$REG"
   fi
   ```

5. Check for an existing branch→card mapping:
   ```bash
   EXISTING="$(config_get_card_id "$BRANCH")"
   if [ -n "$EXISTING" ]; then
     echo "Branch '$BRANCH' already linked to card $EXISTING."
     echo "View: $KANBAN_URL  (open the board)"
     exit 0
   fi
   ```

6. Read git history since merge-base with main:
   ```bash
   MAIN="$(config_main_branch)"
   COMMITS="$(git_branch_commits_since_main "$MAIN")"
   DIFFSTAT="$(git_branch_diffstat_since_main "$MAIN")"
   ```

7. Now YOU (the LLM) propose a kanban card by analyzing the commits and diffstat above. Output a JSON object with these exact keys:
   ```json
   {
     "title": "<imperative, ≤60 chars>",
     "description": "<2-4 sentences>",
     "tags": ["<lowercase-kebab>", ...],
     "status": "today",
     "needs_review": false
   }
   ```

   - `status` must be one of: `backlog`, `today`, `in_progress`, `done` (snake_case).
   - If there are no commits on the branch, ask the user: "What is this branch for?" and use their answer as the title; status=`today`.

8. Show the JSON to the user. Ask: "OK to create? You can edit any field." Wait for explicit confirmation before continuing.

9. POST to kanban:
   ```bash
   PROJECT="$(config_project_key)"
   PAYLOAD="$(jq -cn --arg t "$TITLE" --arg d "$DESC" --argjson tg "$TAGS_JSON" --arg s "$STATUS" --arg p "$PROJECT" \
     '{title:$t, description:$d, tags:$tg, status:$s, project:$p, source:"manual"}')"
   CARD_ID="$(api_create_card "$PAYLOAD")"
   [ -n "$CARD_ID" ] || { echo "create failed"; exit 1; }
   config_set_card_id "$BRANCH" "$CARD_ID"
   api_announce_branch_link "$CARD_ID" "$BRANCH"
   echo "✓ Created card $CARD_ID for branch $BRANCH"
   echo "  Project: $PROJECT"
   echo "  $KANBAN_URL"
   ```

10. Print final summary to user.

## Failure handling

- If any step fails, print the failing command's output and exit non-zero.
- Never delete `.kanban/local.json` or rewrite committed `config.json`.
- If POST returns 401 or 403: tell user "Token rejected — generate new one in Settings → API tokens" and exit.
