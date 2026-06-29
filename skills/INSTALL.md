# Work Track — Installation Guide

Install the skill locally on your machine. Each person runs their own copy with their own GitHub and Jira credentials.

**Repo:** https://github.com/vivekv1504/WorkTrackSkill

---

## Prerequisites

| Tool | Required for | How to get it |
|------|--------------|---------------|
| **Cursor** or **Claude Code** | Running the skill | Your IDE / CLI |
| **GitHub CLI** (`gh`) | PR stats, team GitHub activity | `brew install gh` then `gh auth login` |
| **Jira MCP** (optional) | Ticket status, active assignments, Jira comments | Cursor MCP settings + Cisco Jira token |
| **Confluence client skill** (optional) | Read-only pages, comments, mentions, action items | Install `confluence-client` skill |
| **Internal Webex CLI skill** | Messaging catch-up, meetings, live transcripts, artifacts, calendar routing, team check-ins | Install/enable using your internal Webex CLI skill setup |
| **Cisco VPN** | Jira MCP / internal Jira | Connect when querying Jira |

---

## Step 1 — Get the files

### Option A: Clone from GitHub (recommended)

```bash
git clone https://github.com/vivekv1504/WorkTrackSkill.git
cd WorkTrackSkill
```

### Option B: Copy from a teammate

Unzip or copy the `work_track_skill` folder shared by your team lead.

---

## Step 2 — Install into your skills folder

### Recommended — use the install script

```bash
cd WorkTrackSkill
./install.sh
```

This copies all skill files to `~/.claude/skills/work-track/` and prints:
```
Installed to ~/.claude/skills/work-track
```

Restart Claude Code after running.

### Manual — Cursor

```bash
mkdir -p ~/.cursor/skills/work-track
cp -r WorkTrackSkill/* ~/.cursor/skills/work-track/
```

Restart Cursor or start a new Agent chat.

### Manual — Claude Code (CLI)

```bash
mkdir -p ~/.claude/skills/work-track
cp -r WorkTrackSkill/* ~/.claude/skills/work-track/
```

Restart Claude Code.

### Verify install

```bash
ls ~/.cursor/skills/work-track/SKILL.md    # Cursor
ls ~/.claude/skills/work-track/SKILL.md    # Claude CLI
```

---

## Step 3 — Configure your identity

Edit `config.json` in your skills folder:

```json
"default_user": {
  "display_name": "Your Name",
  "jira_email": "you@cisco.com",
  "jira_username": "your_jira_user",
  "github_username": "your-github-id"
}
```

---

## Step 4 — GitHub auth (required for PR tracking)

```bash
gh auth login
gh auth status
```

No extra token file needed — `gh` stores credentials in your OS keychain.

---

## Step 4a — Confluence client skill auth/setup (optional, read-only)

Confluence is an optional read-only source for work-track. It uses the `confluence-client` skill to search pages, comments, mentions, and action items. Work-track must never create, edit, delete, or comment on Confluence pages.

Install for Codex:

```bash
npx --registry=https://engci-maven-master.cisco.com/artifactory/api/npm/WebExDev-ai-transformation-npm/ @cisco-aifirst/installer --codex --skills confluence-client
```

Install for Claude Code:

```bash
npx --registry=https://engci-maven-master.cisco.com/artifactory/api/npm/WebExDev-ai-transformation-npm/ @cisco-aifirst/installer --claude --skills confluence-client
```

If install fails with `404` or timeout, confirm Cisco VPN and Artifactory access.

Keep this in `config.json`:

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

No Confluence tokens should be stored in this repository, `config.json`, or `team.json`.

---

## Step 4b — Webex CLI skill auth (required)

Webex CLI is required for complete work-track reports. Work-track does not own Webex authentication; it uses the internal Webex CLI skill for messages, meetings, live transcripts, artifacts, calendar routing, and team check-in signals.

Use your internal Webex CLI skill setup to authenticate and verify these capabilities:

- Search spaces and read recent messages
- Read configured team check-in and code review spaces
- List meeting history by date range and timezone
- Read live transcripts when explicitly requested
- Download/read meeting transcripts, summaries, recordings, and chat logs
- Query upcoming/recent calendar meetings
- Enrich results with linked Confluence pages and Jira issues
- Correlate Webex PR review requests with GitHub PR metadata

No Webex tokens should be stored in this repository, `config.json`, or `team.json`.

Keep this in `config.json`:

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

Populate `spaces` with Webex space names or IDs for your team. `code_review` spaces are used to find messages like "please review this PR"; GitHub is then queried to flag oversized PRs such as changes over 1500 lines.

---

## Step 5 — Jira auth (optional but recommended)

Jira data requires **some** authenticated access. Pick one method:

### Method A: Jira MCP in Cursor (recommended at Cisco)

1. Open **Cursor Settings → MCP**
2. Add servers (or copy from a teammate's template):

```json
{
  "mcpServers": {
    "jira-sjc12": {
      "url": "https://aicoding-mcp.cisco.com/jira-sjc12/",
      "headers": {
        "X-JIRA-TOKEN": "<your-jira-api-token>"
      }
    },
    "jira": {
      "url": "https://aicoding-mcp.cisco.com/jira/",
      "headers": {
        "X-JIRA-TOKEN": "<your-jira-api-token>"
      }
    }
  }
}
```

3. Create token: https://id.atlassian.com/manage-profile/security/api-tokens  
   (or your Cisco Jira token process)
4. **Never commit tokens** to git — MCP settings only
5. Toggle MCP servers **On**, reload Cursor, connect VPN if needed

> **Important:** Cursor reads `~/.cursor/mcp.json`. Claude Code CLI does **not** read that file — and it also does **not** read `~/.claude/mcp.json`.

### Method A2: Jira MCP in Claude Code CLI (required for Jira in terminal)

Claude Code reads MCP from **only** these paths:

| Scope | File |
|-------|------|
| User (all projects) | `~/.claude.json` → top-level `"mcpServers"` |
| Project (this repo) | `.mcp.json` at **project root** (not inside `.claude/`) |

**Wrong paths (ignored):** `~/.claude/mcp.json`, `~/.cursor/mcp.json`, `settings.json`

If you already created `~/.claude/mcp.json`, migrate it:

```bash
# Merge into user scope (correct location)
python3 - <<'PY'
import json
from pathlib import Path
claude = json.loads(Path.home().joinpath(".claude.json").read_text())
src = json.loads(Path.home().joinpath(".claude/mcp.json").read_text())
claude.setdefault("mcpServers", {}).update(src.get("mcpServers", {}))
Path.home().joinpath(".claude.json").write_text(json.dumps(claude, indent=2) + "\n")
print("Migrated:", list(src.get("mcpServers", {}).keys()))
PY

claude mcp list   # should show jira + jira-sjc12 Connected
```

Or use **Option 1** below (`claude mcp add`).

#### Option 1 — CLI (recommended)

Set your token once in the shell (same token as Cursor MCP):

```bash
export JIRA_API_TOKEN="your-jira-api-token"

claude mcp add --transport http -s user jira-sjc12 \
  https://aicoding-mcp.cisco.com/jira-sjc12/ \
  --header "X-JIRA-TOKEN: ${JIRA_API_TOKEN}"

claude mcp add --transport http -s user jira \
  https://aicoding-mcp.cisco.com/jira/ \
  --header "X-JIRA-TOKEN: ${JIRA_API_TOKEN}"
```

Verify:

```bash
claude mcp list
```

Start a **new** Claude Code session, then run `/work-track`.

#### Option 2 — Project `.mcp.json`

In your project folder (e.g. `~/Desktop/work_skill/`):

```bash
cp .mcp.json.example .mcp.json   # from WorkTrackSkill repo
export JIRA_API_TOKEN="your-token"
```

The example uses `${JIRA_API_TOKEN}` — do not hardcode tokens in git.

#### Option 3 — Env vars in `~/.claude/settings.json`

Add under `"env"` (works with `fetch_jira.py` fallback):

```json
"env": {
  "JIRA_USER_EMAIL": "you@cisco.com",
  "JIRA_API_TOKEN": "${JIRA_API_TOKEN}",
  "JIRA_BASE_URL": "https://jira-eng-sjc12.cisco.com/jira"
}
```

Also add to `~/.zshrc`:

```bash
export JIRA_API_TOKEN="your-jira-api-token"
export JIRA_USER_EMAIL="you@cisco.com"
export JIRA_BASE_URL="https://jira-eng-sjc12.cisco.com/jira"
```

Restart Claude Code after editing settings.

#### Cursor vs Claude — config locations

| Tool | Jira MCP config file | Skill folder |
|------|----------------------|--------------|
| **Cursor** | `~/.cursor/mcp.json` | `~/.cursor/skills/work-track/` |
| **Claude CLI** | `~/.claude.json` (user scope) or project `.mcp.json` | `~/.claude/skills/work-track/` |
| **Claude env fallback** | `~/.claude/settings.json` → `"env"` | — |

If Claude shows *"JIRA_API_TOKEN not configured"* but Cursor Jira works, you only configured **Cursor** — add MCP or env vars for **Claude CLI** using the steps above.

### Method B: Environment variables + script

Add to `~/.zshrc`:

```bash
export JIRA_USER_EMAIL=you@cisco.com
export JIRA_API_TOKEN=your_token
export JIRA_BASE_URL=https://jira-eng-sjc12.cisco.com/jira
```

Then the agent can run `fetch_jira.py` from the productivity-tracker scripts.

---

## Step 6 — Team roster (optional)

Edit `team.json` for team reports:

```json
{
  "name": "Teammate Name",
  "jira_email": "teammate@cisco.com",
  "github": "github-username",
  "active": true
}
```

Members without `jira_email` still appear in team reports with GitHub/Confluence/Webex data; Jira fields are marked unavailable for that member.

---

## Step 7 — Try it

In Cursor or Claude:

```
/work-track
```

Or:

- *"Track my weekly work"*
- *"Track my bi-weekly work for sync"*
- *"Work report from 2026-06-01 to 2026-06-15"*
- *"Team work report"*

---

## What happens if Jira access is unavailable?

Work Track builds one work summary and action-items report from all configured sources. If Jira access is unavailable, the report should continue with GitHub/Confluence/Webex data and clearly mark Jira as unavailable.

| Feature | Without Jira token | With Jira token |
|---------|:------------------:|:---------------:|
| PRs opened / merged / open | Yes (`gh`) | Yes |
| PR reviews, GitHub leaderboard | Yes | Yes |
| Active assigned Jira tickets | No | Yes |
| Jira status transitions, comments | No | Yes |
| Work summary/action items | Partial; Jira unavailable noted | Full |
| Team report | Partial; Jira unavailable noted | Full |

### What still works without Jira token

1. **GitHub activity** — after `gh auth login`:
   - PRs opened, merged, closed, open PRs
   - Review activity (where `gh search` allows)

2. **Webex activity** — after Webex CLI auth/sync:
   - Messages, meetings, transcripts, tagged questions, code review requests, action items

3. **Partial team report** — GitHub/Confluence/Webex data per member; Jira columns show as unavailable.

4. **Demo / sample output** (no real data):

   ```bash
   python3 ~/.claude/skills/productivity-tracker/scripts/generate_report.py --demo
   ```

5. **Manual paste** — you can paste Jira ticket lists into chat; the agent formats them but does not fetch live data.

### What does **not** work without Jira auth

- Automated Jira ticket queries for private Cisco Jira
- Jira MCP tools (`mcp_jira`, `mcp_jira-sjc12`)
- `fetch_jira.py` without `JIRA_API_TOKEN`

There is no way to read **private** Cisco Jira anonymously — you need either an API token (MCP or env var) or an authenticated browser session (not supported by this skill today).

### Minimum setup paths

| Goal | Minimum setup |
|------|----------------|
| Partial work summary | Skill install + `config.json` + `gh auth login` + Webex CLI auth/sync |
| Confluence-enriched work summary | Above + `confluence-client` skill |
| Full work summary + action items | Above + Jira MCP token or `JIRA_API_TOKEN` |
| Team reports | Above + `team.json` with `jira_email` and `github` per member |

---

## Updating the skill

```bash
cd WorkTrackSkill
git pull
cp -r * ~/.cursor/skills/work-track/
# or ~/.claude/skills/work-track/
```

If you maintain a Desktop copy:

```bash
# Edit ~/Desktop/work_track_skill/team.json
cp ~/Desktop/work_track_skill/team.json ~/.cursor/skills/work-track/team.json
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Skill not triggering | Restart IDE; say "work track" explicitly |
| Jira `fetch failed` | Refresh MCP; check VPN; rotate token |
| GitHub MCP 401 | Use `gh` CLI instead of GitHub MCP |
| **Claude CLI: no Jira, Cursor works** | Add Jira MCP to Claude (`claude mcp add`) or set `JIRA_API_TOKEN` in `~/.claude/settings.json` — see Method A2 |
| No Jira data, GitHub works | Expected without token — add Jira MCP |
| Hidden `.claude` folder | Finder: `Cmd+Shift+G` → `~/.claude/skills/work-track/` |
| Member missing from report | Add `jira_email` and `github` in `team.json` |

See also [README.md](README.md), [CONFIG.md](CONFIG.md), [reference.md](reference.md).

---

## Security notes

- Do **not** commit `JIRA_API_TOKEN`, `X-JIRA-TOKEN`, or GitHub PATs to the repo
- Store tokens only in `~/.cursor/mcp.json` or shell env vars
- Consider making the GitHub repo **private** if `team.json` contains internal emails
