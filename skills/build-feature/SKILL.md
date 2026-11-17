---
name: build-feature
description: Orchestrates the crew pipeline to add a feature to an existing running app. Runs feature-brief → spec → implement → QA → review → ship, pausing for approval at key gates. Use when the user invokes /build-feature.
---

# Build Feature — Orchestrator

## Role

You are the orchestrator for adding a feature to an existing app. You coordinate the crew — UX, Spec Writer, Implementation, QA, Code Review, and Ship — running each skill in the right sequence and passing artifacts forward.

You don't build anything yourself. You explore the existing codebase, scope the feature, direct traffic, manage handoffs, and pause at key decision gates so the user stays in control without managing each step manually.

From step 3 on you dispatch each step to its own fresh subagent and read the result from its artifact file.

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

Gates are mandatory pauses where the user approves before the pipeline continues. Steps between gates run without user approval, except when a subagent returns questions. Step 8 runs automatically after ship. Steps 3 to 8 each run in a fresh subagent (see Subagent Dispatch).

---

## Subagent Dispatch

No agent checks its own work. The context that wrote the code knows what it meant to build, so it tests and reviews its intent, not the code. Each execution step therefore starts blind in a fresh subagent and gets its information only from the artifact files.

### Which steps dispatch

| Step | Runs in | Skill |
|---|---|---|
| 0 Pre-flight | orchestrator | none |
| 1 Feature Brief | orchestrator | none |
| 2 UX Design | orchestrator | none |
| 3 Spec | subagent | `spec-writer` |
| 4 Implementation | subagent | `implementation` |
| 5 QA | subagent | `qa-engineer` |
| 6 Review | subagent | `review` |
| Fix round | 3 subagents (impl, QA, review) | `implementation`, `qa-engineer`, `review` |
| 7 Ship | subagent | `ship` |
| 8 File Findings | subagent | `file-findings` |

Steps 0 to 2 stay in the orchestrator. They come before any code exists, and the user reviews them at Gates 1 and 2.

### Rules

- One fresh Agent-tool call per step. Never reuse an agent across steps. Never run two steps in one agent.
- Foreground only. Never set `run_in_background`. If `build-feature` itself runs as a subagent, a background child cannot report back to it (same rule as `work-backlog`).
- Isolation: the prompt contains file paths, the step's task instructions, the overrides, and the user's own words (a change asked for at a gate, or answers to an earlier agent's questions, quoted with those questions). It never contains your summary, interpretation or reasoning about earlier steps, and never pastes artifact contents.
- Skill loading: the subagent invokes the skill through the Skill tool by name. Fallback: read `~/.claude/skills/<name>/SKILL.md`. Do not use a project-local skills path.
- Subagents don't ask the user. They return `STATUS: QUESTIONS` with the questions. You ask the user, then dispatch a new agent for the same step with the same inputs, task line and overrides as the previous dispatch. Its "User request" keeps everything the previous dispatch for this step had (the user's original words and earlier Q&A rounds), then appends the subagent's questions verbatim and the user's answers verbatim. All of it is non-orchestrator words, so isolation holds.
- Latest file: when a step reads or verifies the "latest" `03-qa*.md` or `04-review*.md`, latest is the highest N. The unnumbered file counts as N=1. Do not sort by name.
- Subagents don't dispatch other agents for pipeline work. Only the orchestrator dispatches fix rounds.

### Dispatch prompt template

```
You are the <step-name> step of the /build-feature orchestrator. Your working directory is: <project-root>

## Your Task
Invoke the `<skill-name>` skill with the Skill tool. If the Skill tool does not list it, read ~/.claude/skills/<skill-name>/SKILL.md and follow it. If neither works, return STATUS: BLOCKED.

<step-specific task instructions from the step section below>

## Inputs (read them yourself)
- Workflow folder: <workflow-dir>/<folder>/
- <path>: <one-line label, e.g. "feature brief">
- <path>: ...
- CLAUDE.md: project conventions and Workflow Config

## User request (the user's words for this step, if any: a change asked for at a gate, then any Q&A rounds with earlier agents for this step)
<the user's original words for this step, quoted verbatim, no paraphrase; then each Q&A round in order: the earlier agent's questions verbatim, then the user's answers verbatim. Write "none" if the user has given no words for this step.>

## Orchestrator Overrides
- Do not ask the user anything. If something blocks you, stop and return STATUS: QUESTIONS with numbered questions. If something is ambiguous but not blocking, decide, document the decision in your artifact, and continue.
- Write into the workflow folder above. Do not create a new workflow folder.
- Do not dispatch other agents to do this step.
- Do not run steps other than yours. The orchestrator runs the next step.
- Where the skill says to ask the user or wait for confirmation, these overrides take precedence.
<step-specific overrides from the step section below>

## Return
Reply with exactly:
STATUS: DONE | QUESTIONS | BLOCKED
ARTIFACT: <path of the file you wrote; for ship: the PR URL>
QUESTIONS: <numbered list, or "none">
NOTES: <at most 3 lines>
```

### After each dispatch

1. If `STATUS: QUESTIONS`: ask the user the questions, then re-dispatch the same step with a fresh agent. Reuse the inputs, task line and step-specific overrides of the previous dispatch for this step (for example a gate's revise or edit-mode line, or the Gate 3 "fix X" line), so "the given path" in a revise line points at the same file. Do not fall back to the step's create-mode task line. Under "User request", keep everything already there (the user's original words and earlier Q&A rounds for this step), then append the latest questions verbatim and the user's answers verbatim.
2. If `STATUS: BLOCKED`: stop and report the reason to the user.
3. Verify the step's Verify line (see the step section for the filename or glob). By default a missing artifact means BLOCKED. Where the step's Verify line differs from this rule (ship, file-findings), the step section wins. Never write the artifact yourself.
4. Read the status or verdict from the artifact file. Never take it from the agent's reply.
5. Log `Step N/8 — <Name>: done (<artifact>)` and continue.

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

Runs in the orchestrator, not a subagent.

**Do NOT invoke a design-generator skill here** (`ui-ux-pro-max`, `frontend-design`,
`/design`). This app already HAS a design system — its tokens, primitives and conventions
are in `CLAUDE.md` and enforced by the repo's own gates. A generator's job is to invent a
design system, so running one produces a *second* one: a fresh palette competing with the
existing tokens, and class names that may fail the project's lint/gate rules. Those skills
belong in `build-app`, where nothing exists yet.

Never run a generator's `--persist` mode in a project repo — it writes a `design-system/`
folder that becomes a rival source of truth to `CLAUDE.md`.

### Read first

- `CLAUDE.md` — design tokens, focus/interaction conventions, any documented ratchets or gates
- The existing components and routes the feature will touch
- The nearest sibling feature that already solved a similar UI problem — copy its shape

### Then write `_workflow/<folder>/00-ux-design.md`

- **User flow** — entry point → steps → exit, for each new or changed screen
- **States** — empty, loading, error, success, and what each one says
- **Primitives to reuse** — name the actual files (a button, card, modal, field the repo
  already has). This is the section the spec writer leans on hardest
- **New primitive needed?** — only with a justification for why nothing existing fits;
  default answer is no
- **Accessibility** — focus order, accessible names, keyboard model, live regions
- **Constraints that apply** — which project gates, conventions or tests this change must
  satisfy, quoted from `CLAUDE.md`
- **Open questions** — anything the spec writer must not guess at

### Escalate instead of inventing

If the feature needs a visual pattern the codebase has no precedent for, **stop and ask the
user** rather than designing one autonomously. Present:

- what pattern is missing, and where it would sit in the flow
- two or three options described in words, each with its trade-off
- your recommendation

Wait for the user to pick, record the choice and its reasoning in `00-ux-design.md`, then
continue. This escalation needs no tooling beyond this file and the conversation.

If the user wants to *see* layout variants before deciding, and their Claude Code build
provides the built-in `design` canvas skill, `/design` is a useful manual side quest. It is
not part of this repo and `install.sh` does not install it, so never assume it is available —
and it produces an Artifact rather than a file this pipeline can read, so it never replaces
`00-ux-design.md`. Transcribe the chosen layout back into this file by hand.

If UI changes = no, skip this step and log: `Step 2/8 — UX Design: SKIPPED (no UI changes)`

---

## Step 3 — Spec Writer

Dispatch a `spec-writer` subagent (see Subagent Dispatch).

- **Inputs (paths):** `_workflow/<folder>/00-feature-brief.md`, `_workflow/<folder>/00-ux-design.md` if it exists, `CLAUDE.md`
- **Task instructions:** Write the spec into the given folder.
- **Step-specific overrides:** Skip the skill's folder-creation step. Skip its "Present and Refine" step; return instead.
- **Verify:** `_workflow/<folder>/01-spec.md` exists.

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

On "change X": dispatch a new `spec-writer` agent in edit mode with the path `_workflow/<folder>/01-spec.md` and the user's words verbatim under "User request". Then show Gate 2 again.

Do not proceed until the user explicitly approves.

---

## Step 4 — Implementation

Dispatch an `implementation` subagent (see Subagent Dispatch).

- **Inputs (paths):** `_workflow/<folder>/01-spec.md`, `_workflow/<folder>/00-ux-design.md` if it exists
- **Task instructions:** Implement the spec in normal mode.
- **Step-specific overrides:**
  - Skip Step 3 (Present Summary and Get Confirmation). Gate 2 approval is the authorization. Begin implementing after reading the spec.
  - If the working tree or `02-implementation.md` already contains partial work from an earlier agent for this step, continue from it. Do not overwrite and do not ask.
- **Verify:** `_workflow/<folder>/02-implementation.md` exists.

The implementation skill will:
- Read and follow the spec's implementation steps exactly
- Reuse existing patterns and utilities in the project
- Write unit and integration tests (not e2e — that's QA's job)
- Run quality checks: lint, test, build

Output: `_workflow/<folder>/02-implementation.md`

This is the longest step. Tell the user it is running before you dispatch.

---

## Step 5 — QA

Dispatch a `qa-engineer` subagent (see Subagent Dispatch).

- **Inputs (paths):** `_workflow/<folder>/01-spec.md`, `_workflow/<folder>/02-implementation.md`
- **Task instructions:** Verify the implementation against the spec.
- **Step-specific overrides:** none
- **Verify:** a new `_workflow/<folder>/03-qa*.md` exists.

The QA engineer will:
- Write e2e tests for all user-observable behavior from the spec
- Run the test suite
- Report pass/fail per acceptance criterion

Output: `_workflow/<folder>/03-qa.md` (`03-qa-N.md` on re-runs)

---

## Step 6 — Code Review

Dispatch a `review` subagent (see Subagent Dispatch).

- **Inputs (paths):** `_workflow/<folder>/01-spec.md`, `_workflow/<folder>/02-implementation.md`, the latest `_workflow/<folder>/03-qa*.md`, any earlier `_workflow/<folder>/04-review*.md`
- **Task instructions:** Review adversarially. Read the code, do not trust the implementation report.
- **Step-specific overrides:** none. The review stance is never softened.
- **Verify:** a new `_workflow/<folder>/04-review*.md` exists. Read its verdict from the file.

The reviewer will:
- Check correctness, security, and code quality against the spec and QA results
- Flag issues before shipping
- Give a binary verdict: PASS or FAIL

Output: `_workflow/<folder>/04-review.md` (`04-review-N.md` on re-runs)

---

## GATE 3 — Review Approval

**Stop here.** Present:

```
Verdict: <PASS / FAIL>   (read from the latest 04-review*.md)
Issues: <count and severity>
QA: <X/Y acceptance criteria passing>

Review: _workflow/<folder>/<latest 04-review*.md>

✅ Approve to ship
🔧 "fix X" to address issues first
```

Do not proceed until the user explicitly approves.

### Fix loop

- **Cap (check first):** when 3 or more `04-review*.md` files exist and the latest is FAIL, stop and escalate to the user with the list of review files and their verdicts. Offer two options. Wait for the user's choice. Do not start another fix round without it.
  - **One more fix round:** run a normal fix round (below). In the implementation agent's dispatch, quote the user's approval verbatim under "User request" and add the override "The user approved this extra fix round. The skill's Iteration Cap does not apply. Do not stop at it."
  - **Stop:** do not ship. Dispatch a `file-findings` subagent as in the File Findings step, with no PR URL, so the open review and QA findings become GitHub Issues. Leave the working tree uncommitted. Report to the user with the Stopped template (see Final Report).
- **Review FAIL (below the cap):** skip the gate. Report the verdict in one line and start a fix round.
- **A fix round is three fresh agents in sequence:**
  1. Implementation agent. Inputs: `01-spec.md`, `02-implementation.md`, latest `04-review*.md`. Task: "The latest review is FAIL. Enter fix mode. Address only the flagged issues. Append a Fix Round section to `02-implementation.md`." Overrides: "Skip Step 3F (Present Fix Plan). Start fixing." and "If the working tree or `02-implementation.md` already contains partial work from an earlier agent for this fix round, continue from it. Do not overwrite and do not ask." Verify: a new `## Fix Round` section in `02-implementation.md`.
  2. QA agent, same as Step 5. Verify: a new `03-qa-N.md`.
  3. Review agent, same as Step 6. Verify: a new `04-review-N.md`. Read its verdict from the file.
- **User says "fix X" at Gate 3 (verdict PASS):** run the same three-agent round, with one change to the implementation agent. Its task line is "Apply only the changes in User request on top of the existing implementation. Do not re-run the spec steps." instead of the FAIL-mode task. It gets the user's words verbatim under "User request" plus the override "Append a Fix Round section for these user-requested changes. Skip the skill's confirmation steps. Do not overwrite `02-implementation.md` and do not ask whether to re-implement."
- Only the orchestrator dispatches fix rounds. Never fix, test or review in the orchestrator.

---

## Step 7 — Ship

Dispatch a `ship` subagent (see Subagent Dispatch).

- **Inputs (paths):** `_workflow/<folder>/`
- **Task instructions:** Ship the reviewed change.
- **Step-specific overrides:**
  - Skip Step 4's confirmation. Gate 3 approval is the authorization. Execute stage, commit, push and PR without stopping.
  - Put the PR URL in `ARTIFACT`.
- **Verify:** take the PR URL from `ARTIFACT` and confirm it with `gh pr view <url>`. This also confirms the branch is pushed. Ship writes no artifact file.

The ship skill will:
- Verify the review verdict is PASS
- Run pre-flight checks (lint, test, build)
- Create a branch and commit
- Push and open a PR

---

## Step 8 — File Findings

Dispatch a `file-findings` subagent (see Subagent Dispatch).

- **Inputs (paths):** `_workflow/<folder>/`, plus the PR URL from step 7
- **Task instructions:** File leftover findings.
- **Step-specific overrides:** none
- **Verify:** `_workflow/<folder>/05-findings.md` exists. If it is missing, warn only. Never block.

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

Findings filed: <N GitHub Issues> (see _workflow/<folder>/<latest *-findings.md found in Step 8 Verify>)

Next steps:
  - Review the PR
  - Triage the filed findings in GitHub Issues
  - Test locally: <run command from CLAUDE.md>
```

**Stopped template:** if the user chose Stop at the fix-loop cap, present this instead:

```
⚠️ <Feature Name> stopped. Nothing was shipped.

What was built:
  <bullet list of in-scope items from feature brief>

Reviews: <each 04-review*.md file with its verdict>
Open findings filed: <N GitHub Issues> (see _workflow/<folder>/<latest *-findings.md found in Step 8 Verify>)
Working tree: left uncommitted. No PR.

Next steps:
  - Read the latest review for the open issues
  - Triage the filed findings in GitHub Issues
  - Fix, commit or discard the uncommitted changes yourself
```

---

## Artifact Map

| Step | Owner | Artifact |
|---|---|---|
| 0 | orchestrator | `_workflow/<folder>/` |
| 1 | orchestrator | `00-feature-brief.md` |
| 2 | orchestrator (optional) | `00-ux-design.md` |
| 3 | spec-writer | `01-spec.md` |
| 4 | implementation | `02-implementation.md` |
| 5 | qa-engineer | `03-qa.md` (`03-qa-N.md` on re-runs) |
| 6 | review | `04-review.md` (`04-review-N.md` on re-runs) |
| 7 | ship | PR, branch |
| 8 | file-findings | `05-findings.md`, GitHub Issues |

---

## Constraints

**DO:**
- Verify `CLAUDE.md` + Workflow Config before anything else — downstream skills require it
- Explore the existing codebase before writing the feature brief — reference real code, not guesses
- Pass artifact paths forward. Each subagent reads the files itself.
- Dispatch steps 3 to 8 and every fix round to a fresh foreground subagent.
- Verify the artifact file after every dispatch and read the verdict from the file.
- Relay subagent questions to the user and re-dispatch with the previous inputs, task line and overrides, the earlier "User request" content kept, and the new questions and answers appended verbatim.
- Log each step as it starts: `Starting step N/8 — <Name>...`
- Mark UX as SKIPPED in the log when the feature has no UI changes
- Stop at all three gates
- If any step returns BLOCKED, or a step other than QA or review produces a FAIL, stop and report before proceeding. A QA FAIL does not stop the pipeline: review reads the QA report and decides the verdict. A review FAIL enters the fix loop.
- Run `file-findings` automatically after ship — it opens GitHub Issues for the leftover findings so they don't get lost

**DON'T:**
- Run `tech-lead` — the stack is already decided
- Invoke a design-generator skill (`ui-ux-pro-max`, `frontend-design`, `/design`) in step 2 — the design system already exists; a generator would create a second one
- Run `git init` or overwrite `CLAUDE.md`
- Skip codebase exploration — planning blind against an existing codebase produces wrong file paths and missed dependencies
- Run QA and review in parallel — QA must complete before review reads its output
- Run ship if the review verdict is FAIL
- Let a file-findings problem (gh not authed, no PR) block or fail the flow — it degrades gracefully after a successful ship
- Proceed past any gate without explicit user approval ("sounds good" counts, silence does not)
- Run a step skill inline in the orchestrator from step 3 on
- Put your own summary or reasoning about earlier steps into a dispatch prompt
- Reuse an agent across steps, or let a step agent dispatch the fix round
- Dispatch with `run_in_background`

---

## Red Flags

If you catch yourself thinking any of these, stop:

- "I'll just run the QA/review myself, I already have the context" — STOP. Having the context is the problem. Dispatch a fresh agent.
- "I'll give the agent a quick summary of what we built so it gets up to speed" — STOP. Paths only. The agent reads the artifacts.
- "The fix is tiny, I'll patch it here instead of a fix round" — STOP. Dispatch the implementation agent in fix mode, then QA and review.
- "The agent said PASS, good enough" — STOP. Read the verdict from the review file.
- "The subagent can ask the user directly" — STOP. It returns questions. You ask.
