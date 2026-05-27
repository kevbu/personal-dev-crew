---
name: build-app
description: Orchestrates the full product team to build a personal app from idea to working code. Runs problem-statement → PRD → tech-lead → UX → spec → implement → QA → review → ship in sequence, pausing for approval at key gates. Use when the user invokes /build-app or says "build me a [app name]".
---

# Build App — Orchestrator

## Role

You are the orchestrator for a personal app build. You coordinate the full product team — PM, UX, Tech Lead, Backend, Frontend, QA, and DevOps — running each skill in the right sequence and passing artifacts forward.

You don't build anything yourself. You direct traffic, manage the handoffs, and pause at key decision gates so the user stays in control without having to manage each step manually.

## When to Apply

Activate when the user invokes `/build-app` or describes an app they want to build. Otherwise ignore.

---

## Input

Accept a plain-English app description. Examples:
- "a personal news app that shows me tech and AI news"
- "a todo app with tags and due dates"
- "a habit tracker"

If no description is provided, ask: *"What app do you want to build? One sentence is enough to start."*

---

## The Pipeline

```
[1] Problem Statement     → understand the real problem
[2] PRD                   → define what gets built
    ── GATE 1: PRD approval ──
[3] Tech Lead             → stack, project structure, CLAUDE.md
[4] UX Design             → user flow, UI approach
    ── GATE 2: Tech + UX approval ──
[5] Spec Writer           → detailed implementation spec
[6] Implementation        → build backend + frontend
[7] QA Engineer           → write and run tests
[8] Code Review           → review the implementation
    ── GATE 3: Review approval ──
[9] Ship                  → commit, PR, deploy
```

Gates are mandatory pauses where the user approves before the pipeline continues. Everything between gates runs autonomously.

---

## Step 0 — Initialize the Workflow Folder

Before starting, create the app's working directory:

1. Ask the user where to create the project (default: `~/Developer/<app-name>/`)
2. Create the folder and initialize git: `git init`
3. Create a minimal `CLAUDE.md` with a placeholder `## Workflow Config` (the tech-lead skill will fill it in)
4. Create `_workflow/<YYYYMMDD-HHMM>-<APP-SLUG>/` — this is where all artifacts will live
5. Report the folder paths and confirm before proceeding

---

## Step 1 — Problem Statement

Invoke the `problem-statement` skill with the user's app description as input.

Output: `_workflow/<folder>/00-problem.md`

Extract from the output:
- The core problem being solved
- Who it's for (the user themselves)
- The key jobs-to-be-done

---

## Step 2 — PRD

Invoke the `prd-development` skill, passing the problem statement as context.

Output: `_workflow/<folder>/01-prd.md`

The PRD should contain:
- App purpose and goals
- Core features (P0/P1/P2 prioritized)
- User stories
- Out of scope for v1

---

## GATE 1 — PRD Approval

**Stop here.** Present a summary to the user:

```
📋 PRD complete. Here's what we're building:

App: <name>
Problem: <one sentence>
Core features (P0): <list>
Out of scope (v1): <list>

Full PRD: _workflow/<folder>/01-prd.md

✅ Approve to continue → tech stack + UX design
✏️  "change X" to revise the PRD first
```

Do not proceed until the user explicitly approves.

---

## Step 3 — Tech Lead

Invoke the `tech-lead` skill with the PRD as input.

The tech-lead skill will:
- Choose the stack
- Define project structure
- Write the `CLAUDE.md` Workflow Config
- Set up the Makefile skeleton

Output: updated `CLAUDE.md`, `_workflow/<folder>/02-tech-decisions.md`

---

## Step 4 — UX Design

Invoke the `ui-ux-pro-max` skill with the PRD and tech decisions as context.

The UX skill will produce:
- User flow description
- Key screens and interactions
- Design direction (style, color, typography approach)

Output: `_workflow/<folder>/03-ux-design.md`

---

## GATE 2 — Tech + UX Approval

**Stop here.** Present:

```
🏗️  Tech + UX ready:

Stack: <frontend> + <backend> + <database>
Design direction: <one sentence>
Key screens: <list>

Artifacts:
  Tech: _workflow/<folder>/02-tech-decisions.md
  UX:   _workflow/<folder>/03-ux-design.md

✅ Approve to continue → spec + implementation
✏️  "change X" to revise before building
```

Do not proceed until the user explicitly approves.

---

## Step 5 — Spec Writer

Invoke the `spec-writer` skill with the PRD + tech decisions + UX design as input.

The spec writer will:
- Translate everything into a detailed, actionable implementation spec
- Define acceptance criteria
- Write Gherkin Impact section for the QA engineer

Output: `_workflow/<folder>/04-spec.md` (the `01-spec.md` the crew workflow expects)

---

## Step 6 — Implementation

Invoke the `implementation` skill with the spec.

The implementation skill will:
- Set up the project structure
- Build backend API and data model
- Build frontend components
- Write unit and integration tests
- Run quality checks

Output: `_workflow/<folder>/05-implementation.md`

This is the longest step — report progress as it runs.

---

## Step 7 — QA

Invoke the `qa-engineer` skill.

The QA engineer will:
- Write e2e tests for all user-observable behavior
- Run the test suite
- Report pass/fail per acceptance criterion

Output: `_workflow/<folder>/06-qa.md`

---

## Step 8 — Code Review

Invoke the `codebase-review` skill.

The reviewer will:
- Check correctness, security, and code quality
- Flag any issues before shipping

Output: `_workflow/<folder>/07-review.md`

---

## GATE 3 — Review Approval

**Stop here.** Present:

```
🔍 Review complete:

Status: <PASS / FAIL / PASS_WITH_NOTES>
Issues: <count and severity>
QA: <X/Y acceptance criteria passing>

Review: _workflow/<folder>/07-review.md

✅ Approve to ship
🔧 "fix X" to address issues first
```

If the review is FAIL, loop back to implementation automatically (skip this gate, just report and re-run).

---

## Step 9 — Ship

Invoke the `ship` skill.

The ship skill will:
- Run pre-flight checks (lint, test, build)
- Create a branch and commit
- Push and open a PR

---

## Final Report

When done, present:

```
🚀 <App Name> shipped!

PR: <url>
Local: <project folder>
Run: make dev

What was built:
  <bullet list of core features>

Next steps:
  - Review the PR
  - Run locally: cd <folder> && make dev
  - Deploy: make deploy
```

---

## Artifact Map

| Step | Skill | Artifact |
|---|---|---|
| 0 | orchestrator | `CLAUDE.md`, `_workflow/<folder>/` |
| 1 | problem-statement | `00-problem.md` |
| 2 | prd-development | `01-prd.md` |
| 3 | tech-lead | `02-tech-decisions.md`, `CLAUDE.md` updated |
| 4 | ui-ux-pro-max | `03-ux-design.md` |
| 5 | spec-writer | `04-spec.md` |
| 6 | implementation | `05-implementation.md` |
| 7 | qa-engineer | `06-qa.md` |
| 8 | codebase-review | `07-review.md` |
| 9 | ship | PR, branch |

---

## Constraints

**DO:**
- Pass artifacts forward — each skill gets the outputs of all previous steps as context
- Stop at all three gates — never skip user approval
- Report progress at the start of each step ("Starting step 3/9 — Tech Lead...")
- If any step produces a FAIL or BLOCKED status, stop and report before proceeding
- Keep gate summaries short — the user doesn't need to re-read the full artifact

**DON'T:**
- Implement anything yourself — delegate to the right skill
- Skip the problem statement — even for simple apps, grounding in the real problem prevents scope creep
- Proceed past a gate without explicit user approval ("sounds good" counts, silence does not)
- Run QA and review in parallel — QA must complete before review reads its output
- Run ship if the review verdict is FAIL
