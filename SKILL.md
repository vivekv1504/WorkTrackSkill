---
name: work-track
description: Tracks engineering work from Jira (comments, status transitions, resolved/open tickets) and GitHub (PRs opened, closed, merged, reviews). Generates individual or team activity reports. Reads and updates ~/.claude/skills/work-track/config.json and team.json. Use whenever the user asks for work tracking, activity summary, sprint review, what they did this week, Jira/GitHub stats, open PRs, team leaderboard, to add/update team members or Jira projects, or to get a Jira summary for a CEC ID — even if they don't say "work-track" explicitly. Also resolves a report target when the user provides a name or CEC ID (e.g. "show me shreysh2's work" or "report for Shreyas Sharma").
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
| **Jira-only** | "Jira summary", "tickets for CEC ID", manager asking about Jira only |

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
- [ ] Step 1:  Load config.json + team.json
- [ ] Step 1b: Resolve target user (name / CEC ID lookup)
- [ ] Step 2:  Resolve date range
- [ ] Step 3a: Fetch Jira — SJC12 board (CAI)
- [ ] Step 3b: Fetch Jira — GPK2 board (SPARK) via MCP
- [ ] Step 4:  Fetch GitHub activity (skip if Jira-only mode)
- [ ] Step 5:  Build report + flag stale items
```

### Step 1 — Load config

Read `~/.claude/skills/work-track/config.json` for defaults. For team reports, read `team.json` and iterate `members[]` where `active !== false`.

---

### Step 1b — Resolve target user (name / CEC ID)

If the user's prompt names a specific person (not "me", "my", "I", or "team"), resolve them before fetching data:

1. **CEC ID / email match** — if the input looks like an email (`@cisco.com`) or a bare CEC ID (no spaces, no `@`), match against `jira_email` (the part before `@`) or `github` in `team.json`. Case-insensitive.
   - `shreysh2` → matches member with `jira_email: "shreysh2@cisco.com"`
   - `shreysh2@cisco.com` → same member
2. **Display name match** — if the input has spaces or doesn't match a CEC/email, do a case-insensitive substring match against `name` in `team.json`.
   - `Shreyas` → matches `"Shreyas Sharma"`
3. **No match** — inform the user the person was not found in `team.json` and list close matches (partial name matches). Offer to add them.
4. **Ambiguous** — if multiple members match, list them and ask the user to clarify.

Once resolved, use that member's `jira_email` and `github` fields as the target user for Steps 3–5 instead of the default user from `config.json`.

**Examples:**
- "work report for shreysh2" → resolve to Shreyas Sharma → `jira_email: shreysh2@cisco.com`, `github: Shreyas281299`
- "what did adweeks do this week" → resolve to Adam Weeks → `jira_email: adweeks@cisco.com`, `github: adamweeks`
- "Jira summary for rsarika" → resolve to Ravi chandra shekar sarika → Jira-only mode, both boards

---

### Step 2 — Dates

Compute `START_DATE` and `END_DATE` as `YYYY-MM-DD` (inclusive).

---

### Step 3a — Jira SJC12 board (CAI)

**Priority:**
1. `mcp__jira-sjc12` MCP tool (primary)
2. curl REST API with `JIRA_API_TOKEN`

```
endpoint: /search
method: GET
params:
  jql: assignee = "EMAIL" AND project = CAI AND updated >= "START" ORDER BY updated DESC
  fields: summary,status,priority,updated,resolutiondate
  maxResults: 50
```

Resolved tickets:
```
jql: assignee = "EMAIL" AND project = CAI AND status changed to Done DURING ("START", "END")
```

---

### Step 3b — Jira GPK2 board (SPARK)

Use `mcp__jira` MCP tool only.

```
endpoint: /search
method: GET
params:
  jql: assignee = "EMAIL" AND project = SPARK AND updated >= "START" ORDER BY updated DESC
  fields: summary,status,priority,updated,resolutiondate
  maxResults: 50
```

If the MCP call returns a 401 or auth error → inform the user: *"GPK2 data unavailable — the PAT token for mcp__jira is expired. Please regenerate it in MCP settings."* Report SJC12 data only.

---

### Step 4 — GitHub (skip in Jira-only mode)

**Jira-only mode** is active when:
- User says "Jira summary", "tickets only", or "just Jira"
- Manager explicitly asks for Jira data for a CEC ID without mentioning GitHub

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

---

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

## Report Templates

### Full report (Jira + GitHub)

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

### Jira-only report (both boards)

```markdown
# Jira Summary — [Name] ([CEC ID])
**Period:** [START] → [END]

## Summary
[2–3 sentences covering activity across both boards]

## SJC12 — CAI Board
| Metric | Count |
|--------|------:|
| Tickets resolved | |
| Open assigned tickets | |
| Updated in period | |

### Resolved
- [CAI-KEY summary](https://jira-eng-sjc12.cisco.com/jira/browse/CAI-KEY) — status — date

### Open / In Progress
- [CAI-KEY summary](url) — status — last updated

## GPK2 — SPARK Board
| Metric | Count |
|--------|------:|
| Tickets resolved | |
| Open assigned tickets | |
| Updated in period | |

### Resolved
- [SPARK-KEY summary](https://jira-eng-gpk2.cisco.com/jira/browse/SPARK-KEY) — status — date

### Open / In Progress
- [SPARK-KEY summary](url) — status — last updated

## Needs attention
- [Tickets stale 3+ days]
```

---

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
- GPK2 MCP auth failure: report SJC12 data only, tell user to regenerate the PAT token in MCP settings
- Partial data: report what's available, note which board failed
- One team member fails: skip, note failure, continue
- No activity: say clearly — don't emit empty template

## Resources

- [config.json](config.json) — defaults
- [team.json](team.json) — roster
- [CONFIG.md](CONFIG.md) — add/update guide
- [reference.md](reference.md) — API + script reference
