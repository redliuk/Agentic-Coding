# Project Instructions

## Memory System

This project uses a file-based memory system located at `.github/memory/`.

### Copilot internal memory — DO NOT USE

- **Never** use the Copilot built-in memory tool (`/memories/`) to store, read, or manage project knowledge.
- All persistent notes, decisions, and procedures **must** be stored in `.github/memory/` 
- If the user asks to "save to memory", "update memory", or "remember this", always use `.github/memory/` — never `/memories/`.

### Reading memory

Before reading from `.github/memory/`, follow these rules:

- Before starting any non-trivial task, check if relevant memory exists in `.github/memory/`.
- Always read `.github/memory/INDEX.md` first — never browse `.github/memory/` files directly.
- Before reading any file inside a `.github/memory/` subfolder, read that subfolder's INDEX.md first.
- Do not read files in `.github/memory/` that are not relevant to your current task. Only read what you need, when you need it.

### Writing memory

Before writing to `.github/memory/`, follow these rules:

- Never write to `.github/memory/` unless the user explicitly asks you to.
- Before writing, read `.github/memory/README.md` for the full writing rules.
- Before creating or modifying any file in `.github/memory/`, describe what you intend to change and why, then wait for user confirmation.
