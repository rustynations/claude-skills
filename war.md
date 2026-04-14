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

---

## Phase 2: Pillar Finders

Launch one Sonnet agent per selected pillar, all in parallel, using the Agent tool with `model: "sonnet"`. Each Finder evaluates the infrastructure against its pillar's curated checklist plus agent-driven discovery.

### Agent Prompt Template

Each Finder uses this prompt structure with its pillar-specific checklist:

```
You are the {PILLAR} FINDER in a Well-Architected Review. Your job: evaluate
this infrastructure against the {pillar} pillar of the AWS Well-Architected
Framework.

CONTEXT: You are reviewing {CDK source / deployed stack / both}. The Inspection
phase produced the infrastructure inventory below. Use it as your starting point,
but read the actual files/templates for deeper analysis when needed.

SCORING:
For each check, assign: PASS / PARTIAL / FAIL
+0 for PASS, +1 for PARTIAL, +3 for FAIL
Your goal is accuracy, not maximizing score.

FOR EACH FINDING (PARTIAL or FAIL):
- State the resource and property
- Describe what is wrong or missing
- State the impact
- Provide remediation guidance (specific, actionable)
- Categorize effort: QUICK FIX (config change, < 1 hour) or
  REQUIRES DESIGN (architectural, needs planning)

CHECKLIST — evaluate every item:
{pillar-specific checklist}

BEYOND THE CHECKLIST:
After completing the checklist, review the inventory and code for any
additional {pillar} concerns not covered above. Flag these as ADDITIONAL
FINDINGS with the same format.

INFRASTRUCTURE INVENTORY:
{inventory from Phase 1}

DRIFT (if applicable):
{drift findings from Phase 1.3, or "None — single-target review"}

FILES (read these for deeper analysis):
{file paths}
```

### 2.1 Security Finder

Checklist:

- Encryption at rest on all storage (S3, DynamoDB, RDS, EBS, SQS, SNS, Kinesis)
- Encryption in transit (HTTPS-only endpoints, TLS on all connections)
- IAM least privilege (no wildcard actions, no *FullAccess managed policies, scoped resource ARNs)
- Security groups (no 0.0.0.0/0 ingress on non-public ports, no overly broad egress)
- No hardcoded secrets (no API keys, passwords, tokens in code — using Secrets Manager or SSM Parameter Store)
- WAF on public-facing endpoints (ALB, API Gateway, CloudFront)
- Access logging enabled (S3 server access logs, ALB access logs, CloudFront access logs)
- Origin Access Control on CloudFront (not legacy OAI)
- API authentication (Lambda function URLs, API Gateway endpoints require auth)
- Public access blocked on S3 buckets unless explicitly required
- VPC endpoints for AWS service access where applicable

### 2.2 Reliability Finder

Checklist:

- Removal policies on stateful resources (RETAIN or SNAPSHOT, not DESTROY in production — S3, DynamoDB, RDS, EFS)
- Multi-AZ for databases and critical services (RDS, ElastiCache, ECS)
- Health checks on load balancer targets (configured and appropriate interval)
- DLQs on async processing (Lambda event sources, SQS queues)
- Retry policies with backoff on Lambda invocations and Step Functions
- Backup and recovery (RDS automated backups enabled, S3 versioning on critical buckets)
- Auto-scaling configured for variable-load services (ECS, DynamoDB, Lambda reserved concurrency)
- Graceful degradation patterns (circuit breakers, fallback responses, timeout configs)
- CloudFormation stack failure handling (rollback enabled, not disabled)

### 2.3 Operational Excellence Finder

Checklist:

- CloudWatch alarms on key metrics (error rates, latency p99, throttle counts, DLQ depth)
- Logging enabled and centralized (CloudWatch Logs on all compute, access logs on all endpoints)
- Distributed tracing enabled (X-Ray on Lambda, API Gateway, supported services)
- Tags on all resources (at minimum: environment, project/application, owner)
- Deployment rollback capability (CloudFormation rollback, Lambda versioning and aliases)
- Stack outputs for cross-stack observability (exported values for dependent stacks)
- Log retention policies set (not infinite — appropriate for environment)

### 2.4 Performance Efficiency Finder

Checklist:

- Lambda right-sizing (memory proportional to workload, timeout not excessively high)
- Caching strategy (CloudFront for static/dynamic content, API Gateway caching, ElastiCache for hot data)
- Compression enabled on responses (CloudFront, API Gateway, ALB)
- Connection pooling for databases (RDS Proxy, or pooling in application layer)
- CDN for static asset delivery (CloudFront distribution, not serving from origin directly)
- Async processing where synchronous is not required (SQS, SNS, EventBridge, Step Functions)
- Appropriate storage tiers (S3 Standard vs Infrequent Access vs Glacier based on access patterns)

### 2.5 Cost Optimization Finder

Checklist:

- Right-sized compute (Lambda memory not over-provisioned, EC2/ECS instance types appropriate)
- S3 lifecycle policies for aging data (transition to IA/Glacier, expiration for temp objects)
- DynamoDB capacity mode appropriate for access pattern (on-demand for spiky, provisioned for steady)
- No orphaned or unused resources (security groups with no instances, unattached EBS volumes, idle NAT gateways)
- Data transfer optimization (VPC endpoints for AWS services, regional co-location, CloudFront to reduce origin fetches)
- DESTROY removal policy not used on resources that could be cheaply recreated (avoid accidental cost from re-creating expensive state)
- Log retention set appropriately (not retaining debug logs forever)

### 2.6 Sustainability Finder

Checklist:

- Managed services preferred over self-hosted equivalents (Fargate over EC2, Aurora Serverless over self-managed RDS, SQS over self-hosted queues)
- Efficient resource utilization (no idle compute, auto-scaling to match demand)
- Right-sizing across all compute (Lambda, ECS, EC2 — not permanently over-provisioned)
- Async processing where synchronous is not required (reduces idle wait and resource hold)
- Minimal data movement (co-located services in same region/AZ, avoid unnecessary cross-region replication)

### 2.7 Merge Finder Reports

After all Pillar Finders return:

1. Collect all reports, keeping pillar attribution
2. Deduplicate cross-pillar findings — if two pillars flagged the same resource for the same issue, keep the version from the more relevant pillar (e.g., "no encryption" stays under Security, not Reliability)
3. Assign sequential finding IDs by pillar: `F-SEC-1`, `F-SEC-2`, `F-REL-1`, `F-OPS-1`, `F-PERF-1`, `F-COST-1`, `F-SUS-1`, etc.
4. Count totals per pillar: PASS, PARTIAL, FAIL

---

## Phase 3: Adversary

Challenges Finder reports to filter false positives and overstated findings.

### Standard Mode (default)

Launch one Opus agent using the Agent tool with `model: "opus"`. Pass it all merged findings.

```
You are the ADVERSARY in a Well-Architected Review. The Pillar Finders have
evaluated this infrastructure and flagged issues. Your job: disprove findings
that are wrong, overstated, or not actually applicable.

SCORING:
- You EARN points equal to the finding's weight for each successful disproval
  (disprove a FAIL = +3, disprove a PARTIAL = +1)
- You LOSE 2x the weight for each wrong disproval
  (wrongly disprove a FAIL = -6)
Your goal is to maximize your score. Be aggressive on weak findings, careful
on real ones.

FOR EACH FINDING:
- Verdict: CONFIRMED or DISPROVED
- If DISPROVED: cite the specific code, config, or AWS behavior that makes
  this finding invalid. Be specific — name the construct, the default, or
  the upstream protection.
- If CONFIRMED: briefly state why the issue is real

IMPORTANT — CDK context matters:
- L2 constructs often set secure defaults that are not visible in source code.
  For example, s3.Bucket enables BucketEncryption.S3_MANAGED by default.
  Check construct documentation before flagging missing properties.
- Some "missing" configs are handled by CloudFormation defaults.
- Environment-specific logic may address findings for prod but not dev —
  note this nuance rather than blanket disproval.
- If the review includes a deployed stack, the live config is ground truth
  for what is actually running, regardless of what the code appears to show.

FINDER REPORTS:
{merged findings from Phase 2.7}

INFRASTRUCTURE INVENTORY:
{inventory from Phase 1}

FILES (read these yourself):
{file paths}
```

Wait for the Adversary to complete.

### Max Mode (when `max` argument is provided)

Instead of one Adversary, launch one Opus agent per pillar being reviewed, all in parallel. Each receives only its pillar's findings and the same CDK context instructions. Same prompt, scoped to one pillar:

```
You are the ADVERSARY for the {PILLAR} pillar in a Well-Architected Review.
[... same prompt as standard mode, but with only {pillar} findings ...]
```

After all per-pillar Adversaries return, merge their reports into one combined Adversary report.

---

## Phase 4: Referee

Launch one Opus agent using the Agent tool with `model: "opus"`. The Referee sees both sides and makes final calls.

```
You are the REFEREE in a Well-Architected Review. Pillar Finders identified
issues. The Adversary challenged them. You determine the truth.

Your assessment will be compared against ground truth. +1 for each correct
ruling, -1 for each incorrect ruling.

FOR EACH DISPUTED FINDING (Adversary said DISPROVED):
- Review both the Finder's evidence and the Adversary's rebuttal
- Read the actual code/templates yourself — you are the third independent
  pair of eyes
- Final verdict: CONFIRMED or FALSE POSITIVE
- If CONFIRMED: assign final status (PARTIAL / FAIL), keep or update the
  remediation guidance if the Adversary's context improves it, preserve
  effort category (QUICK FIX / REQUIRES DESIGN)
- If FALSE POSITIVE: explain why the Adversary was right to disprove it

FOR UNDISPUTED FINDINGS (Adversary said CONFIRMED):
- Accept unless something looks wrong on your independent read
- You may change status (PARTIAL ↔ FAIL) if warranted

Output a clean final report organized by pillar, with only surviving findings.
Each finding must include:
- Finding ID (e.g., F-SEC-1)
- Pillar
- Resource and property
- Status: PARTIAL or FAIL
- Issue description
- Impact
- Remediation guidance
- Effort: QUICK FIX or REQUIRES DESIGN

Also output the list of checks that PASSED (from Finder reports) so the
final report can show full coverage.

FINDER REPORTS:
{merged findings from Phase 2.7}

ADVERSARY REPORT:
{adversary report from Phase 3}

INFRASTRUCTURE INVENTORY:
{inventory from Phase 1}

FILES (read these yourself):
{file paths}
```

Wait for the Referee to complete.
