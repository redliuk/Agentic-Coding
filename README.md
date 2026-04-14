# Agentic Coding

**Do more with less.** A lightweight framework for controlled, scalable agentic coding using nothing but the file system, Markdown files, and VS Code with GitHub Copilot.

## The Idea

AI coding agents are powerful, but using them on real projects — consistently, reliably, and without chaos — is hard. Most approaches to "agent engineering" reach for heavy infrastructure: databases, vector stores, custom tooling, complex orchestration layers.

This repository takes the opposite path. It explores how far you can go with **plain Markdown files and the file system as the only infrastructure**. The goal is a practical framework where:

- Agents have **persistent, structured context** across sessions — without a database
- Agent-authored files follow **enforced quality standards** — without a CI pipeline
- Everything is **version-controlled, human-readable, and diffable** — because it's just `.md` files in `.github/`
- The entire system runs **inside VS Code** with GitHub Copilot — no external services, no API keys, no deployment

This is agentic engineering with zero operational overhead.

Frequent human-in-the-loop interaction is by design, not a limitation. Agents ask for approval before writing, merging, or restructuring — this keeps the human in control and prevents blind spots from accumulating silently in the documentation or the implementation.

## What's Inside

The repository contains two complementary systems, both fully implemented as VS Code Copilot custom agents, hooks, and instruction files.

### 1. Agent Memory System

**Problem:** AI agents start every conversation from zero. They forget past decisions, repeat questions, and give contradictory advice across sessions.

**Solution:** A file-based persistent memory in `.github/memory/` that agents navigate, read, and (with user approval) write to. Memory is structured as Markdown files organized by topic, indexed via `INDEX.md` files, and governed by strict read/write protocols enforced through `copilot-instructions.md`.

Key design choices:

- **File-based, not database.** Memory is plain Markdown — diffable, portable, version-controlled
- **Navigated, not dumped.** Agents follow indexes to find relevant context instead of loading everything into the context window
- **Read-biased, write-controlled.** Agents read freely but can only write with explicit user approval, preventing memory pollution
- **Self-validating.** A `PostToolUse` hook automatically checks structure, naming, and index consistency after every file operation

The system includes six specialized agents organized in an **orchestrator-subagent pattern**: a **reviewer** orchestrates read-only analysis by delegating deep file comparisons to a **deep-analyzer** subagent; a **fixer** dispatches corrections to a **conflict-resolver** subagent (for merges) and a **file-splitter** subagent (for oversized files); and an **importer** migrates existing documentation, delegating large file splits to the same splitter. Orchestrators keep their context lean by only reading INDEX metadata and routing — content-heavy work is always handled by subagents with fresh context.

> Full design document: [`artifacts/PersonalFrameworkIdeas/agent-memory-system.md`](artifacts/PersonalFrameworkIdeas/agent-memory-system.md)

### 2. Agentic Markdown Quality System

**Problem:** There is no single standard for writing `.agent.md`, `.prompt.md`, `SKILL.md`, and other Copilot customization files. Norms differ across VS Code, Claude Code, and Codex documentation. Files copied from community repos have no quality control, and best practices evolve while files stay stale.

**Solution:** A four-agent pipeline that curates authoritative sources, builds agreed-upon norms per file type, audits local files against those norms, and fixes violations — all with user oversight at every step.

The pipeline:

1. **source-scout** — Maintains a curated registry of authoritative documentation and high-quality community repositories
2. **norms-builder** — Fetches directives from sources, classifies them as consensus / conflict / exclusive, and iterates with the user to produce agreed norms
3. **md-auditor** — Scans local `.github/` files against the agreed norms and produces a severity-ranked violation report (read-only)
4. **md-fixer** — Applies fixes one at a time with user approval, then hands off back to the auditor for re-verification

Agents are connected via **handoffs** (not subagents), preserving full conversation context across the chain. A `PostToolUse` hook enforces structural integrity of the norms store in `.github/quality/`.

> Full design document: [`artifacts/PersonalFrameworkIdeas/agentic-markdown-quality-system.md`](artifacts/PersonalFrameworkIdeas/agentic-markdown-quality-system.md)

## Shared Patterns

Both systems converge on the same architectural patterns — a lightweight agent engineering playbook:

| Pattern | How it works |
|---|---|
| **Markdown as infrastructure** | All state, rules, and knowledge live in `.md` files under `.github/`. No databases, no external services |
| **Index-based navigation** | Agents discover content through `INDEX.md` files instead of scanning directories or loading everything |
| **Read-only reviewers → write-capable fixers** | Separation of concerns: analysis agents cannot modify anything; fixer agents require user approval for every change |
| **PostToolUse hooks for guardrails** | Lightweight validation scripts that fire after agent actions and inject feedback into the conversation context |
| **Handoffs for context, subagents for isolation** | When downstream agents need conversation history (reports, decisions), handoffs preserve context. When they need clean context for isolated tasks, subagents start stateless |
| **Orchestrator-subagent delegation** | Orchestrator agents read only metadata and route decisions. Content-heavy analysis, splitting, and merging are delegated to subagents with fresh context windows, keeping quality stable as memory grows |
| **Human-in-the-loop by default** | No agent writes, deletes, or restructures without explicit user confirmation |

## Repository Structure

```
.github/
├── copilot-instructions.md          # Always-on rules for all agents
├── agents/                          # Custom Copilot agents
│   ├── memory-reviewer.agent.md       # Orchestrates review via INDEX triage + subagent
│   ├── memory-deep-analyzer.agent.md  # Subagent: deep file analysis (read-only)
│   ├── memory-fixer.agent.md          # Dispatcher: routes fixes to subagents
│   ├── memory-conflict-resolver.agent.md # Subagent: merge/conflict resolution
│   ├── memory-file-splitter.agent.md  # Subagent: splits large files
│   ├── memory-importer.agent.md       # Imports docs, delegates splits
│   ├── md-auditor.agent.md
│   ├── md-fixer.agent.md
│   ├── norms-builder.agent.md
│   └── source-scout.agent.md
├── hooks/                           # PostToolUse validation hooks
│   ├── memory-validation.json
│   ├── quality-validation.json
│   └── scripts/
├── memory/                          # Agent persistent memory store
│   ├── INDEX.md
│   └── README.md
└── quality/                         # Norms and source registry
    ├── README.md
    ├── sources.md
    └── norms/
artifacts/
└── PersonalFrameworkIdeas/          # Design documents
    ├── agent-memory-system.md
    └── agentic-markdown-quality-system.md
```

## Requirements

- **VS Code** with **GitHub Copilot** (agent mode)
- No external dependencies, databases, or API keys

## Status

This is an active experiment. The systems are functional and in use, but interfaces and patterns may evolve as VS Code Copilot's agent capabilities mature.

## License

This project is shared for learning and experimentation purposes.
