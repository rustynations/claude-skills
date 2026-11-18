---
name: gitflow
description: Automate GitHub issue and PR workflow — create issues for parked items, ideas, and cross-project bugs; suggest branching when editing on main; ensure PRs reference issues. Use when parking work, deferring a bug, noting an idea, writing a handoff doc, starting or finishing a unit of work, or checking project status.
---
<!-- Version: 2026-03-16.1 -->

# GitHub Workflow Automation

Manage issues, branches, and PRs across a multi-project workspace. Auto-triggers on workflow moments; always confirms before acting.

## Trigger Detection

Assess the current context and offer the **first matching** action (priority order). Do NOT chain actions.

| Priority | Signal | Action |
|----------|--------|--------|
| 1 | User invokes `/gitflow status` or `/gitflow` with no other context | **Check Status** |
| 2 | User says "park this", "come back to this", "not fixing now", "defer" | **Create Issue** — `parked` |
| 3 | User says "that's an idea", "idea:", "might be cool to", "we could", "future enhancement" | **Create Issue** — `idea` |
| 4 | User spots a bug in a different project than the current working directory | **Create Issue** — `bug` on the other project's scaffold repo |
| 5 | A handoff doc was just written to `docs/working/` | **Create Issue** — ask: `blocker` or `bug`? |
| 6 | User is on a feature branch and signals work is done | **Close via PR** |
| 7 | User is on `main` with uncommitted changes forming a coherent unit of work | **Suggest Branch + PR** |

**"Idea" detection** relies on explicit phrases listed above, not inference. If no phrase is present, ideas are only captured via manual `/gitflow` invocation.

## Labels

Four labels used across all repos. Create on demand if missing from the target repo.

| Label | Color | gh create command |
|-------|-------|-------------------|
| `blocker` | `B60205` | `gh label create blocker --color B60205 --description "Blocks progress — fix before moving forward"` |
| `bug` | `D73A4A` | `gh label create bug --color D73A4A --description "Defect, not blocking"` |
| `parked` | `FBCA04` | `gh label create parked --color FBCA04 --description "Deferred — will come back to it"` |
| `idea` | `0E8A16` | `gh label create idea --color 0E8A16 --description "Not committed to — future consideration"` |

Before creating a label, check if it already exists: `gh label list --repo <repo> --search <label>`. Skip creation if it exists (even if color differs).

### Area labels

Every issue gets one type label above **plus at least one area label**. An area says which part of the project the work touches, so a filter finds it and an agent reading the issue knows where to look.

Areas are per project. Read them from the project's `manifest.json` → `issueAreas`, a map of label name to meaning. Use only labels from that map. If the project has no `issueAreas`, skip area labels.

If the map has an umbrella label (e.g. "every surface"), add the umbrella **and** each label it covers.

## Repo Conventions

- **GitHub user:** `<YOUR-GITHUB-USER>`
- **Issues** go in scaffold repos (`<project>-project`) — project-level tracking
- **PRs** go in component repos (where the code lives)
- **Cross-repo close syntax:** always use `Fixes <YOUR-GITHUB-USER>/<scaffold-repo>#N` (short `#N` only works same-repo)
- **Branch naming:** `fix/<slug>`, `feat/<slug>`, or `chore/<slug>` — kebab-case

## Action: Create Issue

1. **Determine target repo:**
   - Current project → scaffold repo: `<project-dir-name>-project`
   - Cross-project → ask which project, then use `<that-project>-project`
2. **Ensure label exists** on target repo (see Labels section)
3. **Compose:**
   - Title: concise, from conversation context
   - Label: one of `blocker`, `bug`, `parked`, `idea`
   - Areas: one or more from the target project's `issueAreas` (see Area labels)
   - Body: 2-3 sentences max. Problem + origin. For cross-project issues, include `**Origin:** Discovered while working in <current-project>.`
4. **Confirm:** present the title, labels, and target repo. Ask yes/no.
5. **Execute:**
   ```
   gh issue create --repo <YOUR-GITHUB-USER>/<repo> --label <label> --label <area> --title "<title>" --body "<body>"
   ```
6. **Report:** display the issue URL

## Action: Suggest Branch + PR

**Scope:** only handles uncommitted changes on `main`. Moving existing commits off `main` is out of scope.

1. **Detect:** current branch is `main` AND there are staged or unstaged changes
2. **Suggest branch name** based on the work: `fix/<slug>`, `feat/<slug>`, or `chore/<slug>`
3. **Confirm:** "Create branch `<name>` and open a PR?" — yes/no
4. **Execute:**
   - `git fetch origin` — ensure local refs are current before branching
   - `git checkout -b <branch-name>`
   - `git add <specific-files>` (not `git add .` or `git add -A`)
   - `git commit -m "<message>"` — message derived from PR title
   - `git push -u origin <branch-name>`
   - `gh pr create --title "<title>" --body "<body>"`
5. **Link issues:** search for related open issues in the scaffold repo. If found, include `Fixes <YOUR-GITHUB-USER>/<scaffold-repo>#N` in the PR body.
6. **Report:** display the PR URL

## Action: Close via PR

1. **Detect:** on a feature branch, user signals work is complete
2. **Check:** find the open PR for the current branch. Find related open issues.
3. **Confirm:** "Ready to merge PR #N (squash)? This will close issue #N." — yes/no. Only ask about strategy if the user explicitly requests merge or rebase.
4. **Ensure** the PR body contains `Fixes <YOUR-GITHUB-USER>/<scaffold-repo>#N` (full cross-repo syntax). Edit the PR body if needed before merging.
5. **Execute:** `gh pr merge --squash` (unless user requested a different strategy)
6. **Cleanup:** "Delete branch `<name>`?" — yes/no. If yes: `git checkout main && git pull && git branch -d <branch>`
7. **Report:** confirm PR merged, issue closed, branch deleted

## Action: Check Status

1. **Query open issues** (gitflow labels only):
   ```
   gh search issues --owner <YOUR-GITHUB-USER> --state open --label blocker
   gh search issues --owner <YOUR-GITHUB-USER> --state open --label bug
   gh search issues --owner <YOUR-GITHUB-USER> --state open --label parked
   gh search issues --owner <YOUR-GITHUB-USER> --state open --label idea
   ```
2. **Query open PRs:**
   ```
   gh search prs --owner <YOUR-GITHUB-USER> --state open
   ```
3. **Scope:** if invoked within a project, ask "This project only or all projects?"
   - Current project: filter by `--repo <YOUR-GITHUB-USER>/<project>-project`
4. **Present** as a grouped summary:
   - **Blockers** (count) — list titles and repos
   - **Bugs** (count) — list titles and repos
   - **Parked** (count) — list titles and repos
   - **Ideas** (count) — list titles and repos
   - **Open PRs** (count) — list titles and repos

## Rules

1. **Always confirm** — never auto-execute any GitHub action (issue create, branch, merge, delete)
2. **One action per trigger** — do not chain actions. After completing one, stop.
3. **Minimal body content** — issue bodies are 2-3 sentences, not essays
4. **Actions, not context** — only trigger on work done (edits, commits, handoff docs written), never on files read or code explored
5. **Labels on demand** — check and create labels before creating issues
6. **No Co-Authored-By** — never include Co-Authored-By lines in commit messages
