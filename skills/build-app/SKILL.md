---
name: build-app
description: Orchestrates the full product team to build a personal app from idea to working code. Runs problem-statement → PRD → tech-lead → UX → spec → implement → QA → review → ship in sequence, pausing for approval at key gates. Use when the user invokes /build-app or says "build me a [app name]".
---

# Build App — Orchestrator

## Role

You are the orchestrator for a personal app build. You coordinate the full product team — PM, UX, Tech Lead, Backend, Frontend, QA, and DevOps — running each skill in the right sequence and passing artifacts forward.

You don't build anything yourself. You direct traffic, manage the handoffs, and pause at key decision gates so the user stays in control without having to manage each step manually.

From step 1 on you dispatch each step to its own fresh subagent and read the result from its artifact file.

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
[10] File Findings        → open GitHub Issues for leftover findings/bugs
```

Gates are mandatory pauses where the user approves before the pipeline continues. Steps between gates run without user approval, except when a subagent returns questions. Step 10 runs automatically after ship. Steps 1 to 10 each run in a fresh subagent (see Subagent Dispatch).

---

## Subagent Dispatch

No agent checks its own work. The context that wrote the code knows what it meant to build, so it tests and reviews its intent, not the code. Each step therefore starts blind in a fresh subagent and gets its information only from the artifact files.

### Which steps dispatch

| Step | Runs in | Skill |
|---|---|---|
| 0 Initialize | orchestrator | none |
| 1 Problem Statement | subagent | `problem-statement` |
| 2 PRD | subagent | `prd-development` |
| 3 Tech Lead | subagent | `tech-lead` |
| 4 UX Design | subagent | `ui-ux-pro-max` |
| 5 Spec | subagent | `spec-writer` |
| 6 Implementation | subagent | `implementation` |
| 7 QA | subagent | `qa-engineer` |
| 8 Review | subagent | `review` |
| Fix round | 3 subagents (impl, QA, review) | `implementation`, `qa-engineer`, `review` |
| 9 Ship | subagent | `ship` |
| 10 File Findings | subagent | `file-findings` |

Step 0 stays in the orchestrator. It sets up the folders and asks the user where the project lives.

### Rules

- One fresh Agent-tool call per step. Never reuse an agent across steps. Never run two steps in one agent.
- Foreground only. Never set `run_in_background`. If `build-app` itself runs as a subagent, a background child cannot report back to it (same rule as `work-backlog`).
- Isolation: the prompt contains file paths, the step's task instructions, the overrides, and the user's own words (the app description, a change asked for at a gate, or answers to an earlier agent's questions, quoted with those questions). It never contains your summary, interpretation or reasoning about earlier steps, and never pastes artifact contents.
- Skill loading: the subagent invokes the skill through the Skill tool by name. Fallback: read `~/.claude/skills/<name>/SKILL.md`. Do not use a project-local skills path. Plugin skills (`problem-statement`, `prd-development`) may be listed under a namespaced name such as `problem-statement:problem-statement`. Use the name the Skill tool lists.
- Subagents don't ask the user. They return `STATUS: QUESTIONS` with the questions. You ask the user, then dispatch a new agent for the same step with the same inputs, task line and overrides as the previous dispatch. Its "User request" keeps everything the previous dispatch for this step had (the user's original words and earlier Q&A rounds), then appends the subagent's questions verbatim and the user's answers verbatim. All of it is non-orchestrator words, so isolation holds.
- Subagents don't dispatch other agents for pipeline work. Only the orchestrator dispatches fix rounds.

### Dispatch prompt template

```
You are the <step-name> step of the /build-app orchestrator. Your working directory is: <project-root>

## Your Task
Invoke the `<skill-name>` skill with the Skill tool. If the Skill tool does not list it, read ~/.claude/skills/<skill-name>/SKILL.md and follow it. If neither works, return STATUS: BLOCKED.

<step-specific task instructions from the step section below>

## Inputs (read them yourself)
- Workflow folder: <workflow-dir>/<folder>/
- <path>: <one-line label, e.g. "PRD">
- <path>: ...
- CLAUDE.md: project conventions and Workflow Config

## User request (the user's words for this step, if any: the app description or a change asked for at a gate, then any Q&A rounds with earlier agents for this step)
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
3. Verify the step's Verify line. Resolve the artifact by glob: `*-problem.md`, `*-prd.md`, `*-tech-decisions.md`, `*-ux-design.md`, `*-spec.md`, `*-implementation.md`, `*-qa*.md`, `*-review*.md`, `*-findings.md`. The step skills write their own fixed filenames, which can differ from the Artifact Map numbers. When several files match, latest is the highest N (`-N` suffix). The unnumbered file counts as N=1. Do not sort by name. By default a missing artifact means BLOCKED. Where the step's Verify line differs from this rule (ship, file-findings), the step section wins. Never write the artifact yourself.
4. Read the status or verdict from the artifact file. Never take it from the agent's reply.
5. Log `Step N/10 — <Name>: done (<artifact>)` and continue.

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

Dispatch a `problem-statement` subagent (see Subagent Dispatch).

- **Inputs:** the user's app description, verbatim, under "User request"
- **Task instructions:** Write the problem statement from the user's description.
- **Step-specific overrides:** Write `00-problem.md` in the folder. Interview questions go back as `STATUS: QUESTIONS`.
- **Verify:** `*-problem.md` exists.

Output: `_workflow/<folder>/00-problem.md`

Read from the artifact file (for the Gate 1 summary):
- The core problem being solved
- Who it's for (the user themselves)
- The key jobs-to-be-done

---

## Step 2 — PRD

Dispatch a `prd-development` subagent (see Subagent Dispatch).

- **Inputs (paths):** `_workflow/<folder>/00-problem.md`
- **Task instructions:** Write the PRD from the problem statement.
- **Step-specific overrides:** Write `01-prd.md`. Interview questions go back as `STATUS: QUESTIONS`.
- **Verify:** `*-prd.md` exists.

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

On "change X": re-dispatch the PRD step with a fresh agent, the path `_workflow/<folder>/01-prd.md`, and the user's words verbatim under "User request". Replace the step's task line with: "Revise the existing artifact at the given path. Apply only the change in User request. Do not rewrite or regenerate the rest." Then show Gate 1 again.

Do not proceed until the user explicitly approves.

---

## Step 3 — Tech Lead

Dispatch a `tech-lead` subagent (see Subagent Dispatch).

- **Inputs (paths):** `_workflow/<folder>/01-prd.md`, `CLAUDE.md`
- **Task instructions:** Decide the stack and project structure for the PRD.
- **Step-specific overrides:** Write `02-tech-decisions.md` and fill the Workflow Config in `CLAUDE.md`.
- **Verify:** `*-tech-decisions.md` exists.

The tech-lead skill will:
- Choose the stack
- Define project structure
- Write the `CLAUDE.md` Workflow Config
- Set up the Makefile skeleton

Output: updated `CLAUDE.md`, `_workflow/<folder>/02-tech-decisions.md`

---

## Step 4 — UX Design

Dispatch a `ui-ux-pro-max` subagent (see Subagent Dispatch).

- **Inputs (paths):** `_workflow/<folder>/01-prd.md`, `_workflow/<folder>/02-tech-decisions.md`
- **Task instructions:** Design the user flow and UI approach for the PRD and the chosen stack.
- **Step-specific overrides:** Write `03-ux-design.md`. Do not use `--persist`.
- **Verify:** `*-ux-design.md` exists.

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

On "change X": re-dispatch the affected step (tech-lead or UX) with a fresh agent, the existing artifact path, and the user's words verbatim under "User request". Replace the step's task line with: "Revise the existing artifact at the given path. Apply only the change in User request. Do not rewrite or regenerate the rest." Then show Gate 2 again.

Do not proceed until the user explicitly approves.

---

## Step 5 — Spec Writer

Dispatch a `spec-writer` subagent (see Subagent Dispatch).

- **Inputs (paths):** `_workflow/<folder>/01-prd.md`, `_workflow/<folder>/02-tech-decisions.md`, `_workflow/<folder>/03-ux-design.md`, `CLAUDE.md`
- **Task instructions:** Write the spec into the given folder.
- **Step-specific overrides:** Skip the skill's folder-creation step. Skip its "Present and Refine" step; return instead.
- **Verify:** `*-spec.md` exists.

The spec writer will:
- Translate everything into a detailed, actionable implementation spec
- Define acceptance criteria
- Write Gherkin Impact section for the QA engineer

Output: `_workflow/<folder>/04-spec.md` (the `01-spec.md` the crew workflow expects)

---

## Step 6 — Implementation

Dispatch an `implementation` subagent (see Subagent Dispatch).

- **Inputs (paths):** the `*-spec.md` file, `_workflow/<folder>/03-ux-design.md`
- **Task instructions:** Implement the spec in normal mode.
- **Step-specific overrides:**
  - Skip Step 3 (Present Summary and Get Confirmation). Gate 2 approval and the spec are the authorization. Begin implementing after reading the spec.
  - If the working tree or the implementation report already contains partial work from an earlier agent for this step, continue from it. Do not overwrite and do not ask.
- **Verify:** `*-implementation.md` exists.

The implementation skill will:
- Set up the project structure
- Build backend API and data model
- Build frontend components
- Write unit and integration tests
- Run quality checks

Output: `_workflow/<folder>/05-implementation.md`

This is the longest step. Tell the user it is running before you dispatch.

---

## Step 7 — QA

Dispatch a `qa-engineer` subagent (see Subagent Dispatch).

- **Inputs (paths):** the `*-spec.md` file, the `*-implementation.md` file
- **Task instructions:** Verify the implementation against the spec.
- **Step-specific overrides:** none
- **Verify:** a new `*-qa*.md` exists.

The QA engineer will:
- Write e2e tests for all user-observable behavior
- Run the test suite
- Report pass/fail per acceptance criterion

Output: `_workflow/<folder>/06-qa.md`

---

## Step 8 — Code Review

Dispatch a `review` subagent (see Subagent Dispatch).

- **Inputs (paths):** the `*-spec.md` file, the `*-implementation.md` file, the latest `*-qa*.md`, any earlier `*-review*.md`
- **Task instructions:** Review adversarially. Read the code, do not trust the implementation report.
- **Step-specific overrides:** none. The review stance is never softened.
- **Verify:** a new `*-review*.md` exists. Read its verdict from the file.

The reviewer will:
- Check correctness, security, and code quality against the spec and QA results
- Flag any issues before shipping
- Give a binary verdict: PASS or FAIL

Output: `_workflow/<folder>/07-review.md`

---

## GATE 3 — Review Approval

**Stop here.** Present:

```
🔍 Review complete:

Verdict: <PASS / FAIL>   (read from the latest *-review*.md)
Issues: <count and severity>
QA: <X/Y acceptance criteria passing>

Review: _workflow/<folder>/<latest *-review*.md>

✅ Approve to ship
🔧 "fix X" to address issues first
```

Do not proceed until the user explicitly approves.

### Fix loop

- **Cap (check first):** when 3 or more `*-review*.md` files exist and the latest is FAIL, stop and escalate to the user with the list of review files and their verdicts. Offer two options. Wait for the user's choice. Do not start another fix round without it.
  - **One more fix round:** run a normal fix round (below). In the implementation agent's dispatch, quote the user's approval verbatim under "User request" and add the override "The user approved this extra fix round. The skill's Iteration Cap does not apply. Do not stop at it."
  - **Stop:** do not ship. Dispatch a `file-findings` subagent as in the File Findings step, with no PR URL, so the open review and QA findings become GitHub Issues. Leave the working tree uncommitted. Report to the user with the Stopped template (see Final Report).
- **Review FAIL (below the cap):** skip the gate. Report the verdict in one line and start a fix round.
- **A fix round is three fresh agents in sequence:**
  1. Implementation agent. Inputs: the `*-spec.md` file, the `*-implementation.md` file, the latest `*-review*.md`. Task: "The latest review is FAIL. Enter fix mode. Address only the flagged issues. Append a Fix Round section to the implementation report." Overrides: "Skip Step 3F (Present Fix Plan). Start fixing." and "If the working tree or the implementation report already contains partial work from an earlier agent for this fix round, continue from it. Do not overwrite and do not ask." Verify: a new `## Fix Round` section in the `*-implementation.md` file.
  2. QA agent, same as Step 7. Verify: a new `*-qa*.md`.
  3. Review agent, same as Step 8. Verify: a new `*-review*.md`. Read its verdict from the file.
- **User says "fix X" at Gate 3 (verdict PASS):** run the same three-agent round, with one change to the implementation agent. Its task line is "Apply only the changes in User request on top of the existing implementation. Do not re-run the spec steps." instead of the FAIL-mode task. It gets the user's words verbatim under "User request" plus the override "Append a Fix Round section for these user-requested changes. Skip the skill's confirmation steps. Do not overwrite the implementation report and do not ask whether to re-implement."
- Only the orchestrator dispatches fix rounds. Never fix, test or review in the orchestrator.

---

## Step 9 — Ship

Dispatch a `ship` subagent (see Subagent Dispatch).

- **Inputs (paths):** `_workflow/<folder>/`
- **Task instructions:** Ship the reviewed change.
- **Step-specific overrides:**
  - Skip Step 4's confirmation. Gate 3 approval is the authorization. Execute stage, commit, push and PR without stopping.
  - Put the PR URL in `ARTIFACT`.
- **Verify:** take the PR URL from `ARTIFACT` and confirm it with `gh pr view <url>`. This also confirms the branch is pushed. Ship writes no artifact file.

The ship skill will:
- Run pre-flight checks (lint, test, build)
- Create a branch and commit
- Push and open a PR

---

## Step 10 — File Findings

Dispatch a `file-findings` subagent (see Subagent Dispatch).

- **Inputs (paths):** `_workflow/<folder>/`, plus the PR URL from step 9
- **Task instructions:** File leftover findings.
- **Step-specific overrides:** Write the findings artifact as `08-findings.md`.
- **Verify:** `*-findings.md` exists. If it is missing, warn only. Never block.

The file-findings skill will:
- Read the latest QA (`06-qa.md`) and review (`07-review.md`) artifacts
- Extract leftover findings that survived to ship — MINOR review issues, non-blocking QA issues, deliberately-untested scenarios, out-of-scope follow-ups
- Create one labeled GitHub Issue per finding, referencing the ship PR
- Write `08-findings.md` recording what was filed

This step runs **automatically** — no gate. It fails gracefully: if `gh` isn't authenticated or no findings remain, it warns and returns without blocking. If ship was skipped (no PR), it still files issues, just without the PR reference.

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

Findings filed: <N GitHub Issues> (see _workflow/<folder>/<latest *-findings.md found in Step 10 Verify>)

Next steps:
  - Review the PR
  - Triage the filed findings in GitHub Issues
  - Run locally: cd <folder> && make dev
  - Deploy: make deploy
```

**Stopped template:** if the user chose Stop at the fix-loop cap, present this instead:

```
⚠️ <App Name> stopped. Nothing was shipped.

What was built:
  <bullet list of core features>

Reviews: <each *-review*.md file with its verdict>
Open findings filed: <N GitHub Issues> (see _workflow/<folder>/<latest *-findings.md found in Step 10 Verify>)
Working tree: left uncommitted. No PR.

Next steps:
  - Read the latest review for the open issues
  - Triage the filed findings in GitHub Issues
  - Fix, commit or discard the uncommitted changes yourself
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
| 8 | review | `07-review.md` |
| 9 | ship | PR, branch |
| 10 | file-findings | `08-findings.md`, GitHub Issues |

---

## Constraints

**DO:**
- Pass artifact paths forward. Each subagent reads the files itself.
- Stop at all three gates — never skip user approval
- Report progress at the start of each step ("Starting step 3/10 — Tech Lead...")
- If any step returns BLOCKED, or a step other than QA or review produces a FAIL, stop and report before proceeding. A QA FAIL does not stop the pipeline: review reads the QA report and decides the verdict. A review FAIL enters the fix loop.
- Dispatch steps 1 to 10 and every fix round to a fresh foreground subagent.
- Verify the artifact file after every dispatch and read the verdict from the file.
- Relay subagent questions to the user and re-dispatch with the previous inputs, task line and overrides, the earlier "User request" content kept, and the new questions and answers appended verbatim.
- Keep gate summaries short — the user doesn't need to re-read the full artifact
- Run `file-findings` automatically after ship — it opens GitHub Issues for the leftover findings so they don't get lost

**DON'T:**
- Implement anything yourself — delegate to the right skill
- Skip the problem statement — even for simple apps, grounding in the real problem prevents scope creep
- Proceed past a gate without explicit user approval ("sounds good" counts, silence does not)
- Run QA and review in parallel — QA must complete before review reads its output
- Run ship if the review verdict is FAIL
- Let a file-findings problem (gh not authed, no PR) block or fail the flow — it degrades gracefully after a successful ship
- Run a step skill inline in the orchestrator from step 1 on
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
