# Work Track Skill

Track engineering work from **Jira**, **GitHub**, read-only **Confluence**, and mandatory **Webex CLI** context in one place. Generate individual or team work summaries and action items with PR stats, ticket status, Confluence pages/comments/mentions, meetings, messages, live transcripts, unanswered questions, and follow-ups.

This skill must be installed and configured for **both Claude Code and Codex**. Keep `config.json` and `team.json` in sync across both runtimes so the same user/team/report inputs produce the same output.

---

## What this skill showcases

| Source | What it tracks |
|--------|----------------|
| **Jira** | Assigned tickets, status transitions, comments, resolved vs open tickets |
| **GitHub** | PRs opened, merged, closed, reviews, currently open PRs |
| **Confluence** | Read-only pages, comments, mentions, decisions, docs, action items |
| **Webex CLI** | Spaces/messages, team check-ins, unanswered questions, meetings, live transcripts, artifacts, linked Jira/Confluence context |

### Report types

1. **Individual report** — “What did I do this week?”
2. **Team report** — Leaderboard, per-member summary, team totals, stale/blocked items
3. **Webex catch-up** — Meetings, message threads, unanswered questions, action items, linked Jira/Confluence items
4. **Full-context report** — Jira + GitHub + Confluence + Webex context for a person, CEC ID, or team
5. **Team check-in report** — Work summary and action items from team spaces

### Date period modes

| Mode | Use | Default range |
|------|-----|---------------|
| **Weekly** | Input for Teamspace skill | 7 days |
| **Bi-weekly** | Input for bi-weekly sync skill | 14 days |
| **Custom** | Ad hoc user-supplied date range | Explicit start/end dates |

### Example output

- Summary narrative of shipped work
- GitHub metrics table (opened / merged / open PRs, lines added/deleted, large PRs)
- GitHub PR rows with modification stats shown like GitHub, e.g. `+1411 -10, 5 files`
- Jira metrics (resolved, transitions, comments, open tickets)
- Confluence pages/comments/mentions with read-only action-item extraction
- Webex meetings/messages with decisions, blockers, and action items
- Work summary and action items from team check-in spaces
- PR review friction from code review spaces correlated with GitHub PR size/status
- Highlights and “needs attention” (stale PRs or tickets idle 3+ days)
- Team leaderboard ranked by merges and Jira resolution

---

## Folder contents

```
work_track_skill/
├── README.md        ← Overview
├── INSTALL.md       ← Step-by-step install (start here for new users)
├── SKILL.md         ← Agent instructions (required for the skill)
├── config.json      ← Default user, Jira projects, URLs, period
├── team.json        ← Team roster (GitHub + optional Jira emails)
├── CONFIG.md        ← How to add members and Jira projects
└── reference.md     ← Jira JQL, gh CLI, API examples
```

---

## Quick install

See **[INSTALL.md](INSTALL.md)** for full steps (Claude Code, Codex, Jira MCP, GitHub CLI, Confluence client, and Webex CLI).

## Mandatory setup — Claude Code and Codex

Install/configure the skill in both runtime locations:

```bash
mkdir -p ~/.claude/skills/work-track
mkdir -p ~/.agents/skills/work-track
cp -r /path/to/work_track_skill/skills/* ~/.claude/skills/work-track/
cp -r /path/to/work_track_skill/skills/* ~/.agents/skills/work-track/
```

Then edit both `config.json` files, or run `skills/install.sh` and copy the same configured files into both destinations:

- Claude Code: `~/.claude/skills/work-track/config.json`
- Codex: `~/.agents/skills/work-track/config.json`

1. **Configure your identity**:

   ```json
   "default_user": {
     "display_name": "Your Name",
     "jira_email": "you@cisco.com",
     "jira_username": "your_jira_user",
     "github_username": "your-github-id"
   }
   ```

2. **Set Jira projects** — in `config.json`:

   ```json
   "jira_projects": ["CAI", "YOUR_PROJECT"]
   ```

4. **Configure team** — edit `team.json`:
   - Update `team_name`
   - Add `jira_email` per member for full Jira tracking
   - Set `"active": false` to skip someone without deleting them

5. **Connect source tools in both runtimes**
   - Claude Code: configure Jira MCP with `claude mcp add` and verify with `claude mcp list`
   - Codex: verify the Jira/GitHub/Webex/Confluence tools or skills are visible in the Codex session
   - GitHub: use **`gh` CLI** (`gh auth login`) or GitHub MCP if available

6. **Use the skill**
   - Attach or invoke: `/work-track`
   - Or ask: *“Track my weekly work”*, *“Team work report”*

---

## Example prompts

- *“Track my weekly work”*
- *“Team work report for Teamspace this week”*
- *“Track my bi-weekly work for sync”*
- *“Work report for Shreyas with Confluence and Webex action items”*
- *“Add team member Alice, alice@cisco.com, github alice-dev”*

---

## Configuration reference

### `config.json`

| Field | Purpose |
|-------|---------|
| `default_user` | Who “my work” refers to |
| `defaults.period_mode` | Default period mode; `weekly` |
| `defaults.period_days` | Default report window for `weekly`; `7` |
| `periods.weekly` | Weekly data configuration for Teamspace skill input |
| `periods.bi_weekly` | Bi-weekly data configuration for bi-weekly sync skill input |
| `periods.custom` | Custom date-range configuration for ad hoc reports |
| `defaults.jira_projects` | Project keys for team Jira scope |
| `defaults.jira_base_url` | Jira instance URL |
| `defaults.done_statuses` | Status names treated as complete |
| `github.show_modification_lines` | Show `+additions -deletions` beside every PR |
| `github.show_changed_files` | Show changed file count beside every PR |
| `github.large_pr_lines` | Changed-line threshold for large PR reporting; default is `1500` |
| `confluence.enabled` | Enables read-only Confluence context |
| `confluence.read_only` | Must stay `true`; work-track must never write to Confluence |
| `confluence.search_pages` | Search pages created/updated by the user |
| `confluence.search_comments` | Search comments by or mentioning the user |
| `confluence.search_mentions` | Search mentions/tags of the user |
| `confluence.search_action_items` | Extract Confluence TODOs/follow-ups/action items |
| `webex.enabled` | Enables Webex context |
| `webex.required` | Webex CLI is mandatory for standard work-track reports |
| `webex.include_by_default` | Include Webex in regular work reports; default is `true` |
| `webex.timezone` | Timezone for meeting/date routing |
| `webex.spaces` | Space categories used for team check-ins, code reviews, releases, blockers, and general catch-up |
| `webex.pr_review_thresholds.large_pr_lines` | PR size threshold for review-friction/action-item detection; default is `1500` changed lines |

### `team.json`

| Field | Purpose |
|-------|---------|
| `team_name` | Title on team reports |
| `jira_base_url` | Used by batch fetch scripts |
| `github_scope` | e.g. `webex/*` |
| `members[].name` | Display name |
| `members[].github` | GitHub username |
| `members[].jira_email` | Required for per-person Jira stats |
| `members[].active` | `false` to exclude from team reports |

See [CONFIG.md](CONFIG.md) for add/update examples.

---

## Populating the team from GitHub

To load collaborators from repos (example):

```bash
gh api repos/webex/webex-js-sdk/collaborators --paginate -q '.[].login' | sort -u
gh api repos/webex/widgets/collaborators --paginate -q '.[].login' | sort -u
```

Merge lists, exclude bot accounts, then add each person to `team.json` with `jira_email` filled in over time.

---

## Example prompts

| Goal | Prompt |
|------|--------|
| Personal report | *“Work track — this week”* |
| Weekly Teamspace input | *“Work track weekly data for teamspace”* |
| Bi-weekly sync input | *“Work track bi-weekly data for sync”* |
| Custom date range | *“Work report for Shreyas from 2026-06-01 to 2026-06-15”* |
| Team report | *“Team work report this week”* |
| Webex catch-up | *“Webex catch-up for shreysh2 yesterday”* |
| Full context | *“Work report for Shreyas this week with Confluence, Webex meetings, and unanswered questions”* |
| Confluence context | *“Include Confluence pages, comments, mentions, and action items for Shreyas this week”* |
| Team check-in | *“Summarize team check-in work summary and action items from Webex spaces this week”* |
| PR review friction | *“Check code review spaces and flag PRs that are too large to review”* |
| Add member | *“Add to work-track team: Raj, raj@cisco.com, rarajes2”* |
| Add Jira project | *“Add Jira project ENG to work-track”* |
| Show config | *“Show my work-track config”* |

---

## Requirements

| Tool | Purpose |
|------|---------|
| **Jira access** | MCP or `JIRA_API_TOKEN` + REST API |
| **GitHub CLI** | `gh auth login` — PR search and collaborator lists |
| **Confluence client skill** | Optional read-only source — pages, comments, mentions, action items |
| **Webex CLI skill** | Required — messaging catch-up, meetings, live transcripts, artifacts, calendar routing, team check-ins |
| **Claude Code and Codex** | Both are mandatory: `~/.claude/skills/work-track/` and `~/.agents/skills/work-track/` |

Optional: Python scripts from `productivity-tracker` skill (`~/.claude/skills/productivity-tracker/scripts/`) for offline/batch fetch — see [reference.md](reference.md).

---

## Sharing this package

1. Zip the `work_track_skill` folder (exclude personal tokens).
2. Recipients copy files into their skills directory.
3. Each person updates `config.json` with their Jira email and GitHub username.
4. Trim or replace `team.json` with their own team roster.
5. Remove or anonymize `team.json` members if sharing outside your org.

**Do not commit** `JIRA_API_TOKEN` or other secrets into these JSON files.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| No Jira data | Set `JIRA_API_TOKEN` or enable Jira MCP |
| GitHub MCP 401 | Use `gh` CLI for github.com instead |
| No Confluence data | Install/enable `confluence-client`; report continues with partial data |
| No Webex data | Install/enable the internal Webex CLI skill and authenticate using its setup flow; standard reports are incomplete without it |
| Team member missing Jira stats | Add `jira_email` in `team.json` |
| Skill not triggering | Restart IDE/CLI; use explicit “work track” in prompt |
| Too many team members | Reports aggregate via repo searches; add emails for key people first |

---

## Author notes

Built for **Webex JS SDK & Widgets** team tracking (Jira `CAI`, repos `webex/webex-js-sdk`, `webex/widgets`). Customize `config.json` and `team.json` for your org and projects.

For detailed API patterns, see [reference.md](reference.md).
