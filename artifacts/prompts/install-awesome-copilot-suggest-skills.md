# Install Awesome-Copilot Suggest Skills + Agent Lint

Scarica e installa nella repo corrente le 3 skill "suggest" dalla repository [github/awesome-copilot](https://github.com/github/awesome-copilot) e la skill di validazione `agent-lint`. Le skill suggest permettono di cercare on-demand agenti, instructions e skills dalla community awesome-copilot. La skill agent-lint valida che tool e modelli degli agenti installati siano aggiornati.

## Fase 1 — Skill da scaricare da awesome-copilot

| Skill | URL raw | Cartella destinazione |
|---|---|---|
| suggest-awesome-github-copilot-agents | `https://raw.githubusercontent.com/github/awesome-copilot/main/skills/suggest-awesome-github-copilot-agents/SKILL.md` | `.github/skills/suggest-awesome-github-copilot-agents/SKILL.md` |
| suggest-awesome-github-copilot-instructions | `https://raw.githubusercontent.com/github/awesome-copilot/main/skills/suggest-awesome-github-copilot-instructions/SKILL.md` | `.github/skills/suggest-awesome-github-copilot-instructions/SKILL.md` |
| suggest-awesome-github-copilot-skills | `https://raw.githubusercontent.com/github/awesome-copilot/main/skills/suggest-awesome-github-copilot-skills/SKILL.md` | `.github/skills/suggest-awesome-github-copilot-skills/SKILL.md` |

Per ciascuna delle 3 skill nella tabella sopra:

1. Crea la cartella di destinazione sotto `.github/skills/` se non esiste
2. Scarica il file `SKILL.md` dall'URL raw indicato
3. Salvalo nella cartella di destinazione **senza modificare il contenuto**
4. Verifica che il file sia stato scritto correttamente (controlla che il frontmatter YAML contenga i campi `name` e `description`)

## Fase 2 — Skill agent-lint (creazione locale)

Crea la skill `agent-lint` con **2 file**. Questa skill non si scarica da awesome-copilot, va creata direttamente.

### File 1: `.github/skills/agent-lint/SKILL.md`

Crea il file con questo contenuto esatto:

````markdown
---
name: agent-lint
description: 'Audit and validate VS Code custom agents (.agent.md) for deprecated tools, obsolete models, and misconfigured MCP references. Use when asked to "lint agents", "check agents are up to date", "validate agent tools", or "audit agent configurations".'
---

# Agent Lint

Scan all `.agent.md` files in `.github/agents/` and validate their `tools:` and `model:` frontmatter fields against three sources of truth. Report issues in a structured table and offer to auto-fix.

## Process

1. **Discover Agents**: List all `*.agent.md` files in `.github/agents/`
2. **Parse Frontmatter**: For each agent, extract `tools:` array and `model:` field from YAML frontmatter
3. **Check Built-in Tools**: Fetch the VS Code agent skills documentation to identify current valid built-in tool names:
   - Primary: `https://code.visualstudio.com/docs/copilot/customization/agent-skills`
   - Fallback: `https://code.visualstudio.com/docs/copilot/customization/custom-agents`
   - Extract the list of valid tool identifiers from the documentation
   - Flag any tool in an agent that does not appear in the current documentation and is not an MCP tool (no `mcp_` prefix)
4. **Check MCP Tools**: For tools with `mcp_` prefix or MCP-style names:
   - Read `.vscode/mcp.json` if it exists (workspace MCP config)
   - Also check `.vscode/settings.json` for `mcp.servers` key
   - Extract the list of configured MCP server names
   - For each MCP tool in an agent (e.g. `mcp_github_*`), verify that a matching MCP server is configured (e.g. server named `github`)
   - Flag MCP tools that reference servers not configured in the workspace
5. **Check Models**: Read the bundled `models.md` file from this skill's folder (`.github/skills/agent-lint/models.md`)
   - Flag any `model:` value that appears in the Deprecated Models table
   - Suggest the successor model from the table
   - Flag any `model:` value not found in either Valid or Deprecated tables as "unknown — verify manually"
6. **Report**: Output results in the format specified below
7. **AWAIT** user confirmation before making any changes
8. **Fix**: When user approves, apply fixes to the agent files

## Output Format

### Summary

| Agents Scanned | Issues Found | Auto-fixable |
|---|---|---|
| 12 | 5 | 4 |

### Issues Detail

| Agent | Field | Current Value | Issue | Suggested Fix |
|---|---|---|---|---|
| devops-expert.agent.md | tools | `codebase` | Built-in tool deprecated | Replace with `search` |
| devops-expert.agent.md | model | `claude-3.5-sonnet` | Model deprecated | Replace with `claude-sonnet-4` |
| my-agent.agent.md | tools | `mcp_jira_create_issue` | MCP server `jira` not configured | Configure server in `.vscode/mcp.json` (not auto-fixable) |

## Built-in Tool Validation

Common known renames (use as fallback if fetch fails):

| Deprecated | Current | Since |
|---|---|---|
| `codebase` | `search` | VS Code 1.98 |
| `terminalCommand` | `runInTerminal` | VS Code 1.98 |
| `web/fetch` | `fetch` | VS Code 1.99 |
| `editFiles` | `editFile` | VS Code 1.100 |
| `findFiles` | `search` | VS Code 1.98 |
| `runCommand` | `runInTerminal` | VS Code 1.98 |

## MCP Server Matching Rules

To match an MCP tool to its server:
1. Strip the `mcp_` prefix from the tool name
2. Take the next segment before the second `_` as the server key
3. Example: `mcp_github_create_pull_request` → server key = `github`
4. Check if a server with that key exists in `.vscode/mcp.json` → `servers` or `.vscode/settings.json` → `mcp.servers`

## Requirements

- Use `fetch` tool to get VS Code documentation for built-in tool validation
- Read local files for MCP config and bundled models.md
- Do NOT modify agents without user approval
- If VS Code doc fetch fails, fall back to the built-in rename table above
````

### File 2: `.github/skills/agent-lint/models.md`

Crea il file con questo contenuto esatto:

````markdown
# VS Code Copilot Model Reference

> Last updated: 2026-03-31

## Valid Models

| Model ID | Provider | Notes |
|---|---|---|
| `claude-sonnet-4` | Anthropic | Default recommended, best balance |
| `claude-opus-4` | Anthropic | Highest capability |
| `gpt-4o` | OpenAI | Latest GPT-4 |
| `gpt-4.1` | OpenAI | Latest GPT-4.1 |
| `o4-mini` | OpenAI | Reasoning, fast |
| `o3` | OpenAI | Reasoning, deep |
| `gemini-2.5-pro` | Google | Multimodal |

## Deprecated Models

| Deprecated ID | Successor | Notes |
|---|---|---|
| `claude-3.5-sonnet` | `claude-sonnet-4` | Superseded Feb 2025 |
| `claude-3-opus` | `claude-opus-4` | Superseded May 2025 |
| `claude-3-sonnet` | `claude-sonnet-4` | Superseded Feb 2025 |
| `claude-3-haiku` | `claude-sonnet-4` | Superseded, use sonnet |
| `gpt-4-turbo` | `gpt-4o` | Superseded by 4o |
| `gpt-4` | `gpt-4o` | Legacy |
| `gpt-3.5-turbo` | `gpt-4o` | Legacy |
| `o1-preview` | `o3` | Superseded |
| `o1-mini` | `o4-mini` | Superseded |
| `o1` | `o3` | Superseded |
| `o3-mini` | `o4-mini` | Superseded |
| `gemini-2.0-flash` | `gemini-2.5-pro` | Superseded |
| `gemini-1.5-pro` | `gemini-2.5-pro` | Superseded |

## How to Update This File

When VS Code or providers announce new models:
1. Add the new model to the **Valid Models** table
2. Move the replaced model to the **Deprecated Models** table with its successor
3. Update the `Last updated` date at the top
````

## Fase 3 — Validazione post-installazione

Dopo aver completato le Fasi 1 e 2, esegui un audit degli agenti esistenti:

1. Elenca tutte le skill installate con la dimensione dei file per conferma
2. Esegui la logica della skill `agent-lint`: scansiona `.github/agents/*.agent.md` e verifica tool e modelli come descritto nella skill
3. Presenta la tabella dei risultati

## Cosa fanno queste skill una volta installate

- **suggest-awesome-github-copilot-agents** — Suggerisce agenti dalla community awesome-copilot per il contesto del progetto, segnalando duplicati e versioni obsolete.
- **suggest-awesome-github-copilot-instructions** — Stessa cosa per i file `.instructions.md`.
- **suggest-awesome-github-copilot-skills** — Stessa cosa per le skill (cartelle con `SKILL.md`).
- **agent-lint** — Valida tool e modelli di tutti gli agenti: controlla deprecazioni built-in (fetch dalla doc VS Code), coerenza MCP (verifica `.vscode/mcp.json`), e modelli obsoleti (tabella locale `models.md`).

Dopo l'installazione puoi usarle scrivendo in chat frasi come:
- *"Suggeriscimi agenti awesome-copilot adatti a questo progetto"*
- *"Quali skill di awesome-copilot mi mancano?"*
- *"Cercami instructions awesome-copilot per il mio stack"*
- *"Linta i miei agenti"* / *"Controlla che i miei agenti siano aggiornati"*
