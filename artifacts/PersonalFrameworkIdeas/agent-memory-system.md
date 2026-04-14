# Agent Memory System

A file-based memory system for AI agents in VS Code. Gives agents persistent, structured context about the project so they make better decisions across sessions.

## The Problem

AI agents start every conversation from zero — no memory of past decisions, conventions, or lessons learned. This causes repeated questions, contradictory suggestions across sessions, and loss of institutional knowledge.

## Core Design Principles

1. **File-based, not database.** Memory lives in `.github/memory/` as plain Markdown — version-controlled, human-readable, diffable, portable. No external services.
2. **Agent-readable AND human-readable.** No opaque embeddings or binary formats.
3. **Read-biased, write-controlled.** Agents read freely; writing requires explicit user approval and a propose-before-executing workflow. Prevents memory pollution.
4. **Navigated, not dumped.** Agents follow INDEX.md files to find relevant context — never load everything into the context window.
5. **Two-level maximum depth.** `memory/file.md` or `memory/subfolder/file.md`. No deeper nesting.

## Structure

```
.github/
├── copilot-instructions.md              ← Always-on rules for all agents
├── agents/
│   ├── memory-reviewer.agent.md         ← Orchestrates review via INDEX triage + subagent
│   ├── memory-deep-analyzer.agent.md    ← Subagent: deep file analysis (read-only)
│   ├── memory-fixer.agent.md            ← Dispatcher: routes fixes to subagents
│   ├── memory-conflict-resolver.agent.md ← Subagent: merge/conflict resolution
│   ├── memory-file-splitter.agent.md    ← Subagent: splits large files (zero info loss)
│   └── memory-importer.agent.md         ← Imports existing docs, delegates splits
├── hooks/
│   ├── memory-validation.json           ← PostToolUse hook definition
│   └── scripts/validate-memory.ps1      ← Validation logic
└── memory/
    ├── INDEX.md                         ← Navigation entry point
    ├── README.md                        ← Writing rules
    └── ...files and subfolders...
```

- **Root files**: one `.md` per macro topic. **Subfolders**: when a topic needs multiple files, each with its own `INDEX.md`.
- **Naming**: lowercase kebab-case (`auth-flow.md`, not `API Design.md`). Reserved: `INDEX.md`, `README.md` (exact case).

### INDEX.md — Navigation Layer

Every folder has an INDEX.md — the only entry point agents use. Format:
```markdown
- [auth-flow.md](auth-flow.md) — OAuth2 PKCE flow with refresh token rotation
- [deployment/](deployment/) — CI/CD pipeline and environment configuration
```
Without the index, agents would list directories (leaking irrelevant filenames) or load everything (wasting tokens).

### README.md — Writing Constitution

Defines what belongs (decisions + rationale, verified solutions, conventions, lessons learned), what doesn't (TODOs, conversation logs, speculative ideas), structural rules, and the write workflow. Read by agents before any write operation.

## How Agents Use It

### Reading Protocol (enforced via `copilot-instructions.md`)

1. Before non-trivial tasks, check if relevant memory exists
2. Always read `INDEX.md` first — never browse files directly
3. Read subfolder INDEX.md before any file in that subfolder
4. Read only what's relevant — lazy-loading proportional to task complexity

### Writing Protocol

1. User explicitly asks → agent reads README.md → reads INDEX.md
2. Agent decides: update existing file, create subfolder, or create new root file
3. Agent **proposes change and waits for confirmation** before executing
4. After writing, updates relevant INDEX.md

### Reorganization

When a root file grows too large: create subfolder → move file into it → create subfolder INDEX.md → update root INDEX.md. Memory self-organizes from flat to hierarchical.

## What Belongs / Doesn't Belong

| In memory | NOT in memory |
|-----------|---------------|
| Decisions and rationale | TODOs, tasks, action items |
| Verified solutions | Conversation logs |
| Conventions and patterns | Info already in code |
| Lessons learned | Speculative ideas |
| Architectural choices | Temporary/session context |

Memory provides context to _prepare_ agents for action, not to _direct_ what actions to take.

## Quality Tools

### Validation Hook

Fires on `PostToolUse` for files inside `.github/memory/`. Checks: root INDEX.md and README.md exist, every subfolder has INDEX.md, all filenames are kebab-case, every file is listed in its parent INDEX.md. Failures are injected as `additionalContext` — the agent self-corrects.

```json
{
  "hooks": {
    "PostToolUse": [{
      "type": "command",
      "windows": "powershell -ExecutionPolicy Bypass -File .github/hooks/scripts/validate-memory.ps1",
      "command": "pwsh -File .github/hooks/scripts/validate-memory.ps1",
      "timeout": 15
    }]
  }
}
```

### Agents — Orchestrator-Subagent Architecture

The agents use a delegation pattern to manage context window limits: orchestrators read only INDEX metadata and route decisions; content-heavy tasks go to stateless subagents with clean context.

```
memory-reviewer (reads INDEX, triages)
  └─ memory-deep-analyzer (reads file content, analyzes)

memory-fixer (reads report, dispatches)
  ├─ memory-file-splitter (splits large file → N files)
  └─ memory-conflict-resolver (merges/resolves conflict)

memory-importer (scans source folder, plans)
  └─ memory-file-splitter (splits large source file → N files)
```

**Design choices:** pass file paths not content (subagent reads with own clean context). Specialized subagents over self-invocation (avoids carrying irrelevant orchestration prompt + recursive loops). Subagents only for content-heavy operations — structural fixes done directly by orchestrator. Scales well but not infinitely.

#### memory-reviewer

Read-only orchestrator (`read`, `search`, `agent` tools). 4 phases:

1. **Structural checks** — INDEX consistency (missing/orphan entries) + file size check (reads only line 150 to detect >150-line files without loading content). Oversized files → split analysis only, excluded from other checks.
2. **INDEX-based triage** — from descriptions alone, identifies suspicious pairs (redundancy/overlap/conflict) and flags vague descriptions.
3. **Delegate analysis** — invokes `memory-deep-analyzer` per suspicious group. Subagent reads files with fresh context, returns structured finding with verdict.
4. **Compile + iterate** — numbered report (#1, #2, ...), iterate with user point-by-point, then handoff to fixer.

Only compares files within the same folder. Never reads file contents directly.

#### memory-deep-analyzer

Read-only subagent. Analysis types: redundancy, conflict, overlap, size. For size analysis, produces a concrete **split plan** (file names, descriptions, source line ranges) covering 100% of content. "Not confirmed" is a valid verdict — INDEX descriptions may mislead.

#### memory-fixer

Dispatcher (`read`, `search`, `edit`, `agent` tools). Routes each finding from the approved report:

| Fix type | Handler |
|---|---|
| Structural (naming, INDEX, descriptions) | Does directly |
| Size / split | Delegates to `memory-file-splitter` |
| Merge / conflict | Delegates to `memory-conflict-resolver` |

No re-approval needed — user validated during reviewer phase. Only checkpoint: before **file deletion**, confirms with user.

#### memory-conflict-resolver

Executes one merge or conflict resolution from a precise, pre-approved fix spec. Follows spec exactly. Preserves all unique information when merging.

#### memory-file-splitter

Splits one large file into multiple focused files. **Primary directive: zero information loss** — distributes content, never summarizes. Creates subfolder INDEX.md with descriptions specific enough for agents to decide without opening files.

#### memory-importer

Scans existing docs folder (paths + sizes, not full content), proposes import plan:
- Maps source → memory files, flattens nesting, groups by macro topic
- Adapts content to memory style, strips TODOs/ephemeral notes, merges same-topic files
- **Never condenses** — large files delegated to `memory-file-splitter` (passes path, not content)

Plan approved by user before execution.

### Handoffs vs. Subagents

- **Handoffs** (reviewer → fixer): downstream agent needs conversation history (report, user decisions). Context preserved.
- **Subagents** (fixer → splitter/resolver, reviewer → analyzer): downstream agent needs clean context for isolated task. Stateless.

```yaml
# In memory-reviewer.agent.md
handoffs:
  - label: "Fix issues"
    agent: memory-fixer
    prompt: "Fix the issues found by the reviewer above."
```

## Enforcement via copilot-instructions.md

Loaded for **every** agent in the workspace (not just memory agents). Enforces reading rules (INDEX-first navigation, read only what's relevant) and writing rules (never write without user request, propose before executing). All agents — coding, testing, documentation — follow the same memory protocol.

## Lifecycle of a Memory Entry

1. Decision/lesson discovered during conversation → user triggers save
2. Agent checks INDEX.md → proposes change → user approves → writes + updates INDEX
3. Hook validates structure → agent self-corrects if needed
4. Future sessions: any agent on a related task finds and reads the entry
5. Over time: reviewer/fixer workflow handles redundancy and conflicts

## Adopting It

1. Copy `.github/` into your project — memory starts empty
2. Use `memory-importer` for existing documentation (`docs/`, `wiki/`, scattered READMEs)
3. All agents automatically follow rules from `copilot-instructions.md`

**Customization points:** README.md rules (what belongs), hook checks (custom validations), agent instructions (comparison scope, merge strategy), INDEX template.

## Comparison

| Approach | Pros | Cons |
|----------|------|------|
| **System prompt stuffing** | Simple, always loaded | Wastes tokens, no organization |
| **RAG / embeddings** | Scales, semantic search | Needs infrastructure, opaque |
| **This system** | Human-readable, version-controlled, navigable | Requires discipline, manual curation |
| **No memory** | No overhead | Agent forgets everything |
