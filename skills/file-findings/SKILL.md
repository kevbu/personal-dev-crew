---
name: file-findings
description: Files leftover QA and review findings from a completed workflow as GitHub Issues. Reads the latest QA and review artifacts, extracts findings that survived to ship time (MINOR review issues, non-blocking QA issues, deliberately-untested scenarios, out-of-scope items), and creates labeled GitHub Issues referencing the ship PR. Runs automatically as the final step of build-feature and build-app, or standalone via /file-findings.
---

# File Findings

## Role

You turn the leftover findings from a completed build into tracked GitHub Issues. When a feature or app ships, the review verdict is PASS — meaning CRITICAL and MAJOR issues were already fixed. What remains is worth tracking so it doesn't get lost: MINOR review findings, non-blocking QA issues, scenarios the QA engineer deliberately did not test, and out-of-scope items flagged as follow-up work.

You read the QA and review artifacts, extract these leftovers, and create one GitHub Issue per finding — labeled, deduplicated, and linked back to the ship PR and workflow folder.

You never invent findings. Every issue you create traces to a specific line in a QA or review artifact.

## When to Apply

Activate when:
- Called as the final step of the `build-feature` or `build-app` orchestrator, OR
- The user invokes `/file-findings` directly on a workflow folder.

Otherwise ignore.

---

## Input Handling

Take whatever was passed — workflow folder name, path, or empty to auto-detect (the most recent folder in `workflow-dir` that has a review artifact and no findings manifest yet; ask if multiple candidates).

---

## Step 1 — Resolve Folder and Preconditions

1. Read the project's `CLAUDE.md`
2. Find the `## Workflow Config` section. If it doesn't exist, **stop and warn**: "No Workflow Config found in CLAUDE.md. Run `/adjust` to set up the project for this workflow."
3. Parse the config: `workflow-dir` (default: `_workflow`), `base-branch` (default: `main`)
4. Resolve the input to a workflow folder.
5. Detect the repo: `git remote get-url origin`. Parse `owner/repo`.
6. Verify `gh` CLI is authenticated: `gh auth status`. **If it fails, do NOT fail the flow** — the ship already succeeded. Warn and stop cleanly: "GitHub CLI is not authenticated (`gh auth login`). Skipping issue creation. Findings remain in the QA and review artifacts." Write a findings manifest noting that filing was skipped, then return.

---

## Step 2 — Load Artifacts (glob, don't hardcode numbers)

The two orchestrators number artifacts differently (`build-feature`: `03-qa`, `04-review`; `build-app`: `06-qa`, `07-review`). Never hardcode the prefix. Resolve by glob and take the latest:

1. **Latest QA artifact** — glob `[0-9][0-9]-qa*.md` in the folder. Sort; pick the highest re-run suffix (`03-qa-3.md` > `03-qa-2.md` > `03-qa.md`). If none exists, note "no QA artifact" and continue — review findings may still exist.
2. **Latest review artifact** — glob `[0-9][0-9]-review*.md`. Same latest-wins rule. If none exists, warn: "No review artifact found. There may be nothing to file — continuing with QA findings only."
3. **Spec + brief** — glob `[0-9][0-9]-spec.md` and `00-feature-brief.md` (build-feature only) for the "Out of scope" section.
4. **Ship PR URL** — determine the PR opened for this workflow:
   - Derive the branch: `<branch-prefix><folder-name>` (branch-prefix default `feature/`), or read it from the latest implementation/summary artifact if present.
   - `gh pr list --head <branch> --repo <owner>/<repo> --json number,url --state all` → take the newest.
   - If no PR is found, continue without a PR reference (ship may have been skipped). Do not fail.

---

## Step 3 — Extract Findings

Pull findings from each source. Read the actual artifact text — do not guess. A section reading "None." or empty yields nothing.

### 3a — Review findings (MINOR, and any surviving MAJOR/CRITICAL)

Both the `review` and `codebase-review` formats use `### CRITICAL` / `### MAJOR` / `### MINOR` subsections, with each finding as `**[SEVERITY] <title>**` followed by bullets (`Location`/`File`, `What`, `Why it matters`, `Recommendation`/`Suggested fix`).

- Extract every finding under **MINOR** — these are the expected leftovers.
- Also extract any finding still under **CRITICAL** or **MAJOR**. At a PASS ship there should be none; if any survived, file them at high severity — that is exactly the kind of leftover that must not be lost.
- For each: capture title, severity, location (`file:line` if present), what, why, and the suggested fix/recommendation.

### 3b — QA findings (non-blocking issues)

From the QA artifact's `## Implementation Issues Found` section. Each issue is a `### <title>` with `- **Expected (from spec):**`, `- **Actual:**`, `- **Evidence:**`, `- **Severity:** blocking | major | minor`.

- Extract each issue. Capture title, expected, actual, evidence, severity.
- If the section reads "None — all acceptance criteria verified.", extract nothing.

### 3c — Deliberately untested scenarios (test debt)

From the QA artifact's `## Scenarios Deliberately Not Added` section — a bullet list of ACs routed away from e2e or intentionally not covered.

- Extract each bullet as a `test-debt` follow-up. Capture the AC reference and the one-line reason.

### 3d — Out-of-scope items (follow-up enhancements)

From the feature brief's **Out of scope** list and/or the spec's "Out of scope" section.

- Extract each item as an `enhancement` follow-up.
- Skip items that are clearly "will never do" rather than "deferred" — use judgment; when unclear, include it.

### 3e — Deduplicate

A finding often appears in both QA and review (e.g. a bug QA found and review re-flagged). Merge by normalized title / same `file:line`. Keep the richer description, note both sources, and use the higher severity.

If, after extraction and dedup, there are **zero findings**, skip issue creation. Log: "No open findings to file — QA and review left no leftovers." Write a minimal manifest and return.

---

## Step 4 — Map Findings to Issues

For each finding, build a GitHub Issue:

**Title** — concise, prefixed by kind for scannability:
- Review/QA bug → `[bug] <title>`
- Test debt → `[test-debt] <title>`
- Out-of-scope follow-up → `[follow-up] <title>`

**Labels** (kind + severity + source):
- Kind: `bug` (review/QA findings), `test-debt` (untested scenarios), `enhancement` (out-of-scope follow-ups)
- Severity: `severity:major` or `severity:minor` (map QA `blocking`→`major`; test-debt/follow-ups get no severity label)
- Source: `source:review`, `source:qa`, or `source:scope`

**Body** (Markdown):

```markdown
## What
<description — the "What" / "Actual" / the scenario or scope item>

## Why it matters
<impact — the "Why it matters" / "Expected", or for follow-ups why it was deferred>

## Suggested fix
<the Recommendation / Suggested fix, if the source had one; else omit>

## Source
- Origin: <QA | Review | Out-of-scope> (severity: <original severity>)
- Location: `<file:line>` <if present>
- Workflow: `<workflow-dir>/<folder>/`
- Artifact: `<qa or review filename>`
- Shipped in: <PR URL> <if a PR was found>
```

---

## Step 5 — Ensure Labels Exist

Before creating issues, make sure every label used exists. Create missing ones (tolerate "already exists"):

```bash
gh label create "<label>" --repo <owner>/<repo> --color <hex> 2>/dev/null || true
```

Suggested colors: `bug` red `d73a4a`, `enhancement` teal `a2eeef`, `test-debt` yellow `fbca04`, `severity:major` orange `d93f0b`, `severity:minor` light `fef2c0`, `source:*` gray `ededed`. If the repo already defines these labels, reuse them — don't recolor.

---

## Step 6 — Deduplicate Against Existing Issues (idempotency)

This skill may re-run (the build-feature loop, a manual re-invoke). Do not create duplicate issues.

1. List existing open issues: `gh issue list --repo <owner>/<repo> --state open --limit 200 --json number,title`
2. Also read a prior findings manifest in the folder if one exists (see Step 8) — it lists issues already filed for this workflow.
3. For each planned issue, skip it if an open issue with a matching normalized title already exists, or if the manifest already recorded it. Log skips.

---

## Step 7 — Create Issues (automatic)

Create each remaining issue directly — **no confirmation gate**; this runs automatically at the end of the flow:

```bash
gh issue create --repo <owner>/<repo> \
  --title "<title>" \
  --body "<body>" \
  --label "<label1>" --label "<label2>" --label "<label3>"
```

Capture each created issue's number and URL. If a single `gh issue create` fails (e.g. an unknown label), retry once without the offending label; if it still fails, record the failure in the manifest and continue with the rest — one bad finding must not abort the batch.

---

## Step 8 — Write the Findings Manifest

Write `<NN>-findings.md` in the workflow folder — use the next artifact number after the review (`build-feature`: `05-findings.md`; `build-app`: `08-findings.md`). If that file already exists (re-run), append a new dated run section rather than overwriting.

```markdown
# Findings Filed: <feature/app title>

> Workflow: `<workflow-dir>/<folder>/`
> Date: YYYY-MM-DD
> Repo: <owner>/<repo>
> Shipped PR: <PR URL or "none">
> gh auth: OK | SKIPPED (not authenticated)

## Issues Created

| Issue | Title | Kind | Severity | Source |
|-------|-------|------|----------|--------|
| #<n> (<url>) | <title> | bug | minor | review |
| ... | | | | |

## Skipped (already existed)

- <title> → matched open issue #<n>

## Failed

- <title> → <reason> (needs manual filing)

## Not Filed

<If zero findings: "No open findings — QA and review left no leftovers.">
```

---

## Step 9 — Report to User

Present:

1. How many issues were created (with numbers/URLs), how many skipped as duplicates, how many failed.
2. If nothing was filed, say why (no findings, or gh not authenticated).
3. Path to the findings manifest.

Keep it short — this is a closing step, not a gate.

---

## Constraints

**DO:**
- Resolve QA and review artifacts by glob (`*-qa*.md`, `*-review*.md`) — never hardcode `03`/`04` vs `06`/`07`
- Extract only findings that actually exist in the artifacts — every issue traces to a source line
- File MINOR review findings, non-blocking QA issues, deliberately-untested scenarios, and out-of-scope items
- Also file any CRITICAL/MAJOR that unexpectedly survived to ship — those must never be lost
- Deduplicate within the batch and against existing open issues + the prior manifest — this skill re-runs
- Label every issue (kind + severity + source) and create missing labels first
- Reference the ship PR and workflow folder in every issue body
- Create issues automatically — no confirmation gate
- Write a findings manifest as the idempotency + recovery record
- Fail gracefully: if `gh` isn't authenticated or no PR exists, warn and continue — the ship already succeeded

**DON'T:**
- Fail or block the overall flow because issue creation had a problem — the build already shipped
- Re-file findings that already have an open issue
- Invent findings not present in the artifacts
- Create issues for CRITICAL/MAJOR that were already fixed during the flow (only file ones still open)
- Overwrite an existing findings manifest — append a new run section
- Ask the user to approve each issue individually

---

## Red Flags

If you catch yourself thinking any of these, stop:

- "I'll hardcode `04-review.md`" — STOP. build-app uses `07-review.md`. Glob for it.
- "There were CRITICAL findings during the flow, I'll file all of them" — STOP. Only file what's still open in the final artifact. The fixed ones are done.
- "This finding looks important, I'll write a richer version" — STOP. File what the artifact says, cite the source. Don't invent.
- "gh isn't authenticated, I'll fail the flow" — STOP. The ship succeeded. Warn, write the manifest, return cleanly.
- "I'll ask the user to confirm each issue" — STOP. This step is automatic. Create them and report.
- "A label doesn't exist, so the whole batch fails" — STOP. Create the label first; if one issue still fails, record it and continue with the rest.
