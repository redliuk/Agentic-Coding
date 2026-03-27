# Claude Code — Analisi completa

## 1. Cos'è

Claude Code è un **agentic coding tool** di Anthropic. Legge il codebase, modifica file, esegue comandi e integra tool esterni. Disponibile come:
- **CLI nel terminale** (l'esperienza principale) — esecuzione locale
- **Estensione VS Code e JetBrains** — integrazione IDE locale
- **Desktop app e Web app** — la versione web esegue su VM remota Anthropic, non sulla macchina dell'utente
- **Remote Control** (da mobile, claude.ai, o Claude iOS app)

Pur operando tramite un'interfaccia conversazionale turn-based (chat), si distingue dai chatbot tradizionali per le sue capacità agentiche: esplora autonomamente il codebase, pianifica e implementa in modo multi-step. Nelle modalità standard mantiene un loop di controllo umano; in modalità `auto` o remote tasks può operare con autonomia più ampia. Usa modelli Claude (Sonnet, Opus, Haiku).

## 2. Architettura

```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code Session                       │
│                                                              │
│  Context Window (il vincolo fondamentale)                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  System Prompt (built-in, estendibile con --system-   │   │
│  │  prompt o --append-system-prompt; policy Anthropic     │   │
│  │  non rimovibili)                                      │   │
│  │                                                       │   │
│  │  CLAUDE.md files (caricati all'avvio)                 │   │
│  │  Auto Memory (primi 200 righe di MEMORY.md)           │   │
│  │  .claude/rules/*.md (condizionali a path)             │   │
│  │  Skills descriptions (per auto-invocazione)           │   │
│  │  Subagent descriptions (per auto-delega)              │   │
│  │  Conversazione + Tool Outputs                         │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  Tools: Agent, Bash, Read, Write, Edit, Grep, Glob,         │
│         WebFetch, WebSearch, PowerShell, LSP, Skill,         │
│         NotebookEdit, MCP tools...                           │
│                                                              │
│  Subagents: Explore (Haiku, read-only), Plan, General,      │
│             + custom subagents                               │
│                                                              │
│  Agent Teams (sperimentale): sessioni Claude indipendenti    │
│  che collaborano via task list condivisa e messaggi diretti   │
└─────────────────────────────────────────────────────────────┘
```

## 3. Sistema di memoria e istruzioni

Claude Code ha **più sistemi di istruzioni complementari**, caricati a inizio sessione:

### CLAUDE.md files (scritti da te)

| Posizione | Scope |
|---|---|
| `C:\Program Files\ClaudeCode\CLAUDE.md` | Managed policy — organizzazione |
| `./CLAUDE.md` o `./.claude/CLAUDE.md` | Progetto — condivisi via VCS |
| `~/.claude/CLAUDE.md` | Utente — preferenze personali |

- Caricati in ordine gerarchico (parent → child)
- Supportano `@path/import` per importare file aggiuntivi
- File nei subdirectory caricati on-demand quando Claude legge file in quelle directory
- **Importa AGENTS.md:** se il repo usa AGENTS.md per altri tool, lo importi con `@AGENTS.md`

### `.claude/rules/` — Regole modulari

File `.md` in `.claude/rules/`, ognuno su un topic. Supportano **path-specific rules** via frontmatter:

```yaml
---
paths:
  - "src/api/**/*.ts"
---
# Regole API
- Tutti gli endpoint devono avere validazione input
- Usa il formato di errore standard
```

Le regole con `paths` si caricano solo quando Claude lavora su file che matchano il pattern.

### Auto Memory (scritta da Claude)

- Claude salva note automaticamente: build commands, pattern, preferenze
- Stored in `~/.claude/projects/<project>/memory/`
- `MEMORY.md` (index, primi ~200 righe caricati ad ogni sessione — limite osservato empiricamente, non documentato come contratto stabile)
- File topic (debugging.md, patterns.md...) caricati on-demand
- Edit e delete manuali possibili tramite `/memory`
- Ogni worktree/subdirectory nello stesso repo condivide la stessa auto memory

## 4. Subagents — Worker specializzati

I subagent sono assistenti specializzati che operano nel proprio context window. Definiti come file Markdown con frontmatter YAML in:

| Priorità | Posizione | Scope |
|---|---|---|
| 1 (alta) | `--agents` CLI flag (JSON) | Solo sessione corrente |
| 2 | `.claude/agents/` | Progetto (versionabile) |
| 3 | `~/.claude/agents/` | Utente (tutti i progetti) |
| 4 (bassa) | Plugin `agents/` | Dove il plugin è abilitato |

### Formato file subagent

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
model: sonnet
permissionMode: default
maxTurns: 50
skills:
  - api-conventions
mcpServers:
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
memory: project
background: false
isolation: worktree
effort: high
---

You are a code reviewer. Analyze the code and provide
specific, actionable feedback on quality, security, and best practices.
```

### Frontmatter fields completi

| Campo | Funzione |
|---|---|
| `name` | Identificativo unico (obbligatorio) |
| `description` | Quando Claude deve delegare (obbligatorio) |
| `tools` | Allowlist tool (default: eredita tutti) |
| `disallowedTools` | Denylist tool |
| `model` | `sonnet`, `opus`, `haiku`, ID completo, o `inherit` |
| `permissionMode` | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `maxTurns` | Limite turn agentico |
| `skills` | Skill precaricate nel contesto del subagent |
| `mcpServers` | Server MCP scoped al subagent (inline o reference) |
| `hooks` | Hook di lifecycle (`PreToolUse`, `PostToolUse`, `Stop`) |
| `memory` | `user`, `project`, `local` — memoria persistente cross-sessione |
| `background` | `true` per eseguire sempre in background |
| `isolation` | `worktree` per git worktree isolato e temporaneo |
| `effort` | `low`, `medium`, `high`, `max` (solo Opus 4.6) |
| `initialPrompt` | Prompt auto-inviato quando l'agente è il main (via `--agent`) |

### Subagent built-in

| Nome | Modello | Tools | Scopo |
|---|---|---|---|
| Explore | Haiku | Read-only | Ricerca/analisi codebase (3 livelli: quick, medium, very thorough) |
| Plan | — | — | Pianificazione approcci |
| General-purpose | — | — | Task generiche |

**Vincolo documentato:** i subagent **non possono avviare altri subagent**. La documentazione ufficiale riporta questa limitazione come design policy corrente — non è confermato se si tratti di un hard limit a livello runtime o di una restrizione applicativa che potrebbe essere rilassata in versioni future.

### Delegazione

Claude delega automaticamente in base alla `description` del subagent. Oppure:
- Natural language: "Usa il code-reviewer per..."
- @-mention: `@"code-reviewer (agent)" analizza i cambiamenti`
- Session-wide: `claude --agent code-reviewer` (il subagent diventa il main thread)

### Foreground vs Background

- **Foreground:** blocca la conversazione, permission prompts passano a te
- **Background:** concorrente, permessi pre-approvati prima di avvio, domande non interattive falliscono

## 5. Agent Teams — Parallelismo a livello di sessione

**SPERIMENTALE / PREVIEW** (disabilitato di default, feature non documentata stabilmente). Abilita con:
```json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```

A differenza dei subagent (che riportano solo al main agent), i **teammate sono sessioni Claude indipendenti** che:
- Condividono una **task list**
- Comunicano **direttamente tra loro** (via mailbox)
- Sono gestiti da un **team lead** (la sessione principale)
- Possono auto-assegnarsi task non bloccati

### Architettura

```
┌──────────────────────────────────────────────────┐
│                  Team Lead                        │
│        (sessione principale, coordina)            │
│                                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │Teammate A│←→│Teammate B│←→│Teammate C│       │
│  │ (own ctx)│  │ (own ctx)│  │ (own ctx)│       │
│  └──────────┘  └──────────┘  └──────────┘       │
│        ↕              ↕              ↕            │
│  ┌─────────────────────────────────────────┐     │
│  │         Shared Task List                 │     │
│  │  (pending → in-progress → completed)     │     │
│  │  (con dipendenze tra task)               │     │
│  └─────────────────────────────────────────┘     │
└──────────────────────────────────────────────────┘
```

### Subagent vs Agent Teams

| | Subagent | Agent Team |
|---|---|---|
| **Context** | Proprio, risultati tornano al caller | Proprio, completamente indipendente |
| **Comunicazione** | Solo report back al main | Comunicazione diretta tra teammate |
| **Coordinazione** | Main agent gestisce tutto | Task list condivisa con auto-coordinazione |
| **Best for** | Task focalizzati dove conta solo il risultato | Lavoro complesso che necessita discussione/collaborazione |
| **Costo token** | Basso: risultati riassunti | Alto: ogni teammate è un'istanza Claude separata |

### Limitazioni agent teams

- Non si possono riprendere teammate in-process dopo `/resume`
- Niente team annidati (solo il lead gestisce)
- Lead fisso per tutta la durata
- Split panes richiedono tmux o iTerm2 (non supportato in VS Code terminal)

## 6. Skills — Workflow riutilizzabili

Le Skill sono cartelle con un file `SKILL.md` (istruzioni + frontmatter YAML) più risorse opzionali (script, template, esempi). Invocabili con `/skill-name` o auto-attivate da Claude. Esiste un'iniziativa (`agentskills.io`) che propone convergenza sul formato, ma non è uno standard formale con governance, specifica versionata o interoperabilità reale tra vendor — VS Code Copilot ha un proprio formato `SKILL.md` indipendente.

### Struttura di una skill

```
.claude/skills/
└── webapp-testing/              # nome directory = nome skill
    ├── SKILL.md                 # istruzioni + frontmatter (obbligatorio)
    ├── test-template.js         # script template (opzionale)
    └── examples/                # esempi (opzionali)
```

### Formato `SKILL.md` — frontmatter completo

```yaml
---
name: webapp-testing              # deve corrispondere al nome cartella (max 64 char)
description: >                    # Claude lo usa per decidere quando caricarla
  Test web app con Playwright.
  Usa quando l'utente chiede di testare UI.
argument-hint: "[test file] [options]"  # hint nell'autocomplete
disable-model-invocation: false   # true = solo manuale, Claude non la carica
user-invocable: true              # false = nascosta dal menu /
allowed-tools: Read, Grep, Bash   # tool permessi senza chiedere conferma
model: sonnet                     # modello da usare quando attiva
effort: high                      # low, medium, high, max (solo Opus 4.6)
context: fork                     # fork = esegue in subagent isolato
agent: Explore                    # tipo subagent quando context: fork
hooks:                            # hooks scoped alla skill
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
shell: powershell                 # shell per !`command` (bash default)
---

Istruzioni in Markdown...
```

### Campi frontmatter in dettaglio

| Campo | Obbligatorio | Default | Funzione |
|---|---|---|---|
| `name` | No | nome directory | Identificativo e nome del slash command `/name` |
| `description` | Raccomandato | primo paragrafo body | Claude lo usa per decidere se caricare la skill |
| `argument-hint` | No | — | Hint mostrato nell'autocomplete |
| `disable-model-invocation` | No | `false` | `true` = solo invocazione manuale (`/name`) |
| `user-invocable` | No | `true` | `false` = nascosta dal menu `/`, solo auto-attivazione |
| `allowed-tools` | No | — | Tool permessi senza conferma quando la skill è attiva |
| `model` | No | sessione | Modello da usare quando la skill è attiva |
| `effort` | No | sessione | `low`, `medium`, `high`, `max` (Opus 4.6) |
| `context` | No | inline | `fork` = esegue in subagent isolato |
| `agent` | No | `general-purpose` | Tipo subagent quando `context: fork` (`Explore`, `Plan`, custom) |
| `hooks` | No | — | Hooks scoped alla skill (formato identico a settings.json) |
| `shell` | No | `bash` | `powershell` per `!`command`` su Windows |

### Controllo invocazione

| Configurazione | Menu `/` | Auto-attivazione Claude | Caso d'uso |
|---|---|---|---|
| (default) | Sì | Sì | Skill general-purpose |
| `disable-model-invocation: true` | Sì | No | Workflow con side effects (`/deploy`) |
| `user-invocable: false` | No | Sì | Knowledge di background |

### Posizioni

| Posizione | Scope |
|---|---|
| Enterprise (managed settings) | Organizzazione |
| `~/.claude/skills/<name>/SKILL.md` | Utente (tutti i progetti) |
| `.claude/skills/<name>/SKILL.md` | Progetto |
| Plugin `skills/` | Dove il plugin è abilitato |

### Substitution e preprocessing

| Syntax | Funzione |
|---|---|
| `$ARGUMENTS` | Tutti gli argomenti passati |
| `$ARGUMENTS[N]` o `$N` | Argomento per indice (0-based) |
| `${CLAUDE_SESSION_ID}` | ID sessione corrente |
| `${CLAUDE_SKILL_DIR}` | Directory della skill |
| `!`command`` | **Preprocessing:** esegue comando shell, l'output sostituisce il placeholder prima che Claude veda il prompt |

### Skill bundled notevoli

- `/batch <instruction>` — orchestrazione large-scale: ricerca codebase, decompone in 5-30 unità, spawna un agent per unità in git worktree isolato
- `/simplify [focus]` — review qualità con 3 agenti paralleli
- `/loop [interval] <prompt>` — esecuzione ripetuta su schedule
- `/debug [description]` — analisi log di debug
- `/claude-api` — reference API per il linguaggio del progetto

### Skill vs Subagent

Le skill sono workflow/conoscenze che girano nel contesto della conversazione (o in un fork con `context: fork`). I subagent sono entità con proprio context window, modello, tool e permessi. Con `context: fork`, una skill diventa di fatto un subagent — scegli il tipo con il campo `agent`.

## 7. Hooks — Automazione deterministica

Hook = comando che gira automaticamente a punti specifici del lifecycle. A differenza di CLAUDE.md (suggerimenti che il modello può ignorare), gli hook sono **deterministici per design**: si attivano sempre al trigger corrispondente. Tuttavia non sono "garantiti" in senso forte — possono fallire per timeout, errori di processo o limiti di sandbox. Supportano 4 tipi: `command` (shell), `http` (endpoint), `prompt` (LLM single-turn), `agent` (subagent con tool).

### Hook events

| Evento | Matcher su | Può bloccare? | Quando |
|---|---|---|---|
| `SessionStart` | come è iniziata (`startup`, `resume`, `clear`, `compact`) | No | Sessione avviata |
| `UserPromptSubmit` | — | Sì | Utente invia prompt |
| `PreToolUse` | nome tool (`Bash`, `Edit`, `mcp__*`) | Sì | Prima dell'uso di un tool |
| `PermissionRequest` | nome tool | Sì | Dialog di permesso mostrato |
| `PostToolUse` | nome tool | No (tool già eseguito) | Dopo tool (successo) |
| `PostToolUseFailure` | nome tool | No | Dopo tool (fallimento) |
| `Notification` | tipo notifica | No | Notifica inviata |
| `SubagentStart` | tipo agente | No | Subagent avviato |
| `SubagentStop` | tipo agente | Sì | Subagent terminato |
| `Stop` | — | Sì | Agente finisce il turno |
| `StopFailure` | tipo errore (`rate_limit`, `server_error`...) | No | Turno terminato per errore API |
| `TeammateIdle` | — | Sì | Teammate sta per andare idle |
| `TaskCompleted` | — | Sì | Task marcato completato |
| `InstructionsLoaded` | motivo caricamento | No | CLAUDE.md o rules caricati |
| `ConfigChange` | sorgente config | Sì | File config cambiato |
| `CwdChanged` | — | No | Working directory cambiata |
| `FileChanged` | nome file (basename) | No | File osservato modificato |
| `WorktreeCreate` | — | Sì | Worktree in creazione |
| `WorktreeRemove` | — | No | Worktree in rimozione |
| `PreCompact` | trigger (`manual`, `auto`) | No | Prima della compattazione |
| `PostCompact` | trigger | No | Dopo la compattazione |
| `Elicitation` | nome server MCP | Sì | MCP chiede input utente |
| `ElicitationResult` | nome server MCP | Sì | Utente risponde a elicitation |
| `SessionEnd` | motivo uscita | No | Sessione terminata |

### Formato configurazione

Gli hook si definiscono in file JSON con 3 livelli di nesting:

```json
// .claude/settings.json
{
  "hooks": {
    "PreToolUse": [          // 1. evento
      {
        "matcher": "Bash",   // 2. filtro regex (opzionale)
        "hooks": [            // 3. handler da eseguire
          {
            "type": "command",
            "command": ".claude/hooks/validate.sh",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

### Posizioni

| Posizione | Scope |
|---|---|
| `~/.claude/settings.json` | Utente (tutti i progetti) |
| `.claude/settings.json` | Progetto (versionabile) |
| `.claude/settings.local.json` | Progetto (gitignored) |
| Managed policy settings | Organizzazione |
| Plugin `hooks/hooks.json` | Dove il plugin è abilitato |
| Frontmatter skill/agent | Scoped al componente attivo |

### Tipi di hook handler

**Command** (`type: "command"`):

| Campo | Obbligatorio | Default | Funzione |
|---|---|---|---|
| `type` | Sì | — | `"command"` |
| `command` | Sì | — | Shell command da eseguire |
| `timeout` | No | 600 | Timeout in secondi |
| `async` | No | `false` | `true` = esegue in background senza bloccare |
| `shell` | No | `bash` | `"powershell"` per Windows |
| `statusMessage` | No | — | Messaggio spinner personalizzato |
| `once` | No | `false` | `true` = esegue una sola volta per sessione (solo in skill) |

**HTTP** (`type: "http"`):

| Campo | Obbligatorio | Default | Funzione |
|---|---|---|---|
| `type` | Sì | — | `"http"` |
| `url` | Sì | — | URL per la POST request |
| `timeout` | No | 600 | Timeout in secondi |
| `headers` | No | — | Header HTTP (key-value, supporta `$VAR_NAME`) |
| `allowedEnvVars` | No | — | Variabili d'ambiente permesse nell'interpolazione header |

**Prompt** (`type: "prompt"`) — LLM single-turn:

| Campo | Obbligatorio | Default | Funzione |
|---|---|---|---|
| `type` | Sì | — | `"prompt"` |
| `prompt` | Sì | — | Testo da inviare all'LLM. `$ARGUMENTS` = input JSON dell'hook |
| `model` | No | fast model | Modello da usare |
| `timeout` | No | 30 | Timeout in secondi |

Risposta attesa: `{ "ok": true }` per permettere, `{ "ok": false, "reason": "..." }` per bloccare.

**Agent** (`type: "agent"`) — subagent con tool:

| Campo | Obbligatorio | Default | Funzione |
|---|---|---|---|
| `type` | Sì | — | `"agent"` |
| `prompt` | Sì | — | Task per il subagent. `$ARGUMENTS` = input JSON |
| `model` | No | fast model | Modello da usare |
| `timeout` | No | 60 | Timeout in secondi |

Il subagent può usare Read, Grep, Glob per ispezionare il codebase. Max 50 turni. Stessa risposta: `{ "ok": true/false }`.

### Input/Output

Ogni hook riceve **JSON via stdin** (command) o **POST body** (http):

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/path/to/project",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "npm test" }
}
```

**Exit codes:**
- `0` = successo, stdout parsato come JSON
- `2` = **errore bloccante** (blocca l'operazione, stderr mostrato a Claude)
- Altro = warning non bloccante

**Output JSON (su stdout, solo exit 0):**

| Campo | Default | Funzione |
|---|---|---|
| `continue` | `true` | `false` = ferma Claude del tutto |
| `stopReason` | — | Messaggio per l'utente quando `continue: false` |
| `systemMessage` | — | Warning mostrato all'utente |
| `suppressOutput` | `false` | `true` = nasconde stdout dal verbose mode |

**Controllo decisionale per evento:**

| Evento | Meccanismo | Valori |
|---|---|---|
| `PreToolUse` | `hookSpecificOutput.permissionDecision` | `"allow"`, `"deny"`, `"ask"` |
| `PermissionRequest` | `hookSpecificOutput.decision.behavior` | `"allow"`, `"deny"` |
| `UserPromptSubmit`, `PostToolUse`, `Stop`, `SubagentStop`, `ConfigChange` | top-level `decision` | `"block"` |
| `TeammateIdle`, `TaskCompleted` | exit code 2 o `continue: false` | — |
| `WorktreeCreate` | path su stdout | percorso assoluto worktree |
| `Elicitation`, `ElicitationResult` | `hookSpecificOutput.action` | `"accept"`, `"decline"`, `"cancel"` |

### Variabili d'ambiente disponibili

| Variabile | Disponibile in | Funzione |
|---|---|---|
| `$CLAUDE_PROJECT_DIR` | Tutti | Root del progetto |
| `${CLAUDE_PLUGIN_ROOT}` | Plugin | Directory del plugin |
| `${CLAUDE_PLUGIN_DATA}` | Plugin | Directory dati persistenti del plugin |
| `$CLAUDE_ENV_FILE` | SessionStart, CwdChanged, FileChanged | File per persistere variabili d'ambiente |
| `$CLAUDE_CODE_REMOTE` | Tutti | `"true"` in ambienti remoti |

**Exit code 2 = enforcement reale.** Esempio: bloccare `rm -rf` eseguendo un validatore bash nel `PreToolUse` del tool Bash. Questo è un gate tecnico, non prompt-based.

## 8. Tools built-in

| Tool | Permesso? | Funzione |
|---|---|---|
| `Agent` | No | Avvia subagent nel proprio context window |
| `Bash` | Sì | Esegue comandi shell |
| `PowerShell` | Sì | Comandi PowerShell nativi su Windows (opt-in preview) |
| `Read` | No | Legge file |
| `Edit` | Sì | Modifica mirata di file |
| `Write` | Sì | Crea/sovrascrive file |
| `Grep` | No | Ricerca pattern nei file |
| `Glob` | No | Trova file per pattern |
| `WebFetch` | Sì | Fetch da URL |
| `WebSearch` | Sì | Ricerca web |
| `Skill` | Sì | Esegue una skill |
| `LSP` | No | Code intelligence via language server (jump to def, find refs, type errors) |
| `EnterPlanMode` | No | Modalità pianificazione (read-only) |
| `TodoWrite` | Sì | Gestione todo list persistente |
| `NotebookRead` | No | Legge notebook Jupyter |
| `NotebookEdit` | Sì | Modifica notebook Jupyter |
| `EnterWorktree` | No | Git worktree isolato |

> **Nota:** la lista dei tool evolve rapidamente. Verificare nella [documentazione ufficiale](https://code.claude.com/docs/en/tools-reference) per la versione più aggiornata.

"Permesso?" = richiede conferma utente in modalità `default`.

### Parametri dei tool principali (tool_input)

Questi sono i campi che ogni tool riceve come input e che gli hook possono ispezionare/modificare via `tool_input`:

**Bash:**

| Campo | Tipo | Funzione |
|---|---|---|
| `command` | string | Comando shell da eseguire |
| `description` | string | Descrizione opzionale |
| `timeout` | number | Timeout in ms |
| `run_in_background` | boolean | Esecuzione in background |

**Write:**

| Campo | Tipo | Funzione |
|---|---|---|
| `file_path` | string | Percorso assoluto del file |
| `content` | string | Contenuto da scrivere |

**Edit:**

| Campo | Tipo | Funzione |
|---|---|---|
| `file_path` | string | Percorso assoluto del file |
| `old_string` | string | Testo da trovare e sostituire |
| `new_string` | string | Testo sostitutivo |
| `replace_all` | boolean | Sostituire tutte le occorrenze |

**Read:**

| Campo | Tipo | Funzione |
|---|---|---|
| `file_path` | string | Percorso assoluto del file |
| `offset` | number | Riga di inizio (opzionale) |
| `limit` | number | Numero righe (opzionale) |

**Grep:**

| Campo | Tipo | Funzione |
|---|---|---|
| `pattern` | string | Regex da cercare |
| `path` | string | File/directory dove cercare |
| `glob` | string | Filtro glob sui file |
| `output_mode` | string | `"content"`, `"files_with_matches"`, `"count"` |

**Glob:**

| Campo | Tipo | Funzione |
|---|---|---|
| `pattern` | string | Glob pattern (`**/*.ts`) |
| `path` | string | Directory dove cercare |

**Agent:**

| Campo | Tipo | Funzione |
|---|---|---|
| `prompt` | string | Task per il subagent |
| `description` | string | Descrizione breve |
| `subagent_type` | string | Tipo agente (`Explore`, `Plan`, custom) |
| `model` | string | Override modello |

**WebFetch:**

| Campo | Tipo | Funzione |
|---|---|---|
| `url` | string | URL da fetchare |
| `prompt` | string | Prompt per processare il contenuto |

**WebSearch:**

| Campo | Tipo | Funzione |
|---|---|---|
| `query` | string | Query di ricerca |
| `allowed_domains` | array | Solo risultati da questi domini |
| `blocked_domains` | array | Escludi risultati da questi domini |

## 9. MCP in Claude Code

MCP si configura via:
- `claude mcp add <name> -- <command> [args]` (CLI)
- `--mcp-config ./mcp.json` (file di configurazione esterno)
- Inline nei subagent (campo `mcpServers` nel frontmatter)

### Formato `mcpServers` inline (nel frontmatter subagent/skill)

```yaml
mcpServers:
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
  - example-api:
      type: http
      url: "https://example.com/mcp/v1"
```

| Campo | Funzione |
|---|---|
| `type` | `stdio` (processo locale) o `http` (endpoint remoto) |
| `command` | Comando per avviare il server (stdio) |
| `args` | Argomenti del comando |
| `url` | URL del server (http) |
| `env` | Variabili d'ambiente per il processo |

### Scoping al subagent

I server MCP definiti inline nel frontmatter di un subagent:
- Si **connettono all'avvio** del subagent
- Si **disconnettono alla fine**
- La **conversazione principale non vede** i tool MCP del subagent
- I tool MCP appaiono come `mcp__<server>__<tool>` (es. `mcp__playwright__screenshot`)

Questo permette di dare a un subagent tool specializzati (browser, database, API) senza inquinare il contesto degli altri agenti.

### Hooks su tool MCP

I tool MCP appaiono negli hook come normali tool. Pattern matcher:
- `mcp__memory__.*` — tutti i tool del server `memory`
- `mcp__.*__write.*` — qualsiasi tool "write" da qualsiasi server

## 10. Permission modes

| Modalità | Comportamento |
|---|---|
| `default` | Permission checking standard con prompt |
| `acceptEdits` | Auto-accept edit di file |
| `dontAsk` | Auto-deny permission prompts (tool esplicitamente permessi funzionano) |
| `bypassPermissions` | Salta tutto (pericoloso) |
| `plan` | Read-only, no modifiche |
| `auto` | Classificatore AI valuta ogni operazione (Team plan, Sonnet 4.6+) — **research preview, non stabile** |

## 11. Workflow raccomandato (pattern suggerito dalle best practices ufficiali)

Questo è un pattern suggerito, non un'architettura prescritta del sistema:

```
1. Explore (Plan Mode)   → leggi file, capisci il codebase
2. Plan (Plan Mode)      → crea piano di implementazione dettagliato
3. Implement (Normal)    → codifica seguendo il piano
4. Verify                → test, lint, screenshot
5. Commit & PR           → claude gestisce git e PR
```

**Principio chiave:** "Give Claude a way to verify its work" — fornisci test, screenshot, output attesi. La singola cosa a più alto impatto.

---

## 12. Nota metodologica sulle fonti

Questa analisi combina informazioni da fonti con diversi livelli di affidabilità. Per trasparenza:

| Indicatore | Significato |
|---|---|
| _(nessuna nota)_ | Documentazione ufficiale pubblica e stabile |
| _"osservato empiricamente"_ | Comportamento verificato ma non documentato come contratto API |
| _"preview / sperimentale"_ | Feature flag, research preview, o funzionalità non GA |

Le sezioni che contengono elementi sperimentali o osservati sono annotate inline. La documentazione ufficiale di riferimento è indicata nella sezione Risorse.

**Nota epistemologica:** questa analisi privilegia la documentazione ufficiale come fonte primaria, ma riconosce che in sistemi AI in rapida evoluzione la documentazione può essere incompleta, in ritardo rispetto all'implementazione, o deliberatamente opaca su alcune capacità. Dove rilevante, vengono segnalati comportamenti osservati e inferenze architetturali, distinguendoli esplicitamente dalla documentazione stabile. Alcuni elementi omessi (es. tool non confermati nella documentazione pubblica) sono scelte conservative che privilegiano la verificabilità rispetto alla completezza.

---

## 13. Risorse Claude Code

- **Documentazione ufficiale:** https://code.claude.com/docs/en/overview
- **Subagent:** https://code.claude.com/docs/en/sub-agents
- **Agent Teams:** https://code.claude.com/docs/en/agent-teams
- **Skills:** https://code.claude.com/docs/en/skills
- **Memory (CLAUDE.md):** https://code.claude.com/docs/en/memory
- **Hooks:** https://code.claude.com/docs/en/hooks
- **Tools reference:** https://code.claude.com/docs/en/tools-reference
- **Best practices:** https://code.claude.com/docs/en/best-practices
- **CLI reference:** https://code.claude.com/docs/en/cli-usage
- **Agent SDK:** https://platform.claude.com/docs/en/agent-sdk/overview
