# Agentic Coding — Do More with Less

A lightweight framework for agentic coding using nothing but the file system, Markdown files, and VS Code with GitHub Copilot. Built for Copilot agent mode, but adaptable to other agentic environments such as Claude Code or Codex.

## The Idea

Use **plain Markdown files and the file system as the only infrastructure** to give AI agents persistent memory, enforced quality standards, and structured workflows — with no databases, no vector stores, no external services.

Core principles:

- **Agents retain context across sessions** through a file-based memory system — no database required
- **Everything is version-controlled, human-readable, and diffable** — it's just `.md` files in `.github/`
- **Zero operational overhead** — no API keys, no deployment, no infrastructure beyond the editor

Frequent human-in-the-loop interaction is a deliberate design choice. Agents require explicit approval before writing, merging, or restructuring — the goal is to maintain strong control over the project and minimize technical debt by preventing undocumented assumptions or silent drift in the codebase.

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
- **Project-scoped, not shared.** Unlike cross-project knowledge bases such as LLM Wiki, this memory is intentionally standalone — scoped to a single project with no interconnection to others. This keeps the memory compact and focused, mitigating context explosion and preserving accuracy of project-specific information

The system includes six specialized agents: a **reviewer** (orchestrates read-only analysis), a **deep-analyzer** (detects redundancy, conflicts, and overlap), a **conflict-resolver** (executes merge and conflict resolution from approved specs), a **file-splitter** (breaks large files into focused topics), a **fixer** (applies corrections one at a time with user approval), and an **importer** (migrates existing docs into memory format).

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
| **Handoffs over subagents** | When downstream agents need the full conversation history (reports, decisions), handoffs preserve context; subagents are used only for stateless tasks |
| **Human-in-the-loop by default** | No agent writes, deletes, or restructures without explicit user confirmation |

## Repository Structure

```
.github/
├── copilot-instructions.md          # Always-on rules for all agents
├── agents/                          # Custom Copilot agents
│   ├── memory-reviewer.agent.md
│   ├── memory-deep-analyzer.agent.md
│   ├── memory-conflict-resolver.agent.md
│   ├── memory-file-splitter.agent.md
│   ├── memory-fixer.agent.md
│   ├── memory-importer.agent.md
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
