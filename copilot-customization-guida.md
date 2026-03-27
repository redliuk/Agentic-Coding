# VS Code Copilot — Sistema di personalizzazione agenti

Guida al sistema di customizzazione di GitHub Copilot in VS Code: architettura, componenti, formato dei file, e come si combinano per creare workflow agentic completi.

> **Claude Code** ha un sistema analogo ma distinto. Vedi file separato: **claude-code-analisi.md**

---

## Indice

1. [Panoramica dell'ecosistema](#1-panoramica-dellecosistema)
2. [Custom Agents (`.agent.md`)](#2-custom-agents-agentmd)
3. [Subagenti e orchestrazione](#3-subagenti-e-orchestrazione)
4. [Custom Instructions](#4-custom-instructions)
5. [Prompt Files (`.prompt.md`)](#5-prompt-files-promptmd)
6. [Agent Skills (`SKILL.md`)](#6-agent-skills-skillmd)
7. [MCP Servers](#7-mcp-servers)
8. [Hooks](#8-hooks)
9. [Context Engineering](#9-context-engineering)
10. [Spec-kit e confronto con il formato nativo](#10-spec-kit-e-confronto-con-il-formato-nativo)
11. [Risorse](#11-risorse)

---

## 1. Panoramica dell'ecosistema

VS Code Copilot offre un sistema modulare di personalizzazione. Ogni componente ha un ruolo preciso:

```
┌─────────────────────────────────────────────────────────────┐
│                    UTENTE (Chat / Agent Mode)                │
│                         ↓ prompt                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Custom Agent (.agent.md)                 │   │
│  │  ┌─────────┐ ┌─────────┐ ┌───────┐ ┌─────────────┐  │   │
│  │  │  tools  │ │ agents  │ │ model │ │ mcp-servers │  │   │
│  │  └─────────┘ └─────────┘ └───────┘ └─────────────┘  │   │
│  │  ┌──────────┐ ┌──────────────┐ ┌───────────────┐    │   │
│  │  │ handoffs │ │    hooks     │ │  instructions │    │   │
│  │  └──────────┘ └──────────────┘ └───────────────┘    │   │
│  └──────────────────────────────────────────────────────┘   │
│                         ↓ usa                                │
│  ┌─────────────┐  ┌──────────┐  ┌──────────┐               │
│  │  Skills     │  │  Prompts │  │  MCP     │               │
│  │ (SKILL.md)  │  │(.prompt) │  │(mcp.json)│               │
│  └─────────────┘  └──────────┘  └──────────┘               │
│                                                              │
│  ── always-on ──────────────────────────────────────────    │
│  copilot-instructions.md │ AGENTS.md │ .instructions.md     │
└─────────────────────────────────────────────────────────────┘
```

| Componente | File | Scopo |
|---|---|---|
| **Custom Agent** | `.agent.md` | Agente specializzato con tool, model, subagent, hooks |
| **Custom Instructions** | `copilot-instructions.md`, `AGENTS.md`, `.instructions.md` | Regole always-on o per pattern di file |
| **Prompt File** | `.prompt.md` | Slash command riutilizzabile, task one-shot |
| **Agent Skill** | `SKILL.md` + directory risorse | Capability portabile con script, esempi, risorse |
| **MCP Server** | `mcp.json` o inline in agent | Tool esterni (API, DB, browser, ecc.) |
| **Hooks** | `.github/hooks/*.json` | Automazione deterministica a lifecycle events |

### Dove risiedono i file

| Scope | Agents | Instructions | Prompts | Skills | MCP | Hooks |
|---|---|---|---|---|---|---|
| **Workspace** | `.github/agents/` | `.github/instructions/`, `.github/copilot-instructions.md` | `.github/prompts/` | `.github/skills/` | `.vscode/mcp.json` | `.github/hooks/` |
| **Claude compat** | `.claude/agents/` | `.claude/rules/` | — | `.claude/skills/` | — | `.claude/settings.json` |
| **User profile** | `~/.copilot/agents/` | `~/.copilot/instructions/` | `~/.copilot/prompts/` | `~/.copilot/skills/` | user `mcp.json` | `~/.copilot/hooks/` |

> **Monorepo:** abilitare `chat.useCustomizationsInParentRepositories` per scoprire file dalla root del repo padre.

### Come si creano

- **UI:** Chat Customizations editor (`Chat: Open Chat Customizations` dalla Command Palette)
- **Chat:** `/create-agent`, `/create-instruction`, `/create-prompt`, `/create-skill`, `/create-hook`
- **Wizard:** `/init` → genera instructions, prompts, agents, skills in un colpo
- **Manuale:** creare i file nelle posizioni corrette

---

## 2. Custom Agents (`.agent.md`)

Un custom agent è un file Markdown con frontmatter YAML che definisce un agente AI specializzato: le sue capacità (tool), il modello da usare, quali subagent può invocare, e le istruzioni operative nel body.

### Formato completo del file

```yaml
---
# === Identità ===
name: NomeAgente                    # nome visualizzato (opzionale, default = nome file)
description: Cosa fa l'agente       # usato dall'AI per decidere quando invocarlo come subagent
argument-hint: "[feature] [scope]"  # hint nell'input chat

# === Capabilities ===
tools:                              # restringe i tool disponibili (sandboxing)
  - agent                           # può invocare subagent
  - read                            # lettura file
  - search                          # ricerca codebase
  - edit                            # modifica file
  - execute                         # esecuzione comandi terminale
  - todo                            # gestione todo list
  - "github/*"                      # tutti i tool del namespace github
  - "playwright/*"                  # tutti i tool di Playwright

agents:                             # quali agenti possono essere usati come subagent
  - Developer
  - Tester
  - Reviewer
  # oppure: '*' (tutti), [] (nessuno)

mcp-servers:                        # MCP dichiarato inline, avviato con l'agente
  - name: playwright
    command: npx
    args: ["@playwright/mcp@latest"]

model: Claude Sonnet 4.5 (copilot)  # modello specifico (anche lista prioritizzata)

# === Controllo invocazione ===
user-invocable: true                # true = appare nel dropdown agenti della chat
disable-model-invocation: false     # true = non può essere invocato da altri agenti

# === Workflow sequenziale (UI) ===
handoffs:                           # bottoni per guidare l'utente al passo successivo
  - label: "→ Review"
    agent: Reviewer
    prompt: "Rivedi il codice appena scritto"
    send: true                      # invia automaticamente (false = precompila solo)
    model: Claude Haiku 4.5 (copilot)  # modello per l'agente target

# === Automazione lifecycle ===
hooks:                              # hooks scoped all'agente (Preview)
  PostToolUse:
    - type: command
      command: "./scripts/format.sh"
---

# Istruzioni dell'agente

Il body contiene le istruzioni operative in Markdown.
L'agente le seguirà durante l'esecuzione.
```

### Campi in dettaglio

| Campo | Default | Funzione |
|---|---|---|
| `name` | nome file senza `.agent.md` | Identificativo dell'agente |
| `description` | — | L'AI lo usa per decidere se invocare l'agente come subagent |
| `argument-hint` | — | Testo mostrato nell'input quando l'agente è selezionato |
| `tools` | tutti | **Sandboxing:** lista whitelist dei tool. Supporta namespace (`github/*`) |
| `agents` | `*` (tutti) | Lista agenti invocabili come subagent. `[]` = blocca fan-out |
| `mcp-servers` | — | Server MCP avviati con l'agente. Formato: `name`, `command`, `args` |
| `model` | default VS Code | Modello AI. Può essere lista prioritizzata (fallback) |
| `user-invocable` | `true` | `false` = solo subagent, non appare nel dropdown |
| `disable-model-invocation` | `false` | `true` = solo invocabile dall'utente, mai da un agente |
| `handoffs` | — | Bottoni UI per workflow sequenziale manuale |
| `hooks` | — | Hook scoped all'agente (richiede `chat.useCustomAgentHooks: true`) |

### Il campo `tools` — sandboxing

Senza `tools:`, l'agente ha accesso a **tutto**. Con `tools:`, l'agente vede **solo** i tool elencati.

```yaml
# Agente read-only (può solo leggere e cercare)
tools: [read, search]

# Agente con tool MCP completi + subagent
tools: [agent, read, search, edit, execute, "playwright/*", "github/*"]
```

**Priorità dei tool:** prompt file > custom agent > default. Se un prompt file specifica `tools`, sovrascrive quelli dell'agente.

### Compatibilità con formato Claude

VS Code legge anche file `.md` in `.claude/agents/`. Differenze:
- Claude usa stringhe separate da virgola per i tool (es. `Read, Edit, Bash`)
- VS Code converte automaticamente nel suo formato interno
- Stessa semantica di base, namespace diversi per i tool

### Posizioni dei file

| Scope | Percorso |
|---|---|
| Workspace | `.github/agents/*.agent.md` |
| Workspace (Claude) | `.claude/agents/*.md` |
| User | `~/.copilot/agents/*.agent.md` |
| Org (GitHub) | via `github.copilot.chat.organizationCustomAgents.enabled` |

---

## 3. Subagenti e orchestrazione

I subagenti sono il meccanismo per delegare subtask a agenti isolati. Ogni subagent ha **contesto separato** dalla conversazione principale: riceve solo il prompt del task e restituisce solo il risultato.

### Come funziona

1. L'agente principale (o l'utente) descrive un task complesso
2. L'agente riconosce che una parte beneficia di contesto isolato
3. Lancia un subagent tramite il tool `agent` / `runSubagent`, passando solo il subtask
4. Il subagent lavora autonomamente con i suoi tool e restituisce un summary
5. L'agente principale incorpora il risultato e continua

**Nell'interfaccia:** il subagent appare come tool call collassabile, mostrando nome e tool in esecuzione.

### Configurazione

```yaml
# Orchestratore che può usare solo specifici subagent
---
name: Orchestrator
tools: [agent, read, search]
agents: [Planner, Implementer, Reviewer]
---
```

```yaml
# Worker che non appare nel dropdown (solo subagent)
---
name: Implementer
user-invocable: false
tools: [read, search, edit, execute]
model: Claude Haiku 4.5 (copilot)
---
```

### Nesting

Per default i subagent **non possono** lanciare altri subagent. Per abilitare:

```
chat.subagents.allowInvocationsFromSubagents: true
```

Profondità massima: 5 livelli. Utile per pattern divide-and-conquer (un agente che delega a sé stesso).

### Pattern di orchestrazione

**Coordinator + Workers:**

```
Coordinator (agent, read, search)
    ├── Planner (read, search) — solo lettura
    ├── Implementer (read, search, edit, execute) — può modificare
    └── Reviewer (read, search) — solo lettura, modello diverso
```

Ogni worker ha tool e model diversi, contesto pulito, permessi minimi.

**Multi-perspective review:**

Un agente lancia N subagent in parallelo, ciascuno con focus diverso (correctness, security, code quality, architecture). I risultati vengono sintetizzati dal coordinatore.

**Agente ricorsivo:**

```yaml
agents: [RecursiveProcessor]  # sé stesso
```

Divide una lista in sotto-liste e delega ciascuna a una nuova istanza di sé stesso.

---

## 4. Custom Instructions

Le custom instructions sono regole iniettate automaticamente nel contesto di ogni conversazione. Due categorie:

### Always-on instructions

Caricate **sempre**, in ogni conversazione e agente.

| File | Posizione | Note |
|---|---|---|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Il file principale. Best practice: convenzioni coding, stack, stile |
| `AGENTS.md` | root del repo | Letto da VS Code (richiede `chat.useAgentsMdFile: true`) |
| `CLAUDE.md` | root del repo | Compatibilità Claude Code (richiede `chat.useClaudeMdFile: true`) |

**Contenuto tipico:**

```markdown
# Project Instructions

## Stack
- TypeScript, React 19, Next.js 15
- Tailwind CSS, shadcn/ui

## Conventions
- Functional components only, no class components
- Use named exports, not default exports
- Error handling: Result pattern, never throw in business logic
```

### File-based instructions (`.instructions.md`)

Caricate **solo quando il contesto corrisponde** al pattern glob specificato in `applyTo`.

```yaml
---
name: React Components
description: Convenzioni per componenti React
applyTo: "src/components/**/*.tsx"
---

- Usa React.FC con props esplicite
- Ogni componente in cartella propria con index.ts
- Testa con React Testing Library
```

**Posizioni:**

| Scope | Percorso |
|---|---|
| Workspace | `.github/instructions/*.instructions.md` |
| Claude compat | `.claude/rules/*.md` (con campo `paths` invece di `applyTo`) |
| User | `~/.copilot/instructions/` |

### Priorità

**Personal > Repository > Organization.** Se istruzioni confliggono, quelle più vicine all'utente vincono.

### Differenza tra instructions e agent body

Le instructions sono **iniettate globalmente** (o per pattern). Il body di un `.agent.md` è iniettato **solo quando quell'agente è attivo**. Non duplicare: metti le regole globali nelle instructions, quelle specifiche di un agente nel suo body.

---

## 5. Prompt Files (`.prompt.md`)

I prompt file sono **slash command riutilizzabili** (`/nome`) per task ripetibili. A differenza degli agenti, non creano di per sé una sessione con un ruolo — sono esecuzioni one-shot. Tuttavia, se il prompt file specifica `agent:`, la sessione dell'agente target viene creata regolarmente.

### Formato

```yaml
---
name: gen-component             # opzionale (default = nome file)
description: Genera un componente React con test
argument-hint: "[component name]"
agent: Developer                # delega a un agente specifico (opzionale)
model: Claude Sonnet 4.5 (copilot)
tools: [read, search, edit]     # sovrascrive i tool dell'agente se specificato
---

Genera un componente React per ${input:componentName} seguendo le convenzioni del progetto.

Include:
1. File componente con props tipizzate
2. File test con React Testing Library
3. Export nell'index.ts della cartella

Usa ${selection} come riferimento per lo stile se disponibile.
```

### Variabili disponibili

| Variabile | Valore |
|---|---|
| `${selection}` | Testo selezionato nell'editor |
| `${input:nomeVariabile}` | Input richiesto all'utente al momento dell'invocazione |

### Posizioni

| Scope | Percorso |
|---|---|
| Workspace | `.github/prompts/*.prompt.md` |
| User | `~/.copilot/prompts/` |

### Prompt file vs Agent

| `.prompt.md` | `.agent.md` |
|---|---|
| Slash command (`/nome`) | Agente nel dropdown |
| Task one-shot | Sessione con ruolo persistente |
| Può puntare a un agente (`agent: nome`) | Contiene le istruzioni operative |
| Sovrascrive tool dell'agente se specificato | Definisce tool e capabilities complete |
| Per azioni ripetibili e composizione | Per ruoli specializzati con contesto |

---

## 6. Agent Skills (`SKILL.md`)

Le Skills sono **cartelle di istruzioni, script e risorse** che Copilot carica on-demand quando sono rilevanti per il task. Standard aperto (`agentskills.io`), portabile tra VS Code, Copilot CLI e Copilot coding agent.

### Differenze chiave con instructions e prompts

| | Instructions | Prompts | Skills |
|---|---|---|---|
| **Contenuto** | Solo testo | Solo testo | Testo + script + esempi + risorse |
| **Caricamento** | Always-on / glob | Manuale (`/`) | On-demand (AI decide) o manuale (`/`) |
| **Portabilità** | VS Code + GitHub.com | VS Code | VS Code + CLI + coding agent + qualsiasi agente compatibile |
| **Scope** | Globale o per file | Per invocazione | Per task |
| **Standard** | VS Code-specific | VS Code-specific | Open standard (agentskills.io) |

### Struttura di una skill

```
.github/skills/
└── webapp-testing/              # nome directory = nome skill
    ├── SKILL.md                 # istruzioni + frontmatter (obbligatorio)
    ├── test-template.js         # script template
    └── examples/                # esempi di test
        ├── login-test.spec.ts
        └── api-test.spec.ts
```

### Formato `SKILL.md`

```yaml
---
name: webapp-testing              # deve corrispondere al nome della cartella
description: >
  Test di web application con Playwright.
  Usa questa skill quando l'utente chiede di testare UI,
  form, flussi di navigazione.
argument-hint: "[test file] [options]"
user-invocable: true              # appare nel menu /
disable-model-invocation: false   # l'AI può caricarla automaticamente
---

# Web Application Testing

## Quando usare questa skill
- L'utente chiede di testare componenti UI
- Serve un test E2E o di integrazione

## Procedura
1. Crea un file test da [test template](./test-template.js)
2. Adatta gli esempi in [examples/](./examples/)
3. Esegui con `npx playwright test`

## Riferimenti
- File template: `./test-template.js`
- Esempi: `./examples/`
```

### Caricamento progressivo (3 fasi)

1. **Discovery:** Copilot legge `name` e `description` da tutti i `SKILL.md`. Zero costo di contesto.
2. **Instructions loading:** Quando la skill è rilevante, carica il body del `SKILL.md` nel contesto.
3. **Resource access:** Solo quando le istruzioni riferiscono file nella directory, li legge on-demand.

→ Puoi avere molte skill installate senza consumare contesto. Solo quelle rilevanti vengono caricate.

### Posizioni

| Scope | Percorso |
|---|---|
| Workspace | `.github/skills/`, `.claude/skills/`, `.agents/skills/` |
| User | `~/.copilot/skills/`, `~/.claude/skills/`, `~/.agents/skills/` |
| Personalizzato | setting `chat.agentSkillsLocations` |

### Invocazione

- **Slash command:** `/webapp-testing per la login page`
- **Automatica:** l'AI decide di caricarla in base alla rilevanza della description
- **Controllo:** `user-invocable: false` nasconde dal menu `/`, `disable-model-invocation: true` disabilita il caricamento automatico

### Contribuzione da estensioni

Le estensioni VS Code possono esporre skill via `chatSkills` in `package.json`:

```json
{
  "contributes": {
    "chatSkills": [{ "path": "./skills/my-skill/SKILL.md" }]
  }
}
```

---

## 7. MCP Servers

MCP (Model Context Protocol) è lo standard aperto per connettere modelli AI a tool e servizi esterni. In VS Code, i server MCP forniscono tool (operazioni), risorse (dati read-only), prompt templates, e MCP Apps (UI interattive in chat).

### Configurazione in `mcp.json`

```json
// .vscode/mcp.json (workspace) o user profile
{
  "servers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp"
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@microsoft/mcp-server-playwright"]
    }
  }
}
```

### MCP inline negli agenti

Un agente può dichiarare server MCP nel frontmatter — vengono avviati automaticamente con l'agente:

```yaml
mcp-servers:
  - name: playwright
    command: npx
    args: ["@playwright/mcp@latest"]
```

### Capabilities MCP

| Capability | Descrizione | Come si usa |
|---|---|---|
| **Tools** | Operazioni eseguibili (query DB, interazione browser, ecc.) | Automatico nel chat |
| **Resources** | Dati read-only (file, tabelle, risposte API) | `Add Context > MCP Resources` |
| **Prompts** | Template di prompt del server | `/<server>.<prompt>` nel chat |
| **MCP Apps** | UI interattive (form, visualizzazioni) in chat | Inline quando il server li supporta |

### Sandboxing (macOS/Linux)

```json
{
  "servers": {
    "myServer": {
      "command": "npx",
      "args": ["-y", "@example/mcp-server"],
      "sandboxEnabled": true,
      "sandbox": {
        "filesystem": { "allowWrite": ["${workspaceFolder}"] },
        "network": { "allowedDomains": ["api.example.com"] }
      }
    }
  }
}
```

Con sandbox attivo, i tool del server sono auto-approvati (perché operano in un ambiente controllato). Solo macOS/Linux.

### Posizioni

| Scope | Percorso |
|---|---|
| Workspace | `.vscode/mcp.json` |
| User | `mcp.json` nel profilo utente |
| Agent | campo `mcp-servers` nel frontmatter `.agent.md` |

### Trust e sicurezza

- Al primo avvio, VS Code chiede conferma di trust
- `MCP: Reset Trust` per resettare
- Dalla Extensions view (`@mcp` nel search) si può installare, abilitare/disabilitare
- Enterprise: gestione centralizzata via GitHub policies

---

## 8. Hooks

Gli hooks eseguono **comandi shell deterministici** a punti specifici del lifecycle di una sessione agente. A differenza delle instructions (suggerimenti), gli hooks **garantiscono l'esecuzione** di codice a ogni evento.

### Lifecycle events

| Evento | Quando | Esempio d'uso |
|---|---|---|
| `SessionStart` | Prima sessione inizia | Iniettare contesto progetto, log |
| `UserPromptSubmit` | Utente invia prompt | Audit, iniettare contesto di sistema |
| `PreToolUse` | Prima di ogni tool | Bloccare comandi pericolosi, richiedere approvazione |
| `PostToolUse` | Dopo ogni tool (successo) | Formattare codice, lint, log |
| `PreCompact` | Prima della compattazione contesto | Salvare stato prima del troncamento |
| `SubagentStart` | Subagent avviato | Tracking, setup risorse subagent |
| `SubagentStop` | Subagent completato | Aggregare risultati, cleanup |
| `Stop` | Sessione finisce | Report, cleanup, notifiche |

### Formato file hook

```json
// .github/hooks/format.json
{
  "hooks": {
    "PostToolUse": [
      {
        "type": "command",
        "command": "npx prettier --write \"$TOOL_INPUT_FILE_PATH\"",
        "windows": "powershell -File scripts\\format.ps1",
        "timeout": 15
      }
    ],
    "PreToolUse": [
      {
        "type": "command",
        "command": "./scripts/validate-tool.sh"
      }
    ]
  }
}
```

### Proprietà di un hook command

| Campo | Tipo | Descrizione |
|---|---|---|
| `type` | string | Deve essere `"command"` |
| `command` | string | Comando da eseguire (cross-platform default) |
| `windows` | string | Override per Windows |
| `linux` | string | Override per Linux |
| `osx` | string | Override per macOS |
| `cwd` | string | Working directory (relativo alla root del repo) |
| `env` | object | Variabili d'ambiente aggiuntive |
| `timeout` | number | Timeout in secondi (default: 30) |

### Input/Output

Ogni hook riceve **JSON via stdin** con campi comuni (`timestamp`, `cwd`, `sessionId`, `hookEventName`, `transcript_path`) più campi specifici per evento.

L'hook restituisce **JSON via stdout**:

```json
{
  "continue": true,              // false = ferma la sessione
  "stopReason": "Policy violation",
  "systemMessage": "Warning..."  // mostrato all'utente
}
```

**Exit code:** `0` = successo, `2` = errore bloccante, altro = warning non bloccante.

### PreToolUse — controllo permessi

Output specifico per bloccare/approvare singole tool call:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",   // "allow", "deny", "ask"
    "permissionDecisionReason": "Comando distruttivo bloccato da policy"
  }
}
```

Priorità con hook multipli: `deny` > `ask` > `allow` (vince il più restrittivo).

### Stop hook — impedire la chiusura

```json
{
  "hookSpecificOutput": {
    "hookEventName": "Stop",
    "decision": "block",
    "reason": "Esegui i test prima di terminare"
  }
}
```

Controllare sempre `stop_hook_active` per evitare loop infiniti.

### Hooks scoped all'agente

Definiti nel frontmatter dell'agente, si attivano solo quando quell'agente è attivo:

```yaml
---
name: Strict Formatter
hooks:
  PostToolUse:
    - type: command
      command: "./scripts/format-changed-files.sh"
---
```

Richiede: `chat.useCustomAgentHooks: true`.

### Posizioni

| Scope | Percorso |
|---|---|
| Workspace | `.github/hooks/*.json` |
| Claude compat | `.claude/settings.json`, `.claude/settings.local.json` |
| User | `~/.copilot/hooks/`, `~/.claude/settings.json` |
| Agent | campo `hooks` nel frontmatter `.agent.md` |

### Compatibilità

- **Claude Code:** VS Code legge `.claude/settings.json`. Ignora i matcher (esegue sempre). Tool names e property diversi (snake_case vs camelCase).
- **Copilot CLI:** converte `preToolUse` → `PreToolUse`, `bash` → `osx`/`linux`, `powershell` → `windows`.

### Sicurezza

- Gli hook hanno gli stessi permessi di VS Code
- Se l'agente può editare gli script degli hook, può eseguire codice arbitrario → usare `chat.tools.edits.autoApprove` per richiedere approvazione manuale sugli script
- Validare sempre l'input ricevuto via stdin

---

## 9. Context Engineering

**Principio fondamentale:** la qualità dell'output dell'LLM dipende dalla qualità del contesto in input.

Non è un tool, è una disciplina: progettare intenzionalmente tutto ciò che entra nella finestra di contesto dell'LLM.

### Le leve

| Leva | Implementazione in Copilot |
|---|---|
| Istruzioni persistenti | `copilot-instructions.md`, `AGENTS.md`, `.instructions.md` |
| Istruzioni per ruolo | Body degli `.agent.md` |
| Istruzioni per task | `.prompt.md`, `SKILL.md` |
| Istruzioni per pattern | `.instructions.md` con `applyTo` glob |
| Tool esterni | MCP servers (dati, API, browser) |
| Automazione deterministica | Hooks (formattazione, lint, security gate) |
| Isolamento contesto | Subagent (contesto pulito per subtask) |
| Struttura del repo | Nomi chiari, cartelle logiche, README aggiornati |
| Documentazione inline | Commenti su decisioni architetturali (il perché, non il cosa) |
| Selezione contesto manuale | `#file:...`, `#selection`, `#codebase` |

**Prompt engineering** = scrivere il prompt giusto al momento giusto.
**Context engineering** = progettare tutto l'ambiente che determina cosa l'LLM vede prima di ricevere il prompt.

Ogni componente dell'ecosistema è una forma di context engineering:
- `.agent.md` inietta istruzioni di ruolo e limita i tool
- `.instructions.md` inietta regole per tipo di file
- `SKILL.md` carica capability rilevanti on-demand
- MCP porta dati esterni nel contesto
- Subagent isolano contesto per subtask specifici
- Hooks iniettano contesto a session start e validano output

---

## 10. Spec-kit e confronto con il formato nativo

### Cos'è spec-kit

Spec-kit (github/spec-kit, v0.4.0) è un framework per **Spec-Driven Development**: le specifiche in Markdown guidano design, task e implementazione.

**In pratica:** un set di file `.agent.md` con prompt strutturati + script PowerShell/Bash. La "metodologia" è interamente nei prompt degli agenti.

**Struttura:**

```
.specify/
├── memory/constitution.md       # principi architetturali del progetto
├── scripts/powershell/          # script automazione
└── templates/                   # template per spec, plan, tasks

.github/
├── agents/                      # 9 agenti spec-kit (uno per fase)
└── prompts/                     # slash command → puntano agli agenti
```

**Il flusso:**

```
Constitution → Specify → Clarify → Plan → Tasks → Analyze → Tasks→Issues → Implement
```

### Confronto spec-kit vs formato nativo VS Code Copilot

| Aspetto | Spec-kit | Formato nativo |
|---|---|---|
| **Formato agente** | `.agent.md` con solo `description` e `handoffs` | `.agent.md` completo con `tools`, `agents`, `mcp-servers`, `model`, `hooks` |
| **Orchestrazione** | Manuale (handoffs = bottoni UI) | Programmabile (tool `agent`, fan-out/fan-in parallelo) |
| **Sandboxing** | Nessuno (ogni agente ha accesso a tutto) | Granulare (`tools:` per agente) |
| **MCP** | Non usato | Inline nel frontmatter o via `mcp.json` |
| **Skills** | Non usate | `SKILL.md` con risorse, portabili |
| **Hooks** | Non usati | Lifecycle hooks deterministici |
| **Instructions** | `constitution.md` (caricata esplicitamente) | `copilot-instructions.md` (always-on) + `.instructions.md` (glob) |
| **Enforcement** | Solo per prompt (l'agente "verifica" a parole) | Hooks + sandboxing tool |
| **Parallelismo** | Non possibile | Subagent paralleli via tool `agent` |
| **Portabilità** | VS Code only | VS Code + Claude compat + CLI + coding agent |

### Valore di spec-kit

- La **metodologia** (spec → plan → tasks → analyze) ha valore indipendente dal formato
- I **template** per artefatti sono utili come punto di partenza
- La **constitution** come concetto è valido — da implementare con strumenti nativi
- Gli **Script** per automazione cartelle/branch funzionano

### Limiti

- La logica è fusa dentro gli `.agent.md` — non puoi separare la metodologia dall'agente
- Non usa nessuna feature del formato moderno (tools, agents, mcp-servers, hooks)
- Handoffs manuali al posto di orchestrazione programmabile
- Nessun gate tecnico reale — tutto è enforcement per prompt

---

## 11. Risorse

### Documentazione ufficiale VS Code Copilot

- **Customization overview:** https://code.visualstudio.com/docs/copilot/customization/overview
- **Custom Agents:** https://code.visualstudio.com/docs/copilot/customization/custom-agents
- **Custom Instructions:** https://code.visualstudio.com/docs/copilot/customization/custom-instructions
- **Prompt Files:** https://code.visualstudio.com/docs/copilot/customization/prompt-files
- **Agent Skills:** https://code.visualstudio.com/docs/copilot/customization/agent-skills
- **MCP Servers:** https://code.visualstudio.com/docs/copilot/customization/mcp-servers
- **Hooks:** https://code.visualstudio.com/docs/copilot/customization/hooks
- **Subagents:** https://code.visualstudio.com/docs/copilot/agents/subagents
- **Agent Plugins:** https://code.visualstudio.com/docs/copilot/customization/agent-plugins
- **MCP configuration reference:** https://code.visualstudio.com/docs/copilot/reference/mcp-configuration
- **Release notes (novità mensili):** https://code.visualstudio.com/updates

### Standard e community

- **Agent Skills standard:** https://agentskills.io/
- **Model Context Protocol:** https://modelcontextprotocol.io/
- **Awesome Copilot (ufficiale GitHub):** https://github.com/github/awesome-copilot
  - 100+ agenti, instructions, skills, plugins, hooks, workflows
  - Website: https://awesome-copilot.github.com
- **Reference skills (Anthropic):** https://github.com/anthropics/skills
- **Spec-kit:** https://github.com/github/spec-kit


