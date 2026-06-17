# Work Track — MCP Reference

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
```
