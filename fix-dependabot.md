---
name: fix-dependabot
description: Scan and fix Dependabot security alerts across all component repos in a project. Run from the project root (scaffold repo). Reads manifest.json for components, audits each, fixes and verifies them, and lands the fixes.
---
<!-- Version: 2026-09-27.1 -->

# Fix Dependabot Security Alerts

Scan all component repos in a project, fix vulnerable dependencies, and land the fixes.

🔴 **`npm audit fix` alone typically clears only about half the alerts.** The rest are blocked by one of five specific causes. Read "Why audit fix fails" before concluding a package is unfixable — the classic mistake is reporting "needs manual intervention" when the real blocker was an exact pin or a stale override.

## Prerequisites

- Run from the **project root** (scaffold repo directory)
- `manifest.json` must exist with a `components` object
- Component directories must exist locally
- `gh` CLI authenticated

## Bash Rules

**Never chain commands in an interactive Bash call.** Each call must be a single operation:
- `cd` must be its own separate Bash call — never `cd /path && npm audit`
- No `&&`, `;`, `||`, or pipes
- No `--jq` flag on `gh api` — it counts as a pipe. Redirect the raw JSON to `tmp/` instead, then read it
- Redirects (`>`) to write output files are OK
- After `cd`, the working directory persists for subsequent Bash calls

**For repetitive work across many components, write a shell script to the project's `tmp/` and run that.** One script is one Bash call, so pipes and loops inside it are fine, and it avoids hundreds of round trips. Give it a per-component safety gate (skip dirty trees, revert on a new failure) and have it append a one-line result per component to a TSV you read afterwards. Run it with `run_in_background` when it will take more than a minute or two.

Reading the alert JSON with `jq` from a script is fine — the ban is on `gh api --jq` and on pipes in interactive calls, not on `jq` itself.

**macOS note:** BSD `grep` has no `-P`. Use `awk` for anything beyond a fixed-string match.

## Why audit fix fails — check these five first

Every one of these looks like "unfixable" in `npm audit` output but is not.

| Cause | Symptom | Fix |
|---|---|---|
| **Exact pin, not a range** | `audit fix` reports a fix is available, then changes nothing | `package.json` has `"pkg": "1.2.3"` with no caret. There is no room inside the range. Bump the pin explicitly |
| **Stale override blocking the fix** | Same as above, and the package has an `overrides` entry | A past security fix was pinned exactly and has itself gone vulnerable. **The exact pin actively prevents the new fix.** Convert it to `>=<patched>` so future patches flow |
| **Nested lockfile never visited** | GitHub's count does not drop after a clean local audit | A sub-package (`ui/`, `web/`, `tools/*`) has its own lockfile. A root-level fix never touches it |
| **Pushed to a non-default branch** | Alerts unchanged after a successful push | Dependabot only watches the **default** branch. A fix on `dev`/`staging` counts for nothing |
| **Range too tight on a direct dep** | "Will install X, which is a breaking change" | If it is a **direct** dependency, bump its range yourself. That is not the same as `--force`, which bumps everything blindly |

Only after ruling out all five should a package be classified as genuinely blocked (see Step 4).

## Discovery — before fixing anything

1. **Find every dependency manifest**, not just the root one:
   ```bash
   find <component-path> -name package-lock.json -not -path '*/node_modules/*' > <project-root>/tmp/locks.txt
   ```
   ```bash
   find <component-path> -name pnpm-lock.yaml -not -path '*/node_modules/*' >> <project-root>/tmp/locks.txt
   ```
   Also check for `requirements.txt` (Python CDK) — Dependabot watches those too and `npm audit` will never see them.

2. **Confirm the default branch matches the local branch.** Do this per component, before any work:
   ```bash
   gh repo view <owner>/<repo> --json defaultBranchRef > <project-root>/tmp/<component>-branch.json
   ```
   ```bash
   git -C <component-path> rev-parse --abbrev-ref HEAD
   ```
   If they differ, do **not** fix on the checked-out branch. Use a temporary worktree on the default branch so the user's working copy is left alone:
   ```bash
   git -C <component-path> worktree add <absolute-path>/.worktrees/dependabot-default <default-branch>
   ```
   Remove it when done. Never merge the user's feature branch into the default branch to deliver a dependency fix.

3. **Cross-reference GitHub's alert manifest paths** with the lockfiles you found. `jq` the `.dependency.manifest_path` field out of the alerts JSON — it names exactly which file each alert belongs to, which makes hidden sub-packages obvious immediately.

## Phase 1 — Scan (GitHub API)

Use the **Dependabot API** to get the authoritative list of open alerts. This reflects what GitHub sees, regardless of local lockfile state.

1. Read `manifest.json` from the current directory
2. For each component that has a `repo` field, fetch alerts to a temp file (do NOT use `--jq` — it triggers pipe-blocking hooks):
   ```bash
   gh api repos/<owner>/<repo>/dependabot/alerts > <project-root>/tmp/<component>-alerts.json
   ```
   Then read and parse the JSON file with the Read tool. Extract open alerts: number, package name, severity, summary, scope (dev/runtime), and whether a fix is available.
3. Present a summary table per component:

   ```
   Component          Alerts  Critical  High  Medium  Low
   project-infra         18         1     9       7    1
   project-web            5         0     2       3    0
   project-admin          0         —     —       —    —

   project-infra alerts:
     #12  handlebars       CRITICAL  Prototype pollution
     #13  handlebars       HIGH      XSS
     ...
   ```

4. Skip components with zero alerts
5. Ask: **"Fix all N components with alerts, or pick specific ones?"**

Wait for confirmation before proceeding.

**Why the API instead of `npm audit`:** Local `npm audit` reflects the current lockfile state — if a previous fix branch already patched the lockfile, `npm audit` shows zero alerts even though the PR hasn't merged and GitHub still shows them open. The API is the source of truth.

## Phase 2 — Fix (per selected component)

For each component, run these steps sequentially:

### Step 1: Pick where the work happens

Ask once, for the whole run, then honour it for every component:

- **Commit to the default branch directly** (the usual answer for a solo repo) — work in place, no worktree, no PR
- **Branch + PR per component** — only when the user wants to review each diff

Either way, **a worktree is required in two cases**:

1. The local checkout is on a **non-default** branch (from Discovery step 2)
2. The working tree is **dirty** — never touch uncommitted work. If it is dirty and on the default branch, skip the component and say so

Working in place:

```bash
cd <component-path>
```

```bash
npm install
```

(Use `pnpm install` for pnpm components. If pnpm exits non-zero on `ERR_PNPM_IGNORED_BUILDS`, the install actually succeeded — it is refusing to run an unapproved build script. Add the package to `allowBuilds` in `pnpm-workspace.yaml` rather than treating it as a failed install.)

This ensures `node_modules` exists before audit or test steps.

### Step 2: Baseline — build AND test

🔴 **Capture the baseline before changing anything.** Without it you cannot tell a regression from a repo that was already broken, and plenty of them are.

```bash
npm run build
```

```bash
npm test
```

Also run `npm run synth` here if the component has one.

Record for each: exit code, **the number and text of any build errors**, and **the total test count** alongside pass/fail. Step 5 and Step 6 compare against these exact numbers.

Anything failing here is **pre-existing** — not caused by your change. Note it and continue; do not try to fix it.

### Step 3: npm audit fix

Run this in the component root, and then **separately in every directory that has its own lockfile** (from Discovery step 1). A root-level run does not reach a nested lockfile, and npm workspaces are the exception — there the root lockfile covers all members.

```bash
npm audit fix
```

Expect this to clear roughly half. Step 4 handles the rest.

### Step 4: Check remaining alerts

Run `npm audit --json` locally to see what's resolved. Cross-reference with the Phase 1 API results to map fixes back to specific Dependabot alert numbers.

```bash
npm audit --json
```

Parse the output. First run `npm ls <package>` on anything still listed — it shows which parent pulls the bad version in, which decides the category.

Classify remaining alerts:

**Exact pin on a direct dependency** — `audit fix` says a fix exists but changes nothing:
- Check `package.json` for a version with no caret (`"aws-cdk-lib": "2.247.0"`)
- Bump the pin explicitly, keeping the exact-pin style if that was deliberate:
  ```bash
  npm install --save-exact <package>@<patched-version>
  ```
- This is the single most common cause of a "stuck" alert

**Stale override** — the package already has an `overrides` entry and is still flagged:
- 🔴 An exact-pinned override is a **fix that expired**. It was correct once; the pinned version is now itself vulnerable, and because it is exact it blocks `audit fix` from resolving the advisory at all
- Convert every exact pin to a minimum range so patches flow: `"1.1.13"` → `">=1.1.18"`
- Constrain the major line when a consumer needs the old API: `">=1.1.18 <2"`
- Verify it bit: the resolved version must actually change after `npm install`

**Range too tight on a direct dependency** — "which is a breaking change":
- If the package is a **direct** dependency, raise its range yourself and verify with build + test. A caret on a `0.x` version only allows that minor (`^0.27.3` can never reach `0.28.x`), so this is common and usually harmless
- This is **not** `npm audit fix --force`. Bumping one named direct dependency with verification is safe; `--force` bumps everything blindly and is still banned

**Transitive with no direct-dep route** — add an `overrides` entry:
- Use ranges, never exact pins — an exact pin here becomes the next stale override
- Example: `"overrides": { "qs": ">=6.16.0" }`
- If `overrides` already exists, merge into it (do not replace)
- **pnpm:** modern pnpm reads `overrides` and `allowBuilds` from **`pnpm-workspace.yaml`, not `package.json`**. A `pnpm` block left in `package.json` is silently ignored — pnpm prints only a `WARN` about ignored keys, so an old override there has quietly stopped protecting anything. Move it and delete the dead block

**Bundled inside a parent package's tarball**:
- Overrides cannot reach these — the vulnerable code ships inside the parent
- The fix is to bump the **parent**. Check whether a patched parent exists before declaring it unfixable
- Only if no patched parent exists: report "Resolves when `<parent>` releases a patched version"

**Genuinely needs a major bump** (e.g., a test runner where only the next major is patched):
- Attempt it when the repo has tests that can prove it, then verify hard (below)
- If verification fails, revert **that package in that sub-package only** and keep the wins elsewhere. Do not abandon a whole component over one workspace
- Report it as: "Needs `<package>@<major>`; <what broke> when attempted"

After adding overrides (if any):

```bash
npm install
```

```bash
npm audit --json
```

Report what was resolved and what remains by category.

### Step 5: Build

```bash
npm run build
```

Compare against the Step 2 baseline. **Count the errors** — a component whose build already failed can still be fixed; what matters is that it fails the *same way*. Same errors as baseline is a pass. New errors are a regression.

If new errors appear: **stop this component**, report, move on. Do not push broken code.

### Step 5b: CDK components — `build` is not enough

🔴 **For any component with a `synth` script, run it.** `tsc` compiles fine while `cdk synth` fails outright, so build alone will wave through a broken deploy.

```bash
npm run synth
```

- **The `aws-cdk` CLI must move in lockstep with `aws-cdk-lib`.** A newer library emits a newer cloud assembly schema that an older CLI cannot read: *"Maximum schema version supported is N, but found N+1."* Bumping the library alone breaks synth. Always bump both
- If synth fails on **missing context** (`-c key=value`) or missing AWS credentials, that is configuration, not your change. Pass a throwaway value to prove synth works
- 🔴 **If `cdk.out/` is git-tracked, revert it before committing.** A synth run with placeholder context writes those placeholders into the template. Stage only dependency files

### Step 6: Test

```bash
npm test
```

- If no test script exists, skip
- If the script exists but the runner finds **no test files**, or the runner itself is not installed, that is a pre-existing repo problem, not a failure of your change. Note it and continue
- If tests fail but the **baseline also failed** (Step 2): pre-existing. **Continue** — note it in the commit body
- If tests fail but the **baseline passed**: your change broke something. **Revert and stop this component**

**Compare test totals, not just pass/fail counts.** A drop in the *total* number of tests run means a file stopped collecting — a silent regression that a pass-count check misses entirely.

**Re-run twice before calling a new failure real.** Property-based suites (`fast-check` and similar) generate random input and fail a different case each run. If the failing test name changes between runs, it is flaky, not a regression.

### Step 6b: Known major-bump traps

- **Test-runner majors often drop transitive `@types/node`.** Code annotating timers as `NodeJS.Timeout`, or touching `global` / `globalThis`, then fails to compile. Installing `@types/node` is not enough on its own: if `tsconfig` has an explicit `"types": [...]` allowlist, **`"node"` must be added to it** or the package is ignored
- **Mock implementations used with `new` must be `function` expressions**, not arrows. Newer runners refuse to construct an arrow-function mock. A constructor returning an object yields that object, so `function () { return {...} }` is a behaviour-preserving swap
- Both are one-line fixes. Neither means the bump has to be abandoned

## Phase 3 — Land it (per component)

After a component passes build + test:

1. Stage **only dependency files** — never `git add -A`. A build or synth step may have written generated output, and in a monorepo the fix touches several manifests:
   ```bash
   git add package.json package-lock.json
   ```
   Add `pnpm-lock.yaml`, `pnpm-workspace.yaml`, nested `<sub>/package.json` and `<sub>/package-lock.json`, or a changed `tsconfig*.json` as applicable. Then confirm nothing else crept in:
   ```bash
   git diff --cached --name-only
   ```

2. Commit — write the message to `tmp/commit-msg.txt` (project root `tmp/` directory) using the Write tool, then commit with `--file`:
   ```bash
   git commit --file <project-root>/tmp/commit-msg.txt
   ```

   **Write what was actually wrong, not "ran audit fix".** A future reader needs to know why a pin moved or an override changed, or they will revert it. Cover:
   - Which packages moved, from what to what
   - **Why `audit fix` could not do it** — the exact pin, the stale override, the tight range
   - Anything deliberately left, and what blocks it
   - Pre-existing build or test failures, stated as pre-existing
   - Supporting changes (a `tsconfig` types entry, a mock rewritten) and why they were required

3. Push to the **default** branch (or the PR branch, if that was the choice in Step 1):
   ```bash
   git push origin <default-branch>
   ```

   If the push is rejected as non-fast-forward, the remote already has a fix (often a merged Dependabot PR). Do not merge blindly: reset to the remote, re-run the audit on top, and only commit if something is still outstanding.

   ⚠️ **A push may trigger a deploy.** Check the component's `CLAUDE.md` for a publisher pipeline before the first push of a run, and tell the user if pushing ships to production.

4. **Only if the PR route was chosen in Step 1** — create the PR via `gh pr create` (write body to `tmp/pr-body.txt` first, use `--body-file`):
   - **Title:** `Fix Dependabot security alerts`
   - **Body:** the same content as the commit message, plus the alert numbers resolved
   - Target repo is the component's GitHub repo from manifest
   - 🔴 Reference alerts with `Refs`, never a closing keyword — GitHub closes Dependabot alerts on its own when the patched lockfile lands on the default branch

5. Remove any temporary worktree created for a branch mismatch, and confirm the user's original checkout is back as it was:
   ```bash
   git -C <component-path> worktree remove <worktree-path>
   ```

## Phase 4 — Verify against GitHub, then summarise

🔴 **A clean local `npm audit` is not proof.** Only GitHub closing the alert is. Wait a couple of minutes for the re-scan, then re-run the Phase 1 scan and compare counts per component.

If a component's count did not move, it is almost always cause 3 or 4 from the table above — a nested lockfile you missed, or a push to a non-default branch. Go back and check both before reporting it as unfixable.

Then present:

```
Landed:
  project-infra  — 796b891 (18/18 alerts cleared)
  project-web    — 2c9d3bb (5/5)
  project-admin  — no alerts, skipped

Remaining:
  Component      Package       Sev  Why
  project-web    vitest        med  Only patched in v4; v4 breaks N tests (named)
  project-infra  aws-cdk-lib   low  Pin is deliberate and documented in the file

Pre-existing failures (not caused by this work):
  project-infra  — build fails on a TS error that predates the change
  project-web    — jest is in the test script but not in devDependencies
```

Report **GitHub's** before/after counts, not the local audit's. Note the two numbers often disagree — GitHub's count runs higher, so use it for ranking work, not for estimating effort.

## Known Errors

**E401 — npm auth token invalid:** If `npm audit fix` or `npm install` fails with E401, check two things:

1. **Global `.npmrc`** — stale auth token for registry.npmjs.org. If the component uses no private packages, suggest: `npm config delete //registry.npmjs.org/:_authToken`
2. **`package-lock.json` resolved URLs** — lockfiles may point to a private registry (e.g., AWS CodeArtifact) with an expired token. Check `resolved` URLs in the lockfile. If the project doesn't need the private registry, offer to regenerate the lockfile against the public registry (`rm package-lock.json` then `npm install`). If it does need it, suggest the user re-authenticate (`! aws codeartifact login ...` or `! npm login`).

Ask the user to run auth commands themselves — never attempt registry authentication automatically.

## Rules

1. **Confirm the landing model once**, at the start, then work through every component without asking again. Confirm again only for something genuinely new — a push that deploys, or a major bump that broke tests
2. **Never use `npm audit fix --force`.** Bumping one *named* direct dependency and verifying it is a different thing, and is allowed
3. **Never touch a dirty working tree.** Skip the component and say so
4. **Stop on a *new* build or test failure** — never on a pre-existing one. Compare against the baseline, and compare test totals as well as pass counts
5. **Never write an exact-pinned override.** Today's exact pin is next quarter's blocked alert. Always `>=<patched>`, constrained with `<major>` only when a consumer needs the old API
6. **Fix on the default branch.** Dependabot watches nothing else. Use a throwaway worktree rather than switching the user's checkout, and never merge a feature branch to deliver a dependency fix
7. **npm and pnpm** — check `packageManager` in manifest. For pnpm, `overrides` and `allowBuilds` belong in `pnpm-workspace.yaml`; a `pnpm` block in `package.json` is ignored silently
8. **Run `synth` on CDK components**, and bump the `aws-cdk` CLI whenever `aws-cdk-lib` moves
9. **Stage only dependency files.** Never `git add -A`; revert any generated output a verification step produced
10. **Leave a deliberate pin alone.** If a version is pinned with a comment explaining what breaks above it, that comment outranks a low-severity alert. Report it and let the user decide
11. **No Co-Authored-By** in commit messages
12. **Use the Dependabot API for scanning**, `npm audit` for fixing, and the API again to prove the work landed
