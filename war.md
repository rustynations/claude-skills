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

---

## Phase 1: Inspection

The goal is to produce a structured infrastructure inventory that Pillar Finders work from. Launch a single Sonnet agent using the Agent tool with `model: "sonnet"`.

The inspection mode depends on what targets were provided:
- CDK source only → Section 1.1
- Deployed stack only → Section 1.2
- Both → Sections 1.1, 1.2, and 1.3

### 1.1 CDK Source Inspection (when path provided)

```
You are the INFRASTRUCTURE INSPECTOR in a Well-Architected Review. Your job:
read the CDK project and produce a structured inventory of all infrastructure
resources and their configurations.

CDK PROJECT PATH: {path}

INSTRUCTIONS:
1. Use Glob to find all stack and construct files (*.ts, *.py, *.java, *.go
   matching CDK patterns)
2. Read each file and catalog:
   - Stack names and their construct trees
   - Every AWS resource by type (S3, Lambda, IAM, DynamoDB, CloudFront,
     API Gateway, SQS, SNS, RDS, ECS, EC2, CloudWatch, WAF, etc.)
   - Configuration properties on each resource: encryption settings, removal
     policies, logging config, timeout values, memory sizes, security groups,
     IAM policies, environment variables, tags
   - Cross-stack references and dependencies
   - Environment-specific logic (prod vs dev conditionals, stage parameters)

3. Output a structured inventory in this format:

Stacks:
  - StackName: [list of construct IDs]

Resources:
  S3:
    - BucketName: { encryption: X, versioning: X, removalPolicy: X,
                    logging: X, publicAccess: X, lifecycle: X }
  Lambda:
    - FunctionName: { runtime: X, memory: X, timeout: X, tracing: X,
                      reservedConcurrency: X, dlq: X, env: [keys only] }
  IAM:
    - RoleName: { managedPolicies: [...], inlinePolicies: [summary],
                  trust: [...] }
  [... all resource types found ...]

Cross-Stack References:
  - StackA exports X, consumed by StackB

Environment Logic:
  - [any prod/dev/stage conditionals noted]

Be thorough. Every resource and every configuration property matters for the
review. If a property is not explicitly set, note it as "default" — the
Finders need to know what was left to defaults.
```

### 1.2 Deployed Stack Inspection (when stack reference provided)

```
You are the INFRASTRUCTURE INSPECTOR in a Well-Architected Review. Your job:
inspect the deployed CloudFormation stack and produce a structured inventory.

STACK: {stack_name}
PROFILE: {profile}

INSTRUCTIONS:
1. Get the synthesized template:
   aws cloudformation get-template --stack-name {stack_name} --profile {profile}

2. Get the resource list with physical IDs:
   aws cloudformation describe-stack-resources --stack-name {stack_name} --profile {profile}

3. Get stack metadata (outputs, parameters, tags):
   aws cloudformation describe-stacks --stack-name {stack_name} --profile {profile}

4. Pull live resource configs when the template alone is insufficient to
   determine compliance. Examples:
   - aws s3api get-bucket-encryption --bucket {name} --profile {profile}
   - aws s3api get-bucket-logging --bucket {name} --profile {profile}
   - aws s3api get-public-access-block --bucket {name} --profile {profile}
   - aws lambda get-function-configuration --function-name {name} --profile {profile}
   - aws iam get-role --role-name {name} --profile {profile}
   - aws iam list-attached-role-policies --role-name {name} --profile {profile}

5. Output the same structured inventory format as CDK Source Inspection:
   Stacks, Resources (by type with config properties), Cross-Stack References.

Run one AWS CLI command per Bash call. Do not chain commands.
```

### 1.3 Drift Detection (when both provided)

After both inspections complete, compare the inventories:

- Resources in CDK source but not deployed (or vice versa)
- Configuration mismatches (e.g., code says `versioning: enabled`, deployed has `versioning: suspended`)
- Properties set in code but overridden in the deployed stack

Format drift findings as:

```
Drift:
  - ResourceName: code says {X}, deployed has {Y}
  - ResourceName: exists in code but not deployed
  - ResourceName: deployed but not in code
```

Pass drift findings to ALL Pillar Finders as additional context.
