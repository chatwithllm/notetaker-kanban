# notetaker-kanban

Generic Claude Code → SmartKanban bridge. Records your dev work into a kanban board automatically, across any project, without you thinking about it.

## What it does

- `/kanban-start` in any Claude session creates a card from your branch's git history (LLM-summarized) and links it to the branch.
- Hooks watch your edits/prompts/bash and buffer them locally.
- `/kanban-flush` (or end-of-session) summarizes the buffer and posts an activity entry to the card.
- `/kanban-deployed-local`, `/kanban-deployed-prod`, `/kanban-feedback` mark milestones.
- `kanban-deploy local|prod -- ./your-deploy.sh` wraps deploy scripts and tags the card on success/fail.
- A SmartMirror tile (`tile-active-work`) reads back the in-flight cards.

## Requirements

- macOS or Linux. Claude Code installed.
- `git`, `curl`, `jq`. (`brew install jq` on macOS, `apt install jq` on Debian.)
- A SmartKanban instance with the Phase 1 PR (project column + api tokens). See [the design spec][spec].

[spec]: https://github.com/chatwithllm/SmartMirror/blob/main/docs/superpowers/specs/2026-04-27-notetaker-kanban-design.md

## Install

```bash
git clone <this-repo> ~/WorkingFolder/notetaker-kanban
cd ~/WorkingFolder/notetaker-kanban
./install.sh
```

Add to your shell rc (`~/.zshrc` or `~/.bashrc`):
```bash
export KANBAN_URL=http://localhost:3001
export KANBAN_TOKEN=<from SmartKanban Settings → API tokens>
```

Reload your shell or `source ~/.zshrc`.

## Usage

In any git repo, in a Claude Code session:

```
/kanban-start
```

That's it. From then on, the bridge tracks your work on this branch automatically.

Other commands:

| Command                       | What it does                                  |
|-------------------------------|-----------------------------------------------|
| `/kanban-doing`               | Move card to In Progress                      |
| `/kanban-today`               | Move card to Today                            |
| `/kanban-done`                | Manually mark Done                            |
| `/kanban-block <reason>`      | Tag #blocked + comment                        |
| `/kanban-unblock`             | Remove #blocked                               |
| `/kanban-deployed-local`      | Tag #deployed-local                           |
| `/kanban-deployed-prod`       | Tag #deployed-prod, status=done               |
| `/kanban-feedback <text>`     | Append feedback + tag #has-feedback           |
| `/kanban-comment <text>`      | Free-form comment                             |
| `/kanban-flush`               | Drain buffer → activity entry                 |
| `/kanban-buffer`              | Show buffer (debug)                           |
| `/kanban-link <id>`           | Bind branch to existing card                  |
| `/kanban-unlink`              | Remove branch ↔ card mapping                  |
| `/kanban-status`              | Project, branch, card, last flush, buffer     |
| `/kanban-list`                | List in-flight cards for current project      |
| `/kanban-pull <id>`           | Show full card detail                         |

Wrap deploy scripts:
```bash
kanban-deploy local -- ./scripts/deploy-local.sh
kanban-deploy prod  -- npm run deploy:prod
```

## Architecture

- `~/.claude/commands/kanban-*.md` — slash commands (user-level, fire in every Claude session).
- `~/.claude/hooks/notetaker-buffer.sh` — hook script (PostToolUse, UserPromptSubmit, Stop). Always exits 0; never blocks Claude.
- `~/.claude/notetaker-kanban` — symlink to this repo, used by hooks and slash commands to find `lib/`, `bin/`.
- Per-repo `.kanban/` directory:
  - `config.json` (committed) — project_key, kanban_url, main_branch.
  - `local.json` (gitignored) — branch ↔ card_id map, flush settings.
  - `buffer.jsonl` (gitignored) — raw event log, drained on flush.
- `~/.notetaker-kanban/repos.json` — registry of opted-in repos for the `--all` flush mode.

See [the design spec][spec] for the full architecture.

## Uninstall

```bash
./uninstall.sh
```

Per-repo `.kanban/` directories are left untouched.

## Tests

```bash
bats tests/ tests/integration/
```

## License

MIT — see LICENSE.
