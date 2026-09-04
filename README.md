# claude-skills

A curated collection of Claude Code skills for software development workflows — code review, security scanning, repo evaluation, and GitHub workflow automation.

## What Are Claude Code Skills?

Skills are markdown files with YAML frontmatter that Claude Code loads on demand. Place them in your `.claude/commands/` directory, and they become available as slash commands (e.g., `/adversarialReview`). Skills standardize repeatable workflows so you get consistent, high-quality output every time.

## Active Skills

| Skill | Purpose |
|-------|---------|
| **adversarialReview** | Pre-PR last-look review using scored adversarial agents (Finder/Adversary/Referee) — surfaces logic errors, edge cases, and security blind spots in working code |
| **checkup** | Periodic health check of Claude Code setup — analyzes usage, config, and session history to surface dead weight, config friction, and missed features |
| **fix-dependabot** | Scan and fix Dependabot security alerts across all component repos — audits each, creates worktrees with fixes, and opens PRs |
| **gitflow** | Automate GitHub issue and PR workflow — create issues, suggest branches, ensure PRs reference issues |
| **reviewRepo** | Evaluate a third-party GitHub repo for adoption, extraction, or skipping |

## Related Repos

| Repo | Purpose |
|------|---------|
| [**multi-agent-session-communication**](https://github.com/rustynations/multi-agent-session-communication) | The `multi-agent-session` skill in its own repo — peer Claude Code sessions coordinating over a shared GitHub issue as the message bus |

## Archived Skills

Legacy skills from the original collection are in `archived/`. These were either superseded by [superpowers](https://github.com/anthropics/claude-code-plugins) plugins or never adopted into active use. They remain available for reference but are not maintained.

## Installation

### Download individual skills (recommended)

Download the skills you want directly into your `.claude/commands/` directory:

```bash
mkdir -p ~/.claude/commands
curl -o ~/.claude/commands/adversarialReview.md https://raw.githubusercontent.com/rusty428/claude-skills/main/adversarialReview.md
```

Each `.md` file is self-contained — drop it in and it's available as a slash command.

### Clone the full repo

```bash
git clone https://github.com/rusty428/claude-skills.git
```

Then copy whichever skills you need into your `.claude/commands/` directory.

## Skill Format

Each skill is a standalone markdown file with YAML frontmatter:

```yaml
---
name: skillName
description: One-line description used for trigger matching
---
<!-- Version: YYYY-MM-DD.N -->

# Skill Title

Instructions that Claude follows when the skill is invoked.
```

- **name**: How Claude identifies and invokes the skill
- **description**: Used for matching when Claude decides which skill applies
- **Version comment**: Tracks when the skill was last updated (format: `YYYY-MM-DD.N` where N is the revision number for that date)

## License

MIT License. See [LICENSE](LICENSE) for details.
