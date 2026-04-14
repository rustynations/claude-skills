---
name: war
description: >
  AWS Well-Architected Review using scored adversarial agents. Reviews CDK source,
  deployed CloudFormation stacks, or both against all 6 Well-Architected pillars.
  Produces scored findings with remediation guidance.
argument-hint: "<target: ./path or stack:Name --profile X> [pillars...] [max]"
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Agent
  - Write
user-invocable: true
---
<!-- Version: 2026-04-14.1 -->

# AWS Well-Architected Review (WAR)

Scored multi-agent infrastructure review using the adversarial pattern (Finders / Adversary / Referee) across the six AWS Well-Architected Framework pillars. Reviews CDK source code, deployed CloudFormation stacks, or both.

**When to use:** You have AWS infrastructure to evaluate — a CDK project, a running stack, or both. This produces a scored report with remediation guidance, not in-session fixes.

**What it does NOT do:** Business process evaluation (runbooks, change management), cost estimation, compliance certification (SOC2, HIPAA, PCI), or in-session infrastructure patching.

---

## Phase 0: Parse Arguments + Confirm

### 0.1 Parse Input

Parse `$ARGUMENTS` for:

- **Target(s):**
  - CDK source path: a relative or absolute directory path (e.g., `./infra`, `../myproject/infra`)
  - Deployed stack: `stack:<name> --profile <profile>` (e.g., `stack:MyStack --profile prod`)
  - Both can be provided together
- **Pillars** (optional): any of `security`, `reliability`, `operational`, `performance`, `cost`, `sustainability`
  - Default: all 6
- **Mode** (optional): `max` enables per-pillar Adversary agents
  - Default: standard (single Adversary)

**Examples:**

```
/war ./infra
/war stack:MyStack --profile prod
/war ./infra stack:MyStack --profile prod
/war ./infra security reliability
/war ./infra security max
/war
```

### 0.2 Gather Missing Input

If no target was provided, ask:

> "What should I review? Provide one or both of:
> - A CDK project path (e.g., `./infra`)
> - A deployed stack name with profile (e.g., `stack:MyStack --profile prod`)"

Wait for the user's response before proceeding.

### 0.3 Confirm Intent

Always confirm before spawning agents, regardless of how complete the input was:

```
Ready to run a Well-Architected Review:
  Target:  {target description}
  Pillars: {list of pillars, or "All 6"}
  Mode:    {Standard (single Adversary) or Max (per-pillar Adversary)}

Proceed?
```

Do not spawn any agents until the user confirms.
