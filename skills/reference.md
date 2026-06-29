# Work Track — MCP Reference

## Date period modes

| Mode | Trigger examples | Output metadata | Date range |
|------|------------------|-----------------|------------|
| `weekly` | `weekly`, `this week`, `teamspace`, no period supplied | `consumer: teamspace` | 7 days |
| `bi_weekly` | `bi-weekly`, `biweekly`, `last 2 weeks`, `two weeks` | `consumer: bi_weekly_sync` | 14 days |
| `custom` | `from YYYY-MM-DD to YYYY-MM-DD`, explicit date range | `consumer: ad_hoc` | User supplied |

Always resolve and report:

- `START_DATE`
- `END_DATE`
- `PERIOD_MODE`
- `CONSUMER`

Do not default to 14 days. Default to `weekly` from `config.json`.

## Jira REST (via MCP)

### Search issues
```
endpoint: search
method: GET
params: { jql: "assignee = \"user@co.com\" AND updated >= \"2026-06-10\"", fields: "summary,status,priority,updated", maxResults: 50 }
```

### Issue changelog (status transitions)
```
endpoint: issue/PROJ-123
method: GET
params: { expand: "changelog" }
```
Parse `changelog.histories[]`: filter `items[].field == "status"`, match author email, date in range.

### Comments
```
endpoint: issue/PROJ-123/comment
method: GET
params: { maxResults: 100, orderBy: "-created" }
```

### Useful JQL snippets

| Goal | JQL |
|------|-----|
| Assigned, not done | `assignee = "email" AND status != Done` |
| Resolved in range | `assignee = "email" AND status changed to Done DURING ("2026-06-10", "2026-06-17")` |
| Updated in range | `assignee = "email" AND updated >= "2026-06-10" AND updated <= "2026-06-17"` |
| User commented | Search assigned tickets, then filter comments by author + date in app logic |

---

## GitHub GraphQL (via MCP)

Use `@me` for the authenticated user; use explicit username when tracking others.

### PRs opened in period
```graphql
query {
  search(query: "author:USERNAME is:pr created:2026-06-10..2026-06-17", type: ISSUE, first: 100) {
    issueCount
    nodes { ... on PullRequest { number title url createdAt mergedAt closed merged repository { nameWithOwner } } }
  }
}
```

### PRs merged in period
```graphql
query {
  search(query: "author:USERNAME is:pr is:merged merged:2026-06-10..2026-06-17", type: ISSUE, first: 100) {
    issueCount
    nodes { ... on PullRequest { number title url mergedAt repository { nameWithOwner } } }
  }
}
```

### Open PRs
```graphql
query {
  search(query: "author:USERNAME is:pr is:open", type: ISSUE, first: 50) {
    issueCount
    nodes { ... on PullRequest { number title url createdAt repository { nameWithOwner } } }
  }
}
```

### Reviews by user
```graphql
query {
  search(query: "reviewed-by:USERNAME updated:2026-06-10..2026-06-17", type: ISSUE, first: 100) {
    issueCount
    nodes { ... on PullRequest { number title url repository { nameWithOwner } } }
  }
}
```

Add `repo:org/name` to scope queries.

---

## gh CLI alternatives

```bash
# Open PRs by author
gh search prs --author USERNAME --state open --json number,title,url,createdAt,repository

# Merged in date range (approximate via search)
gh search prs --author USERNAME --merged --merged-at "2026-06-10..2026-06-17" --json number,title,url,mergedAt

# PRs created in range
gh search prs --author USERNAME --created "2026-06-10..2026-06-17" --json number,title,url,createdAt,state

# Modification stats for each PR shown in reports
gh pr view PR_URL --json additions,deletions,changedFiles
```

### GitHub modification display

For every PR included in the report, fetch and display:

- `additions`
- `deletions`
- `changedFiles`

Use this report row format:

```markdown
- [#N title](url) — owner/repo — created date — merged/closed/open status — +A -D, F files
```

Example:

```markdown
- [#699 chore(ci): add no-op next deploy comment](https://github.com/webex/widgets/pull/699) — webex/widgets — Jun 11 — merged Jun 12 — +1411 -10, 5 files
```

Use `additions + deletions` for large PR detection. Default threshold: `1500` changed lines.

---

## Confluence client reference

Use the `confluence-client` skill as a read-only natural-language Confluence client. Work-track should ask it plain-English questions and let that skill translate to Confluence CLI commands.

Never create, edit, delete, or comment on Confluence content from work-track.

### Confluence identity routing

| User input | Confluence identity to use |
|------------|----------------------------|
| `user@cisco.com` | Exact email |
| bare CEC ID | Match `team.json` by `jira_email` prefix, otherwise try `<cec>@cisco.com` |
| display name | Match `team.json.members[].name`, then search name + email |

### Useful Confluence queries

Ask the Confluence skill for these within `START_DATE` → `END_DATE`:

- pages created by the user
- pages updated by the user
- comments by the user
- mentions/tags of the user
- action items assigned to or implied for the user
- meeting notes, design docs, release docs, specs, and decision pages involving the user
- Jira/GitHub/Webex references inside relevant pages/comments

### Confluence action-item extraction

Treat as action items:

- user is mentioned/tagged with a request or question
- user is assigned a TODO, owner, follow-up, or due date
- user writes commitment language such as "I will check", "I'll update", "I can review", or "I'll follow up"
- comment/page asks the user to review a doc, design, release note, decision, or PR

Merge Confluence output into:

- `Confluence` report section for source evidence
- `Work Summary` for completed docs, decisions, specs, release notes, and meaningful updates
- `Action Items` for TODOs, asks, mentions, review requests, and follow-ups
- `Needs attention` for stale/unanswered Confluence asks

Do not create a separate linked-resources section.

---

## Webex CLI skill reference

Use the internal Webex CLI skill for standard work-track reports. Webex is mandatory for messages, meetings, live transcripts, team check-in work-summary signals, action items, and follow-ups. Do not hardcode credentials or Webex tokens in this skill. If command syntax is needed, read the Webex CLI skill's own instructions/help because the command surface is owned by that skill.

### Identity routing

| User input | Webex identity to use |
|------------|------------------------|
| `user@cisco.com` | Exact email |
| bare CEC ID | Match `team.json` by `jira_email` prefix, otherwise try `<cec>@cisco.com` |
| display name | Match `team.json.members[].name`, then use `jira_email` |

### Useful Webex tasks

| Goal | Data to extract |
|------|-----------------|
| Messaging catch-up | Space name, thread/message date, unanswered questions, blockers, decisions, action items |
| Team check-in | Work-summary signals, blockers, wins, pain points, action items |
| Code review spaces | GitHub PR links, PR numbers, requested reviewers, reviewer tags, review blockers |
| Meeting history | Meeting title, date/time, participants if available, summary, decisions, follow-ups |
| Live transcript | Current meeting captions, active action items, unresolved questions |
| Meeting artifacts | Transcript, summary, recording metadata, chat log, links |
| Calendar routing | Upcoming/recent meetings by today/yesterday/week/custom range |
| Jira/Confluence enrichment | Jira issue keys, Confluence page links, related decisions/action items |

### Webex space + GitHub PR correlation

Scan configured `webex.spaces.code_review` spaces first, then any configured `general` spaces. Extract GitHub PR URLs and review-request language from Webex messages.

For each PR URL:

```bash
gh pr view PR_URL \
  --json url,number,title,author,additions,deletions,changedFiles,state,isDraft,reviewRequests,reviews,comments,createdAt,updatedAt,mergedAt
```

Calculate:

- `changed_lines = additions + deletions`
- `age_days = today - createdAt`
- `review_wait_days = today - Webex review request message date`
- pending reviewers from `reviewRequests`

Classify:

| Condition | Report section |
|-----------|----------------|
| `changed_lines >= 1500` | **Needs attention** — oversized PR is hard to review |
| oversized PR is blocking or repeatedly requested | **Action Items** — split/reduce PR or add reviewer notes |
| pending review older than 3 days | **Needs attention** |
| helpful/fast review called out in Webex | **Work Summary** |
| Webex message links Jira/Confluence with PR context | Add to the relevant Jira, Webex, Work Summary, or Action Items context |

### Report merge rules

- Add linked Jira keys found in Webex output to the Jira section and mark them as `mentioned in Webex`.
- Add Confluence page/comment evidence to the Confluence section and fold important decisions or asks into Work Summary or Action Items.
- Add Webex check-in outputs to `Work Summary`, `Action Items`, and `Needs attention`.
- Add unanswered Webex questions, meeting follow-ups, stale PR reviews, and oversized blocking PRs to `Needs attention`.
- Prefer summaries and extracted action items over raw message dumps.
- Include Webex by default for standard work-track reports because `config.json` has `webex.required: true` and `webex.include_by_default: true`.
