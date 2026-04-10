# Memory System
## What belongs in memory

- Project-level decisions, architectural choices, and their rationale
- Verified solutions to problems encountered during development
- Conventions, patterns, and standards adopted for this project
- Key information about components, integrations, and dependencies
- Lessons learned and pitfalls to avoid

## What does NOT belong in memory

- Temporary notes or session-specific context
- Verbatim conversation logs
- Information that is already in the codebase (code comments, README, etc.)
- Speculative or unverified ideas — only store confirmed decisions
- Duplicates of existing memory entries
- Tasks, goals, or action items — memory provides context to prepare agents for action, not to direct what actions to take

## File structure

### Root level (`memory/`)

Each file.md at the root covers a **macro topic** about the project (e.g., architecture, stack, conventions). This files should not be redundant.

### Subfolders

A subfolder is a container of files.md on the same macro topic. It is used when a single file.md can't contain all the context accumulated about a macro topic.


## Writing rules
These are the rules to respect when writing to `.github/memory/`.


### Before writing to memory

**Always describe the intended change to the user and wait for approval before executing.**

Check what already exists using INDEX.md, then determine the case:

- If a file on the same topic exists:
    - **update it** instead of creating a new one.
- If a file on the same macro topic exists but covers a different aspect:
    - **create a subfolder** for that topic
    - create the file.md in the subfolder
    - move relevant file.md from the root `.github/memory/` into the newly created subfolder
    - create an INDEX.md for that subfolder.
- If no file and no subfolder on the topic exists:
    - **create a new file.md** at the root level.
- If a subfolder on the topic exists:
    - check what already exists using the subfolder index
    - **create or update a file.md** in that subfolder
    - update the subfolder index.

### When writing a file.md
1. **Keep entries concise.** Write actionable knowledge, not essays. Prefer bullet points over paragraphs.
2. **Include context.** State *why* a decision was made, not just *what* was decided.


## Naming conventions

- Use lowercase kebab-case: `api-design.md`, not `API Design.md`
- Be specific: `auth-flow.md`, not `notes.md`
- Subfolder names should match the domain they cover

## INDEX.md entry template

When adding an entry to an INDEX.md, use this format:

```
- [filename.md](filename.md) — Max Two-line description of what it contains
- [subfolder/](subfolder/) — Max Two-line description of what it covers
```
