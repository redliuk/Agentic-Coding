# Quality System

This folder contains the **agentic Markdown quality control system** — a set of curated data and agents that ensure your `.github/` customization files (`.agent.md`, `.prompt.md`, `SKILL.md`, `.instructions.md`, hooks) follow the best writing norms from authoritative sources.

## How it works

The system has three layers:

### 1. Sources Registry (`sources.md`)

A curated list of:
- **Repository sources** — where to find high-quality agents, skills, prompts, and instructions to download or adapt.
- **Norm sources** — authoritative documentation that defines how each file type should be written.

Maintained by the `source-scout` agent.

### 2. Agreed Norms (`norms/`)

One file per customization type (e.g., `agent-md.md`, `prompt-md.md`). Each file contains the **agreed writing norms** built by fetching directives from multiple authoritative sources, resolving conflicts with user approval.

Maintained by the `norms-builder` agent.

### 3. Audit & Fix

- `md-auditor` agent reads the agreed norms and compares your local `.github/` files against them. Produces a violation report.
- `md-fixer` agent applies fixes from the audit report, one at a time with user approval.

## Agent chain

```
source-scout → norms-builder → md-auditor → md-fixer → md-auditor (re-audit)
```

Each agent can be invoked independently, but they are designed to work as a pipeline:

1. **source-scout** — verify and update the sources registry
2. **norms-builder** — fetch norms from sources, resolve conflicts, produce agreed norms
3. **md-auditor** — audit local files against agreed norms
4. **md-fixer** — fix violations found by auditor
5. **md-auditor** — re-audit to verify fixes

## Rules

- `sources.md` and `norms/*.md` are **operational data**, not project memory. They live here, not in `.github/memory/`.
- Norms files are **never auto-generated silently**. The `norms-builder` always presents conflicts and waits for user agreement.
- The auditor is **read-only**. It never modifies files.
- The fixer requires **user approval** for every change.
