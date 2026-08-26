---
name: multi-agent-session
description: Use when this Claude Code session is one of several live agents collaborating on the same GitHub issue at once — a multi-agent session, distinct from spawning subagents. Triggers on /multi-agent-session (or /multiAgentSession), or a request to have two or more running sessions talk, coordinate, poll each other, or hand work off through a shared issue. Symptoms — "have the two terminals talk", "agents coordinate via the issue", spec/reviewer agent + builder agent working the same issue.
---

# Multi-Agent Session

## Overview

You are ONE agent among several, all working the same GitHub issue at the same time.
The **issue is the bus.** Comments are the messages. You listen by polling, and you
speak by commenting. Any agent anywhere that can see the issue can join — no shared
machine, no wire between terminals.

This is NOT a subagent you spawned. These are peer sessions you cannot see directly.

## Required inputs — ask if missing

You need TWO things before doing anything else:

1. **Issue number** — e.g. `159`
2. **Your identity** — a short name, e.g. `Frank`, `DocWriter`, `Builder`

If either is missing from how you were invoked, **STOP and ask the user for it.** Do
not guess an identity. Do not guess the issue.

**Repo:** default to this repo's GitHub remote — `gh repo view --json nameWithOwner -q .nameWithOwner`.
If the issue lives in a different repo (common for scaffold projects: issues live in
`<project>-project`), confirm the repo with the user.

## The five golden rules

1. **Sign** every comment — start it with `<identity>:` (e.g. `Frank:`).
2. **Address** every comment — name who it is for: `@DocWriter` or `@all`.
3. **Watermark** — never re-read old comments. The poll script tracks this for you.
4. **Act only if it is for you AND needs action.** A plain "ok / thanks" ends the chain. Reply to it and you start an echo loop. Silence is allowed.
5. **Stop word** — if anyone posts `SESSION DONE`, stop the loop, sign off, wait for the human.

Ignore your own comments. Frank never acts on Frank.

## Keep the record current

The issue is the shared source of truth. **If it isn't on the thread, no one — agent or
human — can see it.** Post an update (signed, `@all` unless it is for someone), then keep
working — do NOT wait for a reply — when any of these happen:

- You **start** a distinct piece of work, or **change your plan.**
- You **finish** a unit of work — a commit, a deploy, a verification — with the **raw evidence**, not just "done."
- You **make or change a decision.**
- You hit a **blocker — including needing the human** (expired login, a decision, a manual
  check), hand off, or **stand down.** Post it on the thread even if you also ask the human
  in your own window: an out-of-band ask is invisible to the team, and the thread just looks
  like you are working.
- You are about to go **heads-down** for a while — say what you are doing and roughly when
  you will resurface. While working you cannot hear the channel, so a labeled pause beats
  ambiguous silence.

These are boundaries, not chatter — that is the "record, not noise" line. Do not narrate
every step; do mark every turn. A current thread also keeps watchers awake: they wake on
your updates instead of timing out on dead air.

## Workflow

Set variables once (use the project `tmp/` for the watermark file):

```
ISSUE=159
ME=Frank
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
WM=tmp/mas-watermark-${ME}-${ISSUE}.txt
POLL=~/.claude/skills/multi-agent-session/poll-issue.sh
```

**Step 1 — mark history as seen** (so you do not reprocess old comments):

```
"$POLL" init "$ISSUE" "$ME" "$REPO" "$WM"
```

**Step 2 — announce you are here:**

```
gh issue comment "$ISSUE" --repo "$REPO" --body "$ME: @all — online, watching #$ISSUE."
```

**Step 3 — make your opening move, if you have one.** Re-read the issue. Do you hold the
first action or a starting task assigned to you? If yes, DO it now and post the result
**before** you listen. If every agent only listens, nobody starts and the session deadlocks.
No opening move? Skip straight to listening.

**Step 4 — listen.** Run the watcher. It BLOCKS and spends zero tokens while waiting.
It returns only when there is real mail for you, a SESSION DONE, or it times out:

```
"$POLL" watch "$ISSUE" "$ME" "$REPO" "$WM"
```

Read the exit code:
- **0** → new mail printed. Handle it (see Step 5), then run `watch` again.
  - **If it means your goal is met** (your question is answered, the work is agreed or done),
    do not just fall silent — post `SESSION DONE` to close the session.
- **42** → SESSION DONE. Post `"$ME: signing off."` and stop. Tell the human.
- **10** → nothing yet. Just run `watch` again to keep listening.

**Step 5 — reply (only if needed):**

```
gh issue comment "$ISSUE" --repo "$REPO" --body "$ME: @Builder answer is X."
```

Then go back to Step 4. That loop IS the session.

## Common mistakes

| Mistake | Fix |
|---|---|
| Replying to every "ok / thanks" | Only reply if action is needed. Kill the echo. |
| Forgetting to sign or address | Every comment starts `Me:` and names `@who`. |
| Re-answering old comments | Run `init` once at start; trust the watermark. |
| Polling with a tight loop in the LLM | Never. Use `watch` — it blocks in bash, not in tokens. |
| Guessing your identity | Ask the user. |
| Everyone listens, nobody starts | The agent with the first move acts BEFORE listening (Step 3). |
| Goal met but nobody closes | When your objective is done or agreed, post `SESSION DONE`. Do not treat agreement as a silent ack. |
| Letting the record go stale | Post at each boundary (start / finish / decide / block). The thread is the source of truth. |
| Going heads-down silently | Say what you are doing and when you will resurface. Silence reads as stalled. |
| Asking the human out-of-band | Need the human? Post the blocker on the thread too — your own window is invisible to the team. |
| Never stopping | Watch for `SESSION DONE`, or let the human stop you. |

## Notes

- The watcher blocks up to ~9 min per call (under the 600s Bash timeout), then exits 10 so you re-run it. This is normal; keep re-running.
- All agents share one GitHub login, so mail is matched by TEXT (`@name` / `@all`), not by author. That is why signing and addressing are mandatory.
