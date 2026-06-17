---
name: work-track
description: Tracks engineering work from Jira (comments, status transitions, resolved/open tickets) and GitHub (PRs opened, closed, merged, reviews). Generates individual or team activity reports. Reads and updates ~/.claude/skills/work-track/config.json and team.json. Use whenever the user asks for work tracking, activity summary, sprint review, what they did this week, Jira/GitHub stats, open PRs, team leaderboard, or to add/update team members or Jira projects — even if they don't say "work-track" explicitly.
---

# Work Track

Claude Code skill for Jira + GitHub work reports.

**Skill directory:** `~/.claude/skills/work-track/`

Track activity across **Jira** (comments, status changes, tickets) and **GitHub** (PRs opened/closed/merged, reviews). Produce readable reports for one person or a team.

## Modes

| Mode | Trigger |
|------|---------|
| **Individual** | "my work", "what did I do", single person |
| **Team** | "my team", "team report", manager view |

Default period: **last 14 days** from [config.json](config.json) → `defaults.period_days`. Accept natural language dates.

## Configuration

| What | File |
|------|------|
| Default user, Jira projects, URLs | [config.json](config.json) |
| Team roster | [team.json](team.json) |
| How to add/update | [CONFIG.md](CONFIG.md) |

**Add/update on request:** edit the JSON file, merge changes, confirm to user.

Team members use `github` (not `github_username`) in [team.json](team.json) for script compatibility.

---

## Workflow

```
- [ ] Step 1: Load config.json + team.json (if team mode)
- [ ] Step 2: Resolve date range
- [ ] Step 3: Fetch Jira activity
- [ ] Step 4: Fetch GitHub activity
- [ ] Step 5: Build report + flag stale items
```

### Step 1 — Load config

Read `~/.claude/skills/work-track/config.json` for defaults. For team reports, read `team.json` and iterate `members[]` where `active !== false`.

### Step 2 — Dates

Compute `START_DATE` and `END_DATE` as `YYYY-MM-DD` (inclusive).

### Step 3 — Jira

**Priority:**
1. Jira MCP tool (if available in this session)
2. `fetch_jira.py` script
3. curl REST API

```bash
# Script (recommended)
python3 ~/.claude/skills/productivity-tracker/scripts/fetch_jira.py \
  --user "$JIRA_EMAIL" --start "$START" --end "$END" \
  --base-url "$JIRA_BASE_URL" --token "$JIRA_API_TOKEN" \
  --output /tmp/work-track-jira.json
```

**JQL** (substitute email, dates, projects from config):

```jql
assignee = "vinvivek@cisco.com" AND status != Done ORDER BY updated DESC
assignee = "vinvivek@cisco.com" AND status changed to Done DURING ("START", "END")
project in (CAI) AND updated >= "START" ORDER BY updated DESC
```

**Multi-board:** Read `jira_boards[]` in [config.json](config.json).
- **CAI** → `mcp_jira-sjc12` (`jira-eng-sjc12`)
- **GPK / SPARK** → `mcp_jira` via `https://aicoding-mcp.cisco.com/jira/` (token in MCP settings only)

Board: [rapidView=10147](https://jira-eng-gpk2.cisco.com/jira/secure/RapidBoard.jspa?rapidView=10147) · Project: `SPARK`

For transitions/comments: fetch issue changelog and comments per ticket. See [reference.md](reference.md).

**Auth:** `JIRA_BASE_URL`, `JIRA_USER_EMAIL`, `JIRA_API_TOKEN` env vars.

### Step 4 — GitHub

**Priority:**
1. `gh` CLI (primary)
2. `fetch_github.py` script

```bash
gh auth status

USER=vivekv1504   # from config or team member
gh search prs --author "$USER" --created "$START..$END" \
  --json number,title,url,createdAt,state,closedAt,repository
gh search prs --author "$USER" --merged --closed "$START..$END" \
  --json number,title,url,createdAt,state,closedAt,repository
gh search prs --author "$USER" --state open \
  --json number,title,url,createdAt,repository
gh search prs --reviewed-by "$USER" --updated "$START..$END" \
  --json number,title,url,repository
```

Or script:
```bash
python3 ~/.claude/skills/productivity-tracker/scripts/fetch_github.py \
  --user "$USER" --start "$START" --end "$END" \
  --scope "*" --output /tmp/work-track-github.json
```

### Step 5 — Team batch (optional)

```bash
python3 ~/.claude/skills/productivity-tracker/scripts/fetch_team.py \
  --config ~/.claude/skills/work-track/team.json \
  --start "$START" --end "$END" \
  --token "$JIRA_API_TOKEN" \
  --output-dir /tmp/work-track-team/

python3 ~/.claude/skills/productivity-tracker/scripts/generate_team_report.py \
  --config ~/.claude/skills/work-track/team.json \
  --data-dir /tmp/work-track-team/ \
  --period-label "$START to $END" \
  --output team_report.md
```

### Step 6 — Report

Use template below. Jira links: `{jira_base_url}/browse/{KEY}`.

Flag stale items: Jira/PR open 3+ days without movement.

---

## Report Template

```markdown
# Work Track — [Name]
**Period:** [START] → [END]

## Summary
[2–3 sentences]

## GitHub
| Metric | Count |
|--------|------:|
| PRs opened | |
| PRs merged | |
| PRs closed (not merged) | |
| Reviews given | |
| Open PRs (now) | |

### PRs opened / merged / open
- [#N title](url) — repo — date

## Jira
| Metric | Count |
|--------|------:|
| Tickets resolved | |
| Status transitions | |
| Comments added | |
| Open assigned tickets | |

### Resolved / transitions / comments / open tickets
- [KEY summary](url) — details

## Highlights
- [Notable item]

## Needs attention
- [Stale item]
```

## Team report extras

```markdown
# Team Work Track — [team_name from team.json]
**Period:** [START] → [END] | **Members:** N

## Leaderboard
| Name | PRs merged | Tickets resolved | Comments | Open items |

## Per-member summary
[Compact block per person]

## Blocked / stale
[3+ days idle, grouped by person]
```

---

## Demo mode

No credentials:
```bash
python3 ~/.claude/skills/productivity-tracker/scripts/generate_report.py --demo
python3 ~/.claude/skills/productivity-tracker/scripts/generate_team_report.py --demo
```

---

## Error handling

- Missing auth: list required env vars; link to [CONFIG.md](CONFIG.md)
- Partial data: report what's available
- One team member fails: skip, note failure, continue
- No activity: say clearly — don't emit empty template

## Resources

- [config.json](config.json) — defaults
- [team.json](team.json) — roster
- [CONFIG.md](CONFIG.md) — add/update guide
- [reference.md](reference.md) — API + script reference
