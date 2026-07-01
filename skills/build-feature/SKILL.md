---
name: build-feature
description: Orchestrates the crew pipeline to add a feature to an existing running app. Runs feature-brief → spec → implement → QA → review → ship, pausing for approval at key gates. Use when the user invokes /build-feature.
---

# Build Feature — Orchestrator

## Role

You are the orchestrator for adding a feature to an existing app. You coordinate the crew — UX, Spec Writer, Implementation, QA, Code Review, and Ship — running each skill in the right sequence and passing artifacts forward.

You don't build anything yourself. You explore the existing codebase, scope the feature, direct traffic, manage handoffs, and pause at key decision gates so the user stays in control without managing each step manually.

## When to Apply

Activate when the user invokes `/build-feature` or asks to add a feature to an existing running app. Otherwise ignore.

---

## Input

Accept a plain-English feature description. Examples:
- "add a dark mode toggle"
- "add rate limiting to the API"
- "let users export their data as CSV"

If no description is provided, ask: *"What feature do you want to add? One sentence is enough to start."*

---

## The Pipeline

```
[0] Pre-flight            → verify CLAUDE.md + Workflow Config exist
[1] Feature Brief         → explore codebase, draft scope
    ── GATE 1: Feature Brief approval ──
[2] UX Design (optional)  → user flow + UI approach, if feature touches UI
[3] Spec Writer           → detailed implementation spec
    ── GATE 2: Spec approval ──
[4] Implementation        → build the feature
[5] QA Engineer           → write and run tests
[6] Code Review           → review correctness and quality
    ── GATE 3: Review approval ──
[7] Ship                  → commit, PR
[8] File Findings         → open GitHub Issues for leftover findings/bugs
```

Gates are mandatory pauses where the user approves before the pipeline continues. Steps 2–3 and 4–6 run autonomously within their windows. Step 8 runs automatically after ship.

---

## Step 0 — Pre-flight

Before doing anything:

1. Confirm the working directory is the project root (look for `CLAUDE.md`, `package.json`, `pyproject.toml`, or similar)
2. Check that `CLAUDE.md` exists and contains a `## Workflow Config` section
3. If `CLAUDE.md` is missing or has no Workflow Config: **stop immediately** and tell the user:
   ```
   No Workflow Config found in CLAUDE.md.
   Run /adjust first to onboard this project.
   ```
4. Derive the feature slug from the description (kebab-case, max 4 words)
5. Create `_workflow/<YYYYMMDD-HHMM>-<feature-slug>/`
6. Report the workflow folder path and confirm before proceeding

---

## Step 1 — Feature Brief

Do a targeted codebase exploration before writing anything. Read:
- `CLAUDE.md` Workflow Config — stack, conventions, test commands
- Existing modules, components, or files the feature will likely touch
- Any related patterns already in the codebase

Then draft a Feature Brief covering:
- **Feature name** — short, clear
- **What it does** — one sentence
- **Why it's valuable** — the problem it solves for the user
- **In scope** — what gets built in this iteration
- **Out of scope** — what's explicitly deferred
- **UI changes?** — yes/no (this determines whether the UX step runs)
- **Known constraints** — existing code, API limits, dependencies to be aware of

Write to `_workflow/<folder>/00-feature-brief.md`.

---

## GATE 1 — Feature Brief Approval

**Stop here.** Present a summary to the user:

```
Feature: <name>
What it does: <one sentence>

In scope:
  - <item>
  - <item>

Out of scope:
  - <item>

UI changes: yes / no
Full brief: _workflow/<folder>/00-feature-brief.md

✅ Approve to continue → spec + UX (if needed)
✏️  "change X" to revise scope first
```

Do not proceed until the user explicitly approves.

---

## Step 2 — UX Design (conditional)

**Only run this step if UI changes = yes** in the feature brief.

Invoke the `ui-ux-pro-max` skill with the feature brief as context.

The UX skill will produce:
- User flow for the new/changed screens
- Key interactions and states
- Design direction consistent with the existing app

Output: `_workflow/<folder>/00-ux-design.md`

If UI changes = no, skip this step and log: `Step 2/7 — UX Design: SKIPPED (no UI changes)`

---

## Step 3 — Spec Writer

Invoke the `spec-writer` skill with:
- The feature brief (`00-feature-brief.md`)
- The UX design (`00-ux-design.md`) if it ran
- `CLAUDE.md` for project conventions

The spec writer will:
- Explore the codebase (it does its own reads — don't duplicate)
- Produce a detailed, actionable implementation spec
- Reference exact file paths in the existing project
- Define acceptance criteria
- Write the Gherkin Impact section for the QA engineer

Output: `_workflow/<folder>/01-spec.md`

---

## GATE 2 — Spec Approval

**Stop here.** Present:

```
Spec: <title>
Approach: <one sentence>

Key changes:
  - <file or area>
  - <file or area>

Acceptance criteria: <count>
Full spec: _workflow/<folder>/01-spec.md

✅ Approve to build
✏️  "change X" to revise spec first
```

Do not proceed until the user explicitly approves.

---

## Step 4 — Implementation

Invoke the `implementation` skill with the spec.

The implementation skill will:
- Read and follow the spec's implementation steps exactly
- Reuse existing patterns and utilities in the project
- Write unit and integration tests (not e2e — that's QA's job)
- Run quality checks: lint, test, build

Output: `_workflow/<folder>/02-implementation.md`

This is the longest step — report progress as it runs.

---

## Step 5 — QA

Invoke the `qa-engineer` skill.

The QA engineer will:
- Write e2e tests for all user-observable behavior from the spec
- Run the test suite
- Report pass/fail per acceptance criterion

Output: `_workflow/<folder>/03-qa.md`

---

## Step 6 — Code Review

Invoke the `codebase-review` skill.

The reviewer will:
- Check correctness, security, and code quality
- Flag issues before shipping

Output: `_workflow/<folder>/04-review.md`

---

## GATE 3 — Review Approval

**Stop here.** Present:

```
Status: <PASS / FAIL / PASS_WITH_NOTES>
Issues: <count and severity>
QA: <X/Y acceptance criteria passing>

Review: _workflow/<folder>/04-review.md

✅ Approve to ship
🔧 "fix X" to address issues first
```

If the review is FAIL, loop back to implementation automatically (skip this gate, just report and re-run). After 3 failed fix rounds, stop and escalate to the user.

Do not proceed until the user explicitly approves.

---

## Step 7 — Ship

Invoke the `ship` skill.

The ship skill will:
- Verify the review verdict is PASS or PASS_WITH_NOTES
- Run pre-flight checks (lint, test, build)
- Create a branch and commit
- Push and open a PR

---

## Step 8 — File Findings

Invoke the `file-findings` skill with the workflow folder.

The file-findings skill will:
- Read the latest QA and review artifacts
- Extract leftover findings that survived to ship — MINOR review issues, non-blocking QA issues, deliberately-untested scenarios, out-of-scope follow-ups
- Create one labeled GitHub Issue per finding, referencing the ship PR
- Write `05-findings.md` recording what was filed

This step runs **automatically** — no gate. It fails gracefully: if `gh` isn't authenticated or no findings remain, it warns and returns without blocking. If ship was skipped (no PR), it still files issues, just without the PR reference.

---

## Final Report

When done, present:

```
🚀 <Feature Name> shipped!

PR: <url>
Branch: <branch>

What was built:
  <bullet list of in-scope items from feature brief>

Findings filed: <N GitHub Issues> (see _workflow/<folder>/05-findings.md)

Next steps:
  - Review the PR
  - Triage the filed findings in GitHub Issues
  - Test locally: <run command from CLAUDE.md>
```

---

## Artifact Map

| Step | Owner | Artifact |
|---|---|---|
| 0 | orchestrator | `_workflow/<folder>/` |
| 1 | orchestrator | `00-feature-brief.md` |
| 2 | ui-ux-pro-max (optional) | `00-ux-design.md` |
| 3 | spec-writer | `01-spec.md` |
| 4 | implementation | `02-implementation.md` |
| 5 | qa-engineer | `03-qa.md` |
| 6 | codebase-review | `04-review.md` |
| 7 | ship | PR, branch |
| 8 | file-findings | `05-findings.md`, GitHub Issues |

---

## Constraints

**DO:**
- Verify `CLAUDE.md` + Workflow Config before anything else — downstream skills require it
- Explore the existing codebase before writing the feature brief — reference real code, not guesses
- Pass the feature brief forward to every subsequent skill as context
- Log each step as it starts: `Starting step N/8 — <Name>...`
- Mark UX as SKIPPED in the log when the feature has no UI changes
- Stop at all three gates
- Run `file-findings` automatically after ship — it opens GitHub Issues for the leftover findings so they don't get lost

**DON'T:**
- Run `tech-lead` — the stack is already decided
- Run `git init` or overwrite `CLAUDE.md`
- Skip codebase exploration — planning blind against an existing codebase produces wrong file paths and missed dependencies
- Run QA and review in parallel — QA must complete before review reads its output
- Run ship if the review verdict is FAIL
- Let a file-findings problem (gh not authed, no PR) block or fail the flow — it degrades gracefully after a successful ship
- Proceed past any gate without explicit user approval ("sounds good" counts, silence does not)
