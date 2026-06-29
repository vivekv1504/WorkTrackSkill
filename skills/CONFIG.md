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
    "mcp": "mcp_jira"
  }
]
```

After adding a board, also append its project key(s) to `defaults.jira_projects`.

**Add a project:** append the key to the array.

**Remove a project:** delete the key from the array.

JQL uses: `project in (CAI, ENG, WXC) AND updated >= "START"`

Also update `done_statuses` / `in_progress_statuses` if your workflow uses different status names.

---

## Date periods (`config.json`)

Work-track supports three period modes:

```json
"defaults": {
  "period_mode": "weekly",
  "period_days": 7
},
"periods": {
  "weekly": {
    "days": 7,
    "consumer": "teamspace"
  },
  "bi_weekly": {
    "days": 14,
    "consumer": "bi_weekly_sync"
  },
  "custom": {
    "consumer": "ad_hoc"
  }
}
```

| Mode | Use | Date behavior |
|------|-----|---------------|
| `weekly` | Input for Teamspace skill | 7-day range; default when no period is specified |
| `bi_weekly` | Input for bi-weekly sync skill | 14-day range when user asks for bi-weekly / last 2 weeks |
| `custom` | Ad hoc report | Explicit user-provided start/end dates |

The report must include `Period mode` and `Downstream consumer` metadata so downstream skills can route the output correctly.

---

## GitHub PR modification stats (`config.json`)

Work-track shows GitHub-style modification stats beside each PR in reports.

```json
"github": {
  "show_modification_lines": true,
  "show_changed_files": true,
  "modification_format": "+{additions} -{deletions}, {changedFiles} files",
  "large_pr_lines": 1500
}
```

| Field | Purpose |
|-------|---------|
| `show_modification_lines` | Shows `+additions -deletions` beside every PR |
| `show_changed_files` | Shows changed file count beside every PR |
| `modification_format` | Controls the display format in report rows |
| `large_pr_lines` | Changed-line threshold for large/hard-to-review PRs |

Example report row:

```markdown
- [#699 chore(ci): add no-op next deploy comment](https://github.com/webex/widgets/pull/699) — webex/widgets — Jun 11 — merged Jun 12 — +1411 -10, 5 files
```

The changed-line total is `additions + deletions`. If it is greater than or equal to `large_pr_lines`, the PR should be considered for **Action Items** or **Needs attention** when it creates review friction.

---

## Confluence context (`config.json`)

Confluence support uses the `confluence-client` skill. It is strictly read-only.

```json
"confluence": {
  "enabled": true,
  "required": false,
  "read_only": true,
  "skill": "confluence-client",
  "identity_field": "jira_email",
  "spaces": [],
  "search_pages": true,
  "search_comments": true,
  "search_mentions": true,
  "search_action_items": true
}
```

| Field | Purpose |
|-------|---------|
| `enabled` | Allows work-track to use Confluence as a source |
| `required` | `false` means reports continue if Confluence is unavailable |
| `read_only` | Must stay `true`; work-track must never create/edit/delete/comment in Confluence |
| `skill` | Skill ID/name used for natural-language Confluence queries |
| `identity_field` | Usually `jira_email`; this is the Cisco mail ID used for lookups |
| `spaces` | Optional Confluence space keys/names to search first; empty means general search |
| `search_pages` | Find pages created/updated by the user in the period |
| `search_comments` | Find comments by the user in the period |
| `search_mentions` | Find pages/comments where the user is mentioned/tagged |
| `search_action_items` | Extract TODOs, asks, follow-ups, and implied action items |

Confluence action-item extraction should look for:

- user mentions/tags with a request or question
- comments assigning an owner, follow-up, TODO, or due date
- commitment language such as "I will check", "I'll update", "I can review", or "I'll follow up"
- requests to review a doc, design, release note, decision, or PR

Do not store Confluence tokens in `config.json`, `team.json`, or git.

---

## Webex context (`config.json`)

Webex CLI is mandatory for standard work-track reports. It provides messages, meetings, live transcripts, team check-in work-summary signals, action items, and review-friction signals. The internal Webex CLI skill owns authentication, secure local storage, and CLI command details.

```json
"webex": {
  "enabled": true,
  "required": true,
  "include_by_default": true,
  "timezone": "Asia/Kolkata",
  "identity_field": "jira_email",
  "spaces": {
    "team_checkin": [],
    "code_review": [],
    "release": [],
    "blockers": [],
    "general": []
  },
  "pr_review_thresholds": {
    "large_pr_lines": 1500,
    "stale_review_days": 3
  }
}
```

| Field | Purpose |
|-------|---------|
| `enabled` | Allows work-track to use Webex context |
| `required` | Marks Webex CLI as mandatory for complete standard reports |
| `include_by_default` | `true` means regular work reports include Webex messages, meetings, and check-in context |
| `timezone` | Used for today/yesterday/date-range meeting and calendar routing |
| `identity_field` | Usually `jira_email`; this is the Cisco mail ID used for Webex lookups |
| `spaces.team_checkin` | Webex spaces used to derive work-summary bullets and action items |
| `spaces.code_review` | Webex spaces scanned for PR review requests and reviewer tags |
| `spaces.release` | Webex spaces scanned for release/sprint asks |
| `spaces.blockers` | Webex spaces scanned for blockers and escalations |
| `spaces.general` | Fallback team spaces for general catch-up |
| `pr_review_thresholds.large_pr_lines` | Changed-line threshold for oversized/hard-to-review PRs; default `1500` |
| `pr_review_thresholds.stale_review_days` | Days before a pending review request becomes a Needs attention item; default `3` |

**The `spaces.*` arrays are optional prioritization hints, not a requirement.** Leaving them empty is fully supported and is the default: work-track falls back to indexed full-text search across all synced Webex spaces (`webex messaging search "<name>" --all-indexed`). Empty `spaces` must never produce a "Webex context unavailable / no spaces configured" message. Populate them only if you want specific spaces searched first for team check-in, code review, release, or blocker context.

**Do not store Webex tokens or session secrets in `config.json` or `team.json`.** Use the Webex CLI skill's setup and secure local storage.

When the user provides a CEC ID, work-track resolves it through `team.json` and uses the matching `jira_email` for Webex. If no team member matches, the agent can try `<cec>@cisco.com` for Webex-only lookup and should tell the user the person is missing from `team.json`.

### Space + GitHub correlation

For code review spaces, work-track should extract GitHub PR links or PR references from Webex messages, then query GitHub for PR metadata:

- additions + deletions
- changed files
- age
- review requests
- review/comment activity
- draft/open/merged state

If a PR mentioned in a Webex code review space has `additions + deletions >= 1500`, classify it as a review-friction item because it is difficult to review effectively. Add an **Action Item** recommending the author split the PR, reduce scope, or provide focused reviewer/testing notes.

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

**MCP config paths (Claude Code):**

| Scope | Correct file |
|-------|----------------|
| User | `~/.claude.json` → `"mcpServers"` |
| Project | `.mcp.json` at project root |

**Not read:** `~/.claude/mcp.json`, `~/.cursor/mcp.json`, `settings.json`

Verify: `claude mcp list` should show `jira` and `jira-sjc12` as Connected.

Set env vars only if using the script fallback (optional when MCP works):

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

- "Track my weekly work"
- "Track my bi-weekly work for sync"
- "Work report from 2026-06-01 to 2026-06-15"
- "Team work report"
- "Add team member Raj, raj@cisco.com, github raj-k"
- "Add Jira project ENG to work-track"
- "Show work-track config"
