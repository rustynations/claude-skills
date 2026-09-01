# multi-agent-session

Let two or more **independent, live Claude Code sessions** collaborate by talking through a
shared **GitHub issue**. The issue is the message bus: each agent listens by polling the
issue and speaks by commenting. Any agent, on any machine, that can see the issue can join —
and so can a human.

This is **not** subagents. There is no parent/orchestrator; these are peer sessions that
cannot see each other directly. Coordination lives in the durable issue thread, not in any
one agent's context — so agents are disposable, a fresh one can take over from the record,
and a human is just another voice on the thread.

## Files

- **`SKILL.md`** — the instructions the agent follows (loaded by Claude Code). Written for the
  agent, not for you.
- **`poll-issue.sh`** — the "radio." A blocking poller with two modes:
  - `init <issue> <identity> <repo> <watermark_file>` — mark existing comments as seen.
  - `watch <issue> <identity> <repo> <watermark_file> [interval_s] [max_wait_s]` — block and
    poll; returns only on mail for you (exit 0), a `SESSION DONE` (exit 42), or timeout
    (exit 10 → just run it again). Spends zero LLM tokens while waiting. See the script header
    for details.

## Install

Skills load from `~/.claude/skills/`. Symlink this folder in:

```bash
git clone git@github.com:rustynations/claude-skills.git   # or: git pull in an existing clone
ln -s "$PWD/claude-skills/multi-agent-session" ~/.claude/skills/multi-agent-session
```

(Adjust the path to wherever you keep the repo. A `git pull` updates every user who symlinks.)

## Use

In each session, run:

```
/multi-agent-session <issue> <identity>
```

Same issue number in every session, a distinct name each (e.g. `Architect`, `Builder`,
`Reviewer`). Miss an argument and the skill asks for it. Roles are yours to define — the
skill is role-agnostic.

## How it behaves (the rules, in brief)

- **Sign + address** every comment (`Me:` … `@who` / `@all`); act only if it's for you and needs action (kills echo loops).
- **Gated start** — an agent can join and hold, acting only when told (e.g. `@B2 go`).
- **Keep the record current** — post at each boundary (start / finish-with-evidence / decide / block), fire-and-continue.
- **Blockers go on the thread** — including "waiting on the human," not just in your own window.
- **Re-check before you commit** — read the thread before shipping, so you build current instructions.
- **Keep watching until told to stop** — long silence is normal; stop only on `SESSION DONE` or the human.

## Provenance

These behaviors are not theoretical — each was added after a real multi-agent run surfaced the
failure it prevents (the artifacts-primitive builds, issues #159 → #160 → #161: a framework
build, its recovery from a fouled deploy, and a moderation phase). The skill is battle-tested,
not designed in the abstract.
