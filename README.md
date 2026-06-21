# personal-dev-crew

A global Claude Code skill set for building personal apps — from idea to shipped product.

Orchestrates a full product team: PM → UX → Tech Lead → Backend → Frontend → QA → DevOps, all running as Claude Code skills.

## Quick Start

```bash
# Clone and install globally
git clone https://github.com/kevbu/personal-dev-crew
cd personal-dev-crew
./install.sh
```

Then in any project:

```
/build-app a personal news app that shows me tech and AI news
```

## The Team

| Skill | Role | Source | Command |
|---|---|---|---|
| `build-app` | Orchestrator — runs the full pipeline | Custom | `/build-app` |
| `tech-lead` | Stack decisions, architecture, CLAUDE.md setup | Custom | `/techlead` |
| `backend-engineer` | API, data model, business logic | Custom | `/backend` |
| `devops-engineer` | CI/CD, Docker, deployment | Custom | `/devops` |
| `frontend-design` | Distinctive, production-grade UI | [anthropics/skills](https://github.com/anthropics/skills) | `/frontend-design` |
| `ui-ux-pro-max` | UX patterns, design systems, 161 color palettes | [nextlevelbuilder](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | `/ui-ux-pro-max` |
| `spec-writer` | Implementation specs | [devshop/crew](https://github.com/devshop-software/crew) | `/spec` |
| `implementation` | Feature implementation | [devshop/crew](https://github.com/devshop-software/crew) | `/implement` |
| `qa-engineer` | E2E tests, Gherkin, acceptance criteria | [devshop/crew](https://github.com/devshop-software/crew) | `/qa` |
| `codebase-review` | Code review | [devshop/crew](https://github.com/devshop-software/crew) | `/codebase-review` |
| `ship` | Branch, commit, PR | [devshop/crew](https://github.com/devshop-software/crew) | `/ship` |
| `docs` | Documentation generation | [devshop/crew](https://github.com/devshop-software/crew) | `/docs` |
| `prep` | Feature briefs for indie-agent | [devshop/crew](https://github.com/devshop-software/crew) | `/prep` |
| `adjust` | Project onboarding, CLAUDE.md Workflow Config | [devshop/crew](https://github.com/devshop-software/crew) | `/adjust` |
| `indie-agent` | Autonomous implementation from a brief | [devshop/crew](https://github.com/devshop-software/crew) | `/indie-agent` |
| `product-manager` | Prioritize GitHub Issues → ranked `pm-backlog.md` | Custom | `/product-manager` |
| `work-backlog` | Backlog orchestrator — runs indie-agent per ticket | Custom | `/work-backlog` |

## PM Skills (via plugin marketplace)

Install separately — these power the early discovery phases:

```
/plugin marketplace add deanpeters/Product-Manager-Skills
/plugin install prd-development@pm-skills
/plugin install user-story@pm-skills
/plugin install problem-statement@pm-skills
/plugin install prioritization-advisor@pm-skills
/plugin install epic-breakdown-advisor@pm-skills
/plugin install jobs-to-be-done@pm-skills
```

## GitHub Backlog Workflow

File GitHub Issues for bugs, features, and improvements — then let the crew implement them:

```
/work-backlog --limit 3
```

What happens:
1. `/product-manager` reads open issues and ranks them (security → bugs → features) using PM frameworks from [RefoundAI/lenny-skills](https://github.com/RefoundAI/lenny-skills)
2. For each prioritized issue (up to `--limit`): creates a worktree + branch `issue/<N>-<slug>`, dispatches `/indie-agent` (spec → implement → QA → review → ship), and posts the PR link as a comment on the issue
3. Issues auto-close on PR merge via `Closes #<N>` in the PR body

```
/product-manager              # only prioritize, don't implement yet
/work-backlog --dry-run       # preview which tickets would run
/work-backlog --issue 42      # implement a single specific issue
/work-backlog --limit 1       # implement only the top-ranked ticket
```

Requires: `gh auth login` and `/adjust` already run for the project.

---

## The Full Workflow

```
/build-app <your app idea>
```

Runs this pipeline automatically, pausing at 3 approval gates:

```
Problem Statement → PRD
        ↓
    GATE 1: approve what gets built
        ↓
Tech Lead → UX Design
        ↓
    GATE 2: approve stack + design
        ↓
Spec → Implementation → QA → Review
        ↓
    GATE 3: approve before shipping
        ↓
      Ship → PR + deployed app
```

Or run individual agents manually:

```
/techlead       # architecture decisions
/backend        # build API + data model
/frontend-design # build UI components
/qa             # write + run tests
/devops         # CI/CD + deployment setup
```

## Install

### Global install (recommended)

```bash
./install.sh
```

This copies all skills to `~/.claude/skills/`.

### Manual

```bash
cp -r skills/* ~/.claude/skills/
```

## Stack Defaults

The `tech-lead` skill defaults to:

| Layer | Default |
|---|---|
| Frontend | React + Vite + Tailwind |
| Backend | Python + FastAPI |
| Database | SQLite (local) / PostgreSQL (cloud) |
| Testing | pytest + Vitest + Playwright |
| Deploy | Docker Compose (local) / Fly.io (cloud) |

## Credits

- [devshop/crew](https://github.com/devshop-software/crew) — spec → implement → QA → ship workflow
- [anthropics/skills](https://github.com/anthropics/skills) — frontend-design skill
- [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) — UI/UX intelligence
- [deanpeters/Product-Manager-Skills](https://github.com/deanpeters/product-manager-skills) — PM skills marketplace
