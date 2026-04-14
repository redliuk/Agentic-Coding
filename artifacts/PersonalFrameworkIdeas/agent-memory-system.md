# Agent Memory System

A file-based memory system for AI agents in VS Code. Gives agents persistent, structured context about the project so they make better decisions across sessions.

## The Problem

AI agents start every conversation from zero. They don't remember past decisions, architectural choices, or lessons learned. This leads to:

- Repeated questions about the same conventions
- Contradictory suggestions across sessions (e.g., suggesting REST in one session, GraphQL in the next)
- Loss of institutional knowledge — the agent never builds up understanding of the project
- Users manually re-explaining context every time

The memory system solves this by giving agents a structured, persistent knowledge base that survives across sessions and is shared across all agents in the project.

## Core Design Principles

1. **File-based, not database.** Memory lives in `.github/memory/` as plain Markdown files. This means it's version-controlled, human-readable, diffable, and portable across machines. No external services, no lock-in.

2. **Agent-readable AND human-readable.** Every file is written so that both the agent and a human developer can read and understand it. No opaque embeddings or binary formats.

3. **Read-biased, write-controlled.** Agents read memory freely when relevant. Writing is gated — agents can only write when the user explicitly asks, and they must propose the change before executing it. This prevents memory pollution from hallucinated or low-quality entries.

4. **Navigated, not dumped.** Agents don't load all memory into context. They navigate through INDEX.md files to find only what's relevant to the current task. This keeps token usage efficient and avoids context window pollution.

5. **Two-level maximum depth.** `memory/file.md` or `memory/subfolder/file.md`. No deeper nesting. This forces clear topic organization and prevents sprawl.

## Structure

```
.github/
├── copilot-instructions.md         ← Always-on rules for all agents
├── agents/
│   ├── memory-reviewer.agent.md    ← Orchestrates review via INDEX triage + subagent delegation
│   ├── memory-deep-analyzer.agent.md ← Subagent: deep file analysis (read-only)
│   ├── memory-fixer.agent.md       ← Dispatcher: routes fixes to subagents
│   ├── memory-conflict-resolver.agent.md ← Subagent: executes merge/conflict resolution
│   ├── memory-file-splitter.agent.md    ← Subagent: splits large files preserving all content
│   └── memory-importer.agent.md    ← Imports existing docs, delegates splits to subagent
├── hooks/
│   ├── memory-validation.json      ← Hook definition (triggers on PostToolUse)
│   └── scripts/
│       └── validate-memory.ps1     ← Validation logic
└── memory/
    ├── INDEX.md                    ← What's in memory (navigate from here)
    ├── README.md                   ← Writing rules
    └── ...files and subfolders...
```

- **Root files**: one `.md` per macro topic (architecture, conventions, stack...).
- **Subfolders**: when a topic needs multiple files. Each has its own `INDEX.md`.
- **Two levels max**: `memory/file.md` or `memory/subfolder/file.md`.

### INDEX.md — The Navigation Layer

Every folder in memory has an INDEX.md. This is the only entry point agents use to discover what exists. Agents never browse files directly — they always start from the index.

The root INDEX.md lists all root-level files and subfolders with one-line descriptions:

```markdown
- [auth-flow.md](auth-flow.md) — OAuth2 PKCE flow with refresh token rotation
- [deployment/](deployment/) — CI/CD pipeline and environment configuration
```

Subfolder INDEX.md files follow the same template but only list contents of that subfolder.

**Why this matters**: without the index, agents would either need to list directory contents (leaking irrelevant filenames into context) or load everything (wasting tokens). The index gives agents just enough metadata to decide what to read.

### README.md — The Writing Constitution

The README.md defines the rules agents must follow when writing to memory. It covers:

- **What belongs**: decisions + rationale, verified solutions, conventions, lessons learned
- **What doesn't**: TODOs, conversation logs, info already in code, speculative ideas
- **Structural rules**: when to create a file vs. a subfolder, how to handle topic growth
- **Writing workflow**: always check INDEX first, always propose before executing, always update INDEX after

This file is read by agents before any write operation — it acts as a contract that prevents memory from degrading over time.

### Naming Conventions

All files and folders use **lowercase kebab-case**: `api-design.md`, `auth-flow.md`, `deployment/`. Never `API Design.md` or `notes.md`. Names must be specific enough to convey the topic at a glance.

Reserved names: `INDEX.md` and `README.md` (exact case).

## How Agents Use It

### Reading Protocol

The reading protocol is enforced via `copilot-instructions.md`, which is always loaded for every agent:

1. Before any non-trivial task, check if relevant memory exists
2. **Always** read `INDEX.md` first — never browse files directly
3. Before reading files in a subfolder, read that subfolder's INDEX.md first
4. Read only files relevant to the current task — not everything

This lazy-loading approach means agents consume memory proportionally to task complexity. A simple rename operation might read nothing. An architectural decision might read 3-4 files.

### Writing Protocol

Writing is intentionally high-friction to preserve quality:

1. The user explicitly asks to save something to memory
2. The agent reads `README.md` for the rules
3. The agent reads `INDEX.md` to check what already exists
4. The agent decides the correct action:
   - **Update** an existing file if the topic matches
   - **Create a subfolder** if a root file needs to split into multiple files
   - **Create a new root file** if the topic is new
5. The agent **describes the intended change** to the user
6. The agent **waits for confirmation** before executing
7. After writing, the agent updates the relevant INDEX.md

The "propose and wait" step is critical. It prevents agents from silently polluting memory with low-confidence or redundant information.

### Merge and Reorganization Logic

When a root file grows too large or a new aspect of the same macro topic emerges:

1. Create a subfolder named after the topic
2. Move the existing root file into the subfolder
3. Create the new file in the subfolder
4. Create an INDEX.md for the subfolder
5. Update the root INDEX.md to point to the subfolder instead of the old file

This happens organically as the project grows — memory self-organizes from flat to hierarchical.

## What Belongs / Doesn't Belong

| In memory | NOT in memory |
|-----------|---------------|
| Decisions and rationale | TODOs, tasks, action items |
| Verified solutions | Conversation logs |
| Conventions and patterns | Info already in code |
| Lessons learned | Speculative ideas |
| Architectural choices | Temporary/session context |
| Integration details | Duplicates of existing entries |

**Key distinction**: memory provides context to _prepare_ agents for action. It does not _direct_ what actions to take. A memory entry says "we use PostgreSQL because X" — not "migrate to PostgreSQL by Friday."

## Quality Tools

### Validation Hook

The memory validation hook fires automatically after every tool use (`PostToolUse` event). If the touched file is inside `.github/memory/`, the hook runs a PowerShell script that checks:

1. **Root INDEX.md exists** — the navigation entry point must always be present
2. **Root README.md exists** — the writing rules must always be present
3. **Every subfolder has its own INDEX.md** — no unindexed subfolders allowed
4. **All filenames are lowercase kebab-case** — except INDEX.md and README.md
5. **Every file and subfolder is listed in its parent INDEX.md** — no orphaned content

If any check fails, the hook injects validation errors back into the agent's context as `additionalContext`, so the agent can self-correct immediately. The hook does NOT block the operation — it reports, and the agent decides how to fix.

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

The cross-platform `command` field uses `pwsh` (PowerShell Core), while `windows` uses the built-in PowerShell 5.1 with `-ExecutionPolicy Bypass` to avoid policy restrictions.

### memory-reviewer Agent

A read-only orchestrator that analyzes memory for semantic quality issues. It uses `read`, `search`, and `agent` tools — it cannot modify anything. It delegates deep analysis to the `memory-deep-analyzer` subagent to keep its own context lean.

**Workflow (4 phases):**

1. **Phase 0 — Structural checks.** Verifies INDEX consistency (missing entries, orphan entries) by comparing INDEX.md against actual files on disk. Also checks file sizes: reads only line 150 of each file to detect oversized files (>150 lines) without loading content. Oversized files are flagged for split analysis only — they are excluded from all other analysis types.
2. **Phase 1 — INDEX-based triage.** Reads all INDEX.md descriptions to identify suspicious pairs: similar topics (→ redundancy/overlap), contradictory descriptions (→ conflict), multi-topic descriptions (→ size). Also flags vague descriptions that make triage impossible. No file content is read — only INDEX metadata.
3. **Phase 2 — Delegate deep analysis.** For each suspicious group, invokes `memory-deep-analyzer` as a subagent, passing file paths, analysis type, and the suspicion. The subagent reads files with fresh context and returns a structured finding with verdict and evidence.
4. **Phase 3 — Compile and iterate.** Assembles a numbered report from all findings. Iterates with the user point-by-point until the report is confirmed. Only then offers the "Fix issues" handoff to the fixer.

**Why subagent delegation matters:** the reviewer never reads memory file contents directly (except INDEX.md). By delegating deep analysis to a subagent with clean context, each comparison gets full attention instead of being degraded by accumulated context from other files. This scales regardless of memory size.

**What it checks:**

- **INDEX inconsistencies**: missing or orphan entries
- **Oversized files**: files exceeding ~150 lines that need splitting
- **Redundancy**: two files stating the same fact, even with different wording
- **Conflict**: two files making contradictory claims about the same topic
- **Overlap**: files that partially cover the same ground and could be merged
- **Vague INDEX descriptions**: entries too generic to evaluate

**Scope rule**: it only compares files **within the same folder**. Files in different folders are independent domains and are never compared against each other.

**Report format**: every finding is numbered (#1, #2, ...) so the user can respond point by point. Each finding cites file paths, line numbers, quotes from the subagent analysis, and a suggested action.

### memory-deep-analyzer Subagent

A read-only subagent invoked by the reviewer. Receives file paths + an analysis question, reads the files thoroughly with clean context, and returns a structured finding.

**Analysis types:** redundancy, conflict, overlap, size. For size analysis, it produces a concrete **split plan** — proposed output file names, descriptions, and source line ranges — covering 100% of the content. This plan is passed through the fixer to the `memory-file-splitter` for execution.

**Key property:** "not confirmed" is a valid verdict. If the reviewer's suspicion (based on INDEX descriptions) was wrong, the analyzer says so clearly. INDEX descriptions may be misleading — actual content is ground truth.

### memory-fixer Agent

A dispatcher agent that executes the fixes from the reviewer's approved report. It routes each finding to the appropriate handler, keeping its own context lean by delegating heavy operations to subagents.

**Routing logic:**

| Fix type | Handler |
|---|---|
| Structural (naming, INDEX inconsistencies, vague descriptions) | Does directly — lightweight, no file content needed |
| Size / split | Delegates to `memory-file-splitter` subagent |
| Merge / redundancy / overlap / conflict | Delegates to `memory-conflict-resolver` subagent |

**Execution model:** the fixer does not re-ask for approval on each fix — the user already validated the report during the reviewer phase. The only exception: before any **file deletion** (e.g., after a merge), the fixer shows what will be deleted and waits for a confirmation checkpoint.

After each fix, the fixer verifies and updates the relevant INDEX.md.

### memory-conflict-resolver Subagent

Invoked by the fixer to execute a single merge or conflict resolution. Receives the fix specification (already user-approved), the file paths, and the target INDEX.md path. Reads the files, applies the resolution, and returns a summary of changes.

**Key rule:** follows the fix specification exactly without reinterpretation. Preserves all unique information when merging — merging means combining, never discarding.

### memory-file-splitter Subagent

Invoked by the fixer (for size fixes) or by the importer (for large source files). Receives a single file to split and the target subfolder path. Reads the file thoroughly, identifies natural topic boundaries, and distributes the content across multiple focused files.

**Primary directive: zero information loss.** Splitting means distributing content, never summarizing or condensing. Specific numbers, config values, command examples, URLs, rationale — all must be preserved in the output files.

Creates/updates the subfolder's INDEX.md with descriptions specific enough for agents to decide whether to read each file without opening it.

### memory-importer Agent

Used when adopting the memory system on a project that already has documentation. It scans an existing docs folder (noting paths and sizes, not reading full content), then proposes an import plan:

- Maps source files to memory files (new or existing)
- Flattens deep nesting to the two-level maximum
- Groups by macro topic, not by source folder structure
- Rewrites content to match memory style (concise, bullet points, actionable)
- Strips out TODOs, task lists, session context, ephemeral notes
- Merges source files on the same topic into a single memory file
- **Flags large or multi-topic source files for split** — delegates them to `memory-file-splitter`

The importer **never summarizes or condenses** content to make it fit. If a source file is too large for a single memory file, it delegates the split to the subagent rather than losing information. The importer passes the file path (not the content) to the subagent, so the subagent reads it with fresh context.

The import plan is approved by the user before execution. Small files are imported directly; large files are delegated to the splitter.

## Subagent Delegation Pattern

The memory system uses subagent delegation to manage context window limits. The core problem: an agent that reads many files accumulates broad context but loses depth — by the time it processes the 15th file, the analysis quality of any specific file has degraded.

**The pattern:** orchestrator agents (reviewer, fixer, importer) do lightweight work themselves (read indexes, route decisions, update indexes) and delegate content-heavy tasks to stateless subagents that start with clean context.

```
memory-reviewer (reads only INDEX.md, routes)
  └─ memory-deep-analyzer (reads file content, analyzes)

memory-fixer (reads report, dispatches)
  ├─ memory-file-splitter (reads one large file, produces N files)
  └─ memory-conflict-resolver (reads 2+ files, produces merged result)

memory-importer (scans source folder, plans)
  └─ memory-file-splitter (reads one large source file, produces N files)
```

**Key design choices:**

- **Pass file paths, not content.** Orchestrators pass paths to subagents so they read files with their own clean context. Pasting content in the prompt would duplicate tokens and defeat the purpose.
- **Specialized subagents over self-invocation.** An orchestrator calling itself as subagent would carry the full orchestration prompt (irrelevant to the task) and risk recursive loops. Dedicated subagents have focused, minimal prompts.
- **Subagents for content operations, not structural ones.** Naming fixes, INDEX updates, and other lightweight operations don't benefit from subagent isolation — the orchestrator does them directly.
- **The approach scales but not infinitely.** Each subagent invocation has setup cost. The system works well for memories with dozens to hundreds of files. At extreme scale, the orchestrators' INDEX-based triage would also degrade.

### Review → Fix Workflow

The reviewer has a `handoff` to the fixer. After the review completes, a **"Fix issues"** button appears in chat. Clicking it switches to the fixer agent **in the same conversation** — the fixer sees the full review report as context and can start dispatching fixes immediately.

This is different from subagents, which start stateless. The handoff preserves the entire conversation history, so the fixer doesn't need to re-analyze anything — it just dispatches each finding to the appropriate subagent based on the already-approved report.

The two mechanisms serve different purposes:
- **Handoffs** (reviewer → fixer): when the downstream agent needs the full conversation history (the report, user decisions, approved actions)
- **Subagents** (fixer → splitter, fixer → conflict-resolver): when the downstream agent needs clean context for a specific isolated task

```yaml
# In memory-reviewer.agent.md
handoffs:
  - label: "Fix issues"
    agent: memory-fixer
    prompt: "Fix the issues found by the reviewer above."
```

## Enforcement: How copilot-instructions.md Ties It Together

The entire system is enforced by `.github/copilot-instructions.md`, which is loaded for **every** agent in the project. It contains two rule blocks:

**Reading rules** — agents must:
- Check INDEX.md before non-trivial tasks
- Never browse memory files directly
- Read subfolder INDEX.md before any file in that subfolder
- Read only what's relevant

**Writing rules** — agents must:
- Never write unless the user explicitly asks
- Read README.md for the full writing rules before writing
- Describe the intended change and wait for confirmation

Because `copilot-instructions.md` is always-on (it's the project-level instruction file), these rules apply to every agent in the workspace — not just the memory-specific agents. A coding agent, a testing agent, a documentation agent — they all follow the same memory protocol.

## Lifecycle of a Memory Entry

1. **Discovery**: during a conversation, a decision is made or a lesson is learned
2. **User trigger**: the user says "save this to memory" or "remember this"
3. **Agent checks**: reads INDEX.md, checks if a file on the topic exists
4. **Agent proposes**: "I'll add this to `auth-flow.md`, lines 12-15. Here's the new content: ..."
5. **User approves**: the user confirms or adjusts
6. **Agent writes**: the file is updated, INDEX.md is updated if needed
7. **Hook validates**: the PostToolUse hook checks structure, naming, and index consistency
8. **Agent self-corrects**: if the hook reports issues, the agent fixes them immediately
9. **Future sessions**: any agent working on a related task finds and reads this entry

Over time, entries may become redundant or conflicting as the project evolves. The reviewer/fixer workflow handles this maintenance.

## Adopting It

1. Copy `.github/` into your project — memory is ready (empty).
2. If docs already exist, use `memory-importer` to selectively import them.
3. All agents automatically follow the rules from `copilot-instructions.md`.

### Bootstrap for Existing Projects

For projects with existing documentation (e.g., `docs/`, `wiki/`, scattered READMEs):

1. Run `memory-importer` and point it to the source folder
2. Review the import plan — it will flatten, merge, and restructure
3. Approve file by file — each one gets adapted to memory style
4. After import, the original docs remain untouched — memory is a parallel layer

### Customization Points

- **README.md rules**: adjust what belongs/doesn't belong for your project
- **Hook checks**: add custom validations (e.g., max file size, required sections)
- **Agent instructions**: tune the reviewer's comparison scope or the fixer's merge strategy
- **INDEX template**: change the entry format if you need more metadata

## Comparison with Other Approaches

| Approach | Pros | Cons |
|----------|------|------|
| **System prompt stuffing** | Simple, always loaded | Wastes tokens, no organization, hard to maintain |
| **RAG / embeddings** | Scales well, semantic search | Needs infrastructure, opaque, hard to debug |
| **This system** | Human-readable, version-controlled, navigable | Requires discipline, manual curation |
| **No memory** | No overhead | Agent forgets everything every session |

This system sits in the sweet spot: structured enough to scale, simple enough to inspect and maintain, and lightweight enough to work with zero infrastructure beyond the file system.
