# Work Track Skill

Track engineering work from **Jira** and **GitHub** in one place. Generate individual or team activity reports with PR stats, ticket status, comments, and open items.

---

## What this skill showcases

| Source | What it tracks |
|--------|----------------|
| **Jira** | Assigned tickets, status transitions, comments, resolved vs open tickets |
| **GitHub** | PRs opened, merged, closed, reviews, currently open PRs |

### Report types

1. **Individual report** — “What did I do last 2 weeks?”
2. **Team report** — Leaderboard, per-member summary, team totals, stale/blocked items
3. **Active tickets** — Open Jira work for any team member (not Done/Closed)

### Example output

- Summary narrative of shipped work
- GitHub metrics table (opened / merged / open PRs)
- Jira metrics (resolved, transitions, comments, open tickets)
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

See **[INSTALL.md](INSTALL.md)** for full steps (Cursor, Claude CLI, Jira MCP, and GitHub-only mode).

## Setup — Cursor

1. **Copy the skill folder**

   ```bash
   mkdir -p ~/.cursor/skills/work-track
   cp -r /path/to/work_track_skill/* ~/.cursor/skills/work-track/
   ```

   Or drag `work_track_skill` contents into:

   ```
   ~/.cursor/skills/work-track/
   ```

2. **Configure your identity** — edit `config.json`:

   ```json
   "default_user": {
     "display_name": "Your Name",
     "jira_email": "you@cisco.com",
     "jira_username": "your_jira_user",
     "github_username": "your-github-id"
   }
   ```

3. **Set Jira projects** — in `config.json`:

   ```json
   "jira_projects": ["CAI", "YOUR_PROJECT"]
   ```

4. **Configure team** — edit `team.json`:
   - Update `team_name`
   - Add `jira_email` per member for full Jira tracking
   - Set `"active": false` to skip someone without deleting them

5. **Connect MCP (recommended for Jira)**
   - Configure **Jira MCP** in Cursor (e.g. `jira-sjc12` for Cisco Jira)
   - GitHub: use **`gh` CLI** (`gh auth login`) or GitHub MCP if available

6. **Use the skill**
   - Attach or invoke: `/work-track`
   - Or ask: *“Track my work for the last 2 weeks”*, *“Team work report”*

---

## Setup — Claude CLI (Claude Code)

1. **Install the skill**

   ```bash
   mkdir -p ~/.claude/skills/work-track
   cp -r /path/to/work_track_skill/* ~/.claude/skills/work-track/
   ```

2. **Auth — shell environment**

   ```bash
   export JIRA_BASE_URL=https://jira-eng-sjc12.cisco.com/jira
   export JIRA_USER_EMAIL=you@cisco.com
   export JIRA_API_TOKEN=your_token
   # Create token: https://id.atlassian.com/manage-profile/security/api-tokens

   gh auth login
   ```

3. **Edit `config.json` and `team.json`** (same as Cursor above)

4. **Restart Claude Code** so it discovers the new skill

5. **Example prompts**
   - *“Track my work last 14 days”*
   - *“Team work report last 2 weeks”*
   - *“What are the active tickets for Shreyas Sharma?”*
   - *“Add team member Alice, alice@cisco.com, github alice-dev”*

---

## Configuration reference

### `config.json`

| Field | Purpose |
|-------|---------|
| `default_user` | Who “my work” refers to |
| `defaults.period_days` | Default report window (14) |
| `defaults.jira_projects` | Project keys for team Jira scope |
| `defaults.jira_base_url` | Jira instance URL |
| `defaults.done_statuses` | Status names treated as complete |

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
| Personal report | *“Work track — last 2 weeks”* |
| Team report | *“Team work report last 2 weeks”* |
| Open Jira work | *“Active tickets for [name] — not Done”* |
| Add member | *“Add to work-track team: Raj, raj@cisco.com, rarajes2”* |
| Add Jira project | *“Add Jira project ENG to work-track”* |
| Show config | *“Show my work-track config”* |

---

## Requirements

| Tool | Purpose |
|------|---------|
| **Jira access** | MCP or `JIRA_API_TOKEN` + REST API |
| **GitHub CLI** | `gh auth login` — PR search and collaborator lists |
| **Cursor or Claude Code** | Loads skills from `~/.cursor/skills/` or `~/.claude/skills/` |

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
| Team member missing Jira stats | Add `jira_email` in `team.json` |
| Skill not triggering | Restart IDE/CLI; use explicit “work track” in prompt |
| Too many team members | Reports aggregate via repo searches; add emails for key people first |

---

## Author notes

Built for **Webex JS SDK & Widgets** team tracking (Jira `CAI`, repos `webex/webex-js-sdk`, `webex/widgets`). Customize `config.json` and `team.json` for your org and projects.

For detailed API patterns, see [reference.md](reference.md).
