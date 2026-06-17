# Work Track — Configuration Guide

Skill location: `~/.claude/skills/work-track/`

Edit these files directly, or ask Claude to update them (e.g. "add team member" or "add Jira project ENG").

## Files

| File | Purpose |
|------|---------|
| [config.json](config.json) | Default user, Jira projects, period, status names |
| [team.json](team.json) | Team name and member list for team reports |

---

## Jira projects (`config.json`)

Field: `defaults.jira_projects` — array of Jira project keys (all boards combined).

```json
"jira_projects": ["CAI", "ENG", "WXC"]
```

### Multiple Jira boards / instances (`jira_boards`)

Use `jira_boards[]` when teams use more than one Jira server or board:

```json
"jira_boards": [
  {
    "name": "CAI",
    "instance": "sjc12",
    "base_url": "https://jira-eng-sjc12.cisco.com/jira",
    "projects": ["CAI"],
    "mcp": "mcp_jira-sjc12"
  },
  {
    "name": "GPK",
    "instance": "gpk2",
    "base_url": "https://jira-eng-gpk2.cisco.com/jira",
    "rapid_view_id": 10147,
    "board_url": "https://jira-eng-gpk2.cisco.com/jira/secure/RapidBoard.jspa?rapidView=10147",
    "projects": ["YOUR_GPK_PROJECT_KEY"],
    "mcp": "mcp_jira-gpk2"
  }
]
```

After adding a board, also append its project key(s) to `defaults.jira_projects`.

**Add a project:** append the key to the array.

**Remove a project:** delete the key from the array.

JQL uses: `project in (CAI, ENG, WXC) AND updated >= "START"`

Also update `done_statuses` / `in_progress_statuses` if your workflow uses different status names.

---

## Team members (`team.json`)

```json
{
  "team_name": "Cypher Calling SDK",
  "members": [
    {
      "name": "Alice Example",
      "jira_email": "alice@cisco.com",
      "github_username": "alice-dev",
      "active": true
    }
  ]
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `name` | yes | Display name in reports |
| `jira_email` | no* | Required for Jira tracking; leave `""` until known |
| `github` | yes | GitHub username |
| `active` | no | Default `true`; set `false` to skip without deleting |

---

## Auth (Claude CLI)

Set in shell profile or `.env` (never commit tokens):

```bash
export JIRA_BASE_URL=https://jira-eng-sjc12.cisco.com/jira
export JIRA_USER_EMAIL=vinvivek@cisco.com
export JIRA_API_TOKEN=your_token   # https://id.atlassian.com/manage-profile/security/api-tokens
gh auth login                      # GitHub via gh CLI
```

If Jira MCP is configured in Claude Code, MCP can be used instead of env tokens.

---

## Cursor MCP — dual Jira setup

| MCP name | Use for | Instance |
|----------|---------|----------|
| `jira-sjc12` | CAI board | `jira-eng-sjc12` |
| `jira` | GPK / SPARK board | `jira-eng-gpk2` |

**GPK MCP config (Cursor → Settings → MCP):**

| Field | Value |
|-------|-------|
| Name | `jira` |
| Type | `http` |
| URL | `https://aicoding-mcp.cisco.com/jira/` |
| Header | `X-JIRA-TOKEN: <your-token>` |

**Never** put the token in `config.json`, `team.json`, or git. Store it only in Cursor MCP settings.

SPARK uses different statuses (`Ready`, `Verification`, `New`, `In Progress`, `Code Complete`). Active = not `Done` / `Closed` / `Resolved`.

---

## Example prompts in Claude CLI

- "Track my work for the last 2 weeks"
- "Team work report"
- "Add team member Raj, raj@cisco.com, github raj-k"
- "Add Jira project ENG to work-track"
- "Show work-track config"
