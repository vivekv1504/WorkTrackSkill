---
name: work-track
description: Tracks engineering work from Jira (comments, status transitions, resolved/open tickets), GitHub (PRs opened, closed, merged, reviews), read-only Confluence context (pages, comments, mentions, action items), and mandatory Webex context (messages, meetings, transcripts, artifacts). Generates individual or team work summaries and action items. Must be installed and configured for both Claude Code and Codex; reads and updates the active runtime's work-track config.json and team.json. Use whenever the user asks for work tracking, activity summary, sprint review, what they did this week, Jira/GitHub/Confluence stats, open PRs, team leaderboard, Webex catch-up, meeting follow-up, unanswered Webex questions, team space check-in, action items, to add/update team members or Jira projects, or to get a Jira/Webex/Confluence summary for a CEC ID — even if they don't say "work-track" explicitly. Also resolves a report target when the user provides a name or CEC ID (e.g. "show me shreysh2's work" or "report for Shreyas Sharma").
---

# Work Track

Claude Code and Codex skill for Jira + GitHub + Confluence + Webex work reports.

**Mandatory skill directories:**

- Claude Code: `~/.claude/skills/work-track/`
- Codex: `~/.agents/skills/work-track/`

Keep both copies installed and configured with the same `config.json` and `team.json`. If only one runtime is configured, reports may differ or miss data depending on where the skill is run.

Track activity across **Jira** (comments, status changes, tickets), **GitHub** (PRs opened/closed/merged, reviews), read-only **Confluence** context (pages, comments, mentions, action items), and mandatory **Webex CLI** context (spaces, messages, meetings, transcripts, artifacts). Produce readable reports for one person or a team.

## Modes

| Mode              | Trigger                                                                               |
| ----------------- | ------------------------------------------------------------------------------------- |
| **Individual**    | "my work", "what did I do", single person                                             |
| **Team**          | "my team", "team report", manager view                                                |
| **Webex context** | "Webex catch-up", "meeting notes", "unanswered questions", "messages for CEC ID"      |
| **Full context**  | Work report that should include Jira + GitHub + Confluence + Webex meetings/messages  |
| **Team check-in** | "team space check-in", "action items", "what needs follow-up", "what is blocked" |

Default period mode: **weekly** from [config.json](config.json) → `defaults.period_mode`. Weekly data is intended as input for the **Teamspace skill**. Bi-weekly data is intended as input for the **bi-weekly sync skill**. Custom date ranges are supported when the user provides explicit dates or natural-language ranges.

## Configuration

| What                              | File                       |
| --------------------------------- | -------------------------- |
| Default user, Jira projects, URLs | [config.json](config.json) |
| Team roster                       | [team.json](team.json)     |
| How to add/update                 | [CONFIG.md](CONFIG.md)     |

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
- [ ] Step 4:  Fetch GitHub activity
- [ ] Step 4b: Fetch Confluence context (read-only)
- [ ] Step 4c: Fetch Webex context (mandatory for messages, meetings, transcripts, and team check-ins)
- [ ] Step 4d: Correlate Webex/Confluence signals with GitHub PR metadata
- [ ] Step 5:  Team batch (optional)
- [ ] Step 6:  Build work summary + action items; flag stale items, unanswered questions, and follow-ups
```

### Step 1 — Load config

Read the active runtime's `work-track/config.json` for defaults:

- Claude Code: `~/.claude/skills/work-track/config.json`
- Codex: `~/.agents/skills/work-track/config.json`

For team reports, read the matching `team.json` from the same runtime directory and iterate `members[]` where `active !== false`.

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

Once resolved, use that member's `jira_email` and `github` fields as the target user for Steps 3–6 instead of the default user from `config.json`.

For Webex context, use the resolved Cisco email as the primary identity. If the user provides a bare CEC ID, normalize it to `<cec>@cisco.com` for Webex CLI lookups after matching `team.json`.

**Examples:**

- "work report for shreysh2" → resolve to Shreyas Sharma → `jira_email: shreysh2@cisco.com`, `github: Shreyas281299`
- "what did adweeks do this week" → resolve to Adam Weeks → `jira_email: adweeks@cisco.com`, `github: adamweeks`
- "work summary for rsarika" → resolve to Ravi chandra shekar sarika → full work summary + action items

---

### Step 2 — Date period

Resolve one of these period modes before fetching data:

| Period mode | Trigger | Range | Downstream consumer |
|-------------|---------|-------|---------------------|
| `weekly` | "weekly", "this week", "last week", default | 7 days unless the prompt says a specific week | Teamspace skill |
| `bi_weekly` | "bi-weekly", "biweekly", "last 2 weeks", "two weeks" | 14 days unless the prompt says a specific two-week range | Bi-weekly sync skill |
| `custom` | explicit date range, e.g. "Jun 1 to Jun 15", "2026-06-01..2026-06-15" | user-supplied start/end | Ad hoc |

Compute `START_DATE` and `END_DATE` as `YYYY-MM-DD` inclusive.

Rules:

- If the user does not specify a period, use `defaults.period_mode` from `config.json`; currently `weekly`.
- If the user says weekly/teamspace, set `PERIOD_MODE=weekly`, `PERIOD_LABEL="Weekly"`, and `CONSUMER="teamspace"`.
- If the user says bi-weekly/biweekly/two weeks/last 2 weeks, set `PERIOD_MODE=bi_weekly`, `PERIOD_LABEL="Bi-weekly"`, and `CONSUMER="bi_weekly_sync"`.
- If the user gives explicit start and end dates, set `PERIOD_MODE=custom`, `PERIOD_LABEL="Custom"`, and `CONSUMER="ad_hoc"`.
- Include the resolved `PERIOD_MODE`, `PERIOD_LABEL`, and `CONSUMER` in the final report metadata.
- Do not assume "last 14 days" by default anymore; 14 days is only for bi-weekly mode or a matching custom request.

---

### Step 3a — Jira SJC12 board (CAI)

**Source order:**

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

If the MCP call returns a 401 or auth error → inform the user: _"GPK2 data unavailable — the PAT token for mcp\_\_jira is expired. Please regenerate it in MCP settings."_ Report SJC12 data only.

---

### Step 4 — GitHub

Fetch GitHub activity for every standard work-track report. Jira is no longer a separate report mode; Jira activity is one source within the complete work summary and action-items report.

**Source order:**

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

For every PR that appears in the report, fetch modification stats so the report can show GitHub-style line changes next to the PR:

```bash
gh pr view "$PR_URL" \
  --json additions,deletions,changedFiles
```

Render modification stats using `config.json` → `github.modification_format`:

```text
+{additions} −{deletions}, {changedFiles} files
```

Example:

```markdown
- [#699 chore(ci): add no-op next deploy comment](https://github.com/webex/widgets/pull/699) — webex/widgets — Jun 11 — merged Jun 12 — +1411 -10, 5 files
```

If `additions + deletions >= github.large_pr_lines` (default `1500`), also treat the PR as large/hard to review. If it causes review friction or was requested in Webex or Confluence, add it as an action item or needs-attention item.

---

### Step 4b — Confluence context (read-only)

Use the `confluence-client` skill when available. This source is strictly read-only: never create, edit, delete, or comment on Confluence pages from work-track.

**Source order:**

1. `confluence-client` skill
2. If unavailable or unauthenticated, continue with Jira/GitHub/Webex data and mark Confluence as unavailable in the report.

**Identity resolution:**

- Use the resolved member's `jira_email` as the primary identity.
- Also search by display name, CEC ID, and GitHub handle when available.

**Data to collect for `START_DATE` → `END_DATE`:**

- Pages created by the user
- Pages updated by the user
- Comments by the user
- Mentions/tags of the user
- Action items assigned to or implied for the user
- Meeting notes, design docs, release docs, specs, and decision pages updated in the period
- Jira/GitHub/Webex references found in pages or comments

**Action-item extraction:**

Treat Confluence content as an action item when:

- the user is mentioned/tagged with a request or question
- a page/comment assigns an owner, follow-up, TODO, or due date to the user
- the user says or writes commitment language such as "I will check", "I'll update", "I can review", or "I'll follow up"
- a Confluence comment asks the user to review a doc, PR, design, release note, or decision

**Output rules:**

- Add Confluence activity to the `Confluence` section.
- Fold important Confluence decisions/updates into `Work Summary`.
- Fold Confluence asks/TODOs/mentions into `Action Items`.
- Do not create a separate linked-resources section.

---

### Step 4c — Webex CLI context (mandatory)

Use the internal Webex CLI skill for all standard work-track reports. Webex is mandatory because meeting context, code-review requests, live transcripts, unanswered questions, and action items come from Webex spaces and meetings.

**Source order:**

1. Internal Webex CLI skill
2. Webex CLI binary/helper configured by that skill
3. Ensure the Webex sync server is running before querying messages. If `webex messaging health` reports the server is not running, auto-start it without asking: `npm explore -g @webex/cli -- npm run server:start`, wait ~3s, then re-check health.
4. Webex is "unavailable" **only** when the Webex CLI is missing or unauthenticated (`webex auth status` fails). In that case continue Jira/GitHub collection as partial data and explicitly mark the report incomplete: `Webex data unavailable — mandatory Webex CLI access is required for messages, meetings, transcripts, work summary, and action items.`
5. An empty `webex.spaces` in `config.json` is **not** a reason to skip Webex. It only removes configured space hints. Always fall back to indexed full-text search across all spaces (see Space routing). Never emit a "Webex context unavailable / no spaces configured" message solely because these arrays are empty.

**Identity resolution:**

- Use the resolved member's `jira_email` as the Cisco mail ID.
- If only a CEC ID is provided, match it through `team.json`; if no match exists, use `<cec>@cisco.com` only for Webex lookup and tell the user the person is not in `team.json`.
- If only a display name is provided, resolve through `team.json` first. If multiple members match, ask for clarification before querying Webex.

**Supported Webex context:**

- **Messaging catch-up:** search spaces, read recent messages, identify unanswered questions, decisions, blockers, and active threads.
- **Meeting history:** list today's, yesterday's, or date-range meetings using the resolved timezone.
- **Live transcripts:** attach to an active meeting when explicitly requested and summarize captions or watch for action items.
- **Meeting artifacts:** download/read transcripts, summaries, recordings, and chat logs from past meetings when available.
- **Calendar routing:** query upcoming and recent meetings by day, week, or custom range.
- **Confluence/Jira enrichment:** include linked Confluence pages and Jira issues found in messages, meetings, transcripts, or artifacts.
- **Secure local storage:** rely on the Webex CLI skill's storage/auth model; never copy Webex credentials into this skill's JSON files.

**Scope rules:**

- Include Webex data by default in normal individual, team, and full-context work reports.
- For team reports, summarize Webex context only at team level unless the user explicitly asks for per-person Webex details.
- For live meeting transcripts, attach/watch only when the user explicitly asks; otherwise use past artifacts/history only.

**Output extraction:**

- Capture decisions, blockers, action items, unanswered questions, linked Jira issues, linked Confluence pages, and meeting follow-ups.
- Prefer concise summaries over raw message dumps.
- Attribute items to the Webex space/meeting and date when available.
- If Webex output references Jira issue keys, merge them into the Jira section and mark them as "mentioned in Webex".
- Extract team check-in signals into:
  - **Work summary:** completed work, meaningful progress, shipped/validated work, helpful reviews, important decisions, unblocked work.
  - **Action items:** explicit asks, review bottlenecks, blockers, release/sprint asks, unresolved questions, owner/date-linked follow-ups.
  - **Needs attention:** stale reviews, hard-to-review PRs, unclear ownership, blocked meetings/actions, repeated unresolved items.

**Space routing:**

- `webex.spaces` in `config.json` is an **optional search hint, never a gate**. Empty arrays mean "no configured space hints," not "no Webex access." Never emit a "Webex unavailable / no spaces configured" message just because these arrays are empty.
- Read `config.json` → `webex.spaces`. If any spaces are listed, search/read those configured team check-in, code review, release, blocker, and general spaces first for the report period.
- If no explicit spaces are configured (the default), fall back to indexed full-text search across **all** spaces:
  - Confirm index scope with `webex messaging search-index list` (mode should be `all`).
  - Search with `webex messaging search "<name>" --all-indexed --top 60 --after <START>` using the resolved person's name / CEC / GitHub handle.
  - Open the top matching spaces with `webex messaging messages <space-id> --last-days <N>` and report which spaces were used.
- For team check-in prompts, prioritize `team_checkin` spaces and extract work-summary bullets and action items from the check-in messages.
- For code-review prompts, prioritize `code_review` spaces and extract GitHub PR URLs, PR numbers, author names, reviewer tags, and review requests.

---

### Step 4d — Webex/Confluence signal + GitHub PR correlation

Use this step after fetching Webex messages, Confluence context, and GitHub PR data.

1. Parse Webex messages, Confluence pages/comments, meeting chats, transcripts, and artifacts for:
   - GitHub PR URLs
   - repo/name + PR number references
   - review request wording such as "please review", "tagged to review", "can someone review", "blocking review"
   - reviewer mentions or tagged users
2. For every referenced PR, query GitHub using `gh` or the GitHub script:

```bash
gh pr view PR_URL \
  --json url,number,title,author,additions,deletions,changedFiles,state,isDraft,reviewRequests,reviews,comments,createdAt,updatedAt,mergedAt
```

3. Compute:
   - `changed_lines = additions + deletions`
   - age in days from `createdAt`
   - stale review age from the Webex request date or PR `updatedAt`
   - whether requested reviewers are still pending
4. Classify:
   - If `changed_lines >= webex.pr_review_thresholds.large_pr_lines` (default `1500`), add to **Needs attention** as an oversized/hard-to-review PR.
   - If a PR has a pending review request older than `webex.pr_review_thresholds.stale_review_days` (default `3`), add to **Needs attention**.
   - If a PR is oversized and actively blocking work, add an **Action item** to split/reduce the PR or provide focused reviewer notes.
   - If Webex messages show fast/helpful review or unblocking, include it in **Work summary**.

Example:

```markdown
## Action Items

- Ask the author to split [repo#123](url), reduce scope, or add focused reviewer notes/testing notes before reviewers spend more time on it.

## Needs attention

- Oversized review request: [repo#123](url) has 1,850 changed lines and was requested in the Code Review space, making it hard to review effectively.
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
  --config ~/.claude/skills/work-track/team.json
  --data-dir /tmp/work-track-team/ \
  --period-label "$START to $END" \
  --output team_report.md
```

### Step 6 — Report

Use template below. Jira links: `{jira_base_url}/browse/{KEY}`.

Flag action items, stale items, unanswered questions, meeting follow-ups, and oversized PR review pain points.

---

## Report Templates

### Full report (Jira + GitHub + Confluence + mandatory Webex)

Use this for normal individual reports, full-context requests, and team check-in prompts.

```markdown
# Work Track — [Name]

**Period:** [START] → [END]
**Period mode:** [weekly | bi_weekly | custom]
**Downstream consumer:** [teamspace | bi_weekly_sync | ad_hoc]

## Summary

[2–3 sentences combining Jira, GitHub, Confluence, and Webex context]

## GitHub

| Metric                  | Count |
| ----------------------- | ----: |
| PRs opened              |       |
| PRs merged              |       |
| PRs closed (not merged) |       |
| Reviews given           |       |
| Open PRs (now)          |       |
| Lines added             |       |
| Lines deleted           |       |
| Large PRs               |       |

### PRs opened / merged / open

- [#N title](url) — repo — date/status — +A -D, F files

## Jira

| Metric                | Count |
| --------------------- | ----: |
| Tickets resolved      |       |
| Status transitions    |       |
| Comments added        |       |
| Open assigned tickets |       |

### Resolved / transitions / comments / open tickets

- [KEY summary](url) — details

## Confluence

| Metric                | Count |
| --------------------- | ----: |
| Pages created         |       |
| Pages updated         |       |
| Comments added        |       |
| Mentions/action items |       |

### Pages / comments / mentions

- [Page title](url) — updated date — summary/action item

## Webex

| Metric                  | Count |
| ----------------------- | ----: |
| Meetings reviewed       |       |
| Spaces reviewed         |       |
| Action items found      |       |
| Unanswered questions    |       |
| Linked Jira issues      |       |
| PRs mentioned in spaces |       |
| Oversized PRs flagged   |       |

### Meetings / transcripts

- [Meeting title] — date — decisions/action items/follow-ups

### Messages / spaces

- [Space/thread] — date — unanswered question, blocker, review request, or decision

## Work Summary

<!-- _Work Summary is generated by analyzing activity across GitHub, Jira, Confluence, and Webex within the reporting period. The skill summarizes completed work, meaningful progress, key contributions, important decisions, and recurring themes based on:_

- _High-impact PRs (opened, merged, reviewed, or large/complex changes)_
- _Important Jira ticket resolutions, status changes, or comment activity_
- _Confluence pages, comments, mentions, decisions, specs, or release/design docs_
- _Significant meetings, decisions, follow-ups, or action items from Webex_
- _Patterns found in messages, comments, meeting transcripts, and recurring topics across team spaces_

_This section combines automated extraction with brief narrative summarization to surface what work happened and what mattered most from the aggregated data sources._ -->

- [Completed work, meaningful progress, decision, or shipped contribution]

## Action Items

- [Owner/action/source/date, including stale review requests, tagged questions, meeting follow-ups, and oversized PR cleanup]

## Needs attention

- [Stale Jira/PR item, unanswered Webex question, overdue review request, or meeting follow-up]
```

## Team report extras

```markdown
# Team Work Track — [team_name from team.json]

**Period:** [START] → [END] | **Members:** N
**Period mode:** [weekly | bi_weekly | custom] | **Downstream consumer:** [teamspace | bi_weekly_sync | ad_hoc]

## Leaderboard

| Name | PRs merged | Tickets resolved | Comments | Open items |

## Per-member summary

[Compact block per person]

## Webex team context

[Mandatory for standard team reports: team-level meetings, space check-ins, unanswered questions, blockers, decisions, Confluence/Jira context, PR review asks]

## Team Work Summary

[Team completed work, meaningful progress, important decisions, shipped PRs, resolved tickets, and meeting outcomes]

## Team Action Items

[Action items from Jira/GitHub/Confluence/Webex, including tagged questions, code review requests, Confluence mentions/TODOs, meeting follow-ups, stale reviews, and PRs that need split/reduced scope]

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
- Missing Confluence skill/auth: continue with partial data and mark Confluence unavailable; Confluence is read-only and optional unless the user explicitly requires it
- Missing Webex CLI/auth: mark the report incomplete; Webex is mandatory for messages, meetings, transcripts, work summary, and action items
- Empty `webex.spaces`: NOT an error and NOT a reason to skip Webex — fall back to `--all-indexed` full-text search across all spaces (see Step 4b Space routing). Never report "Webex context unavailable" solely because `webex.spaces` is empty.
- Webex sync server not running: auto-start with `npm explore -g @webex/cli -- npm run server:start`, then re-check `webex messaging health`; do not ask the user first.
- GPK2 MCP auth failure: report SJC12 data only, tell user to regenerate the PAT token in MCP settings
- Partial data: report what's available, note which board failed
- One team member fails: skip, note failure, continue
- No activity: say clearly — don't emit empty template

## Resources

- [config.json](config.json) — defaults
- [team.json](team.json) — roster
- [CONFIG.md](CONFIG.md) — add/update guide
- [reference.md](reference.md) — API + script reference
