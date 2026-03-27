# VS Code + GitHub Copilot vs Claude Code — Confronto completo

Analisi comparativa tra i due principali approcci al coding assistito e agentico: **VS Code con GitHub Copilot** (Microsoft/GitHub) e **Claude Code** (Anthropic).

> **Data analisi:** Marzo 2026. Entrambi i sistemi evolvono rapidamente — verificare la documentazione ufficiale per lo stato più aggiornato.

---

## Indice

1. [Panoramica e filosofia](#1-panoramica-e-filosofia)
2. [Architettura](#2-architettura)
3. [Sistema di memoria e istruzioni](#3-sistema-di-memoria-e-istruzioni)
4. [Agenti e subagent](#4-agenti-e-subagent)
5. [Skills](#5-skills)
6. [Hooks e automazione deterministica](#6-hooks-e-automazione-deterministica)
7. [Tool e capabilities](#7-tool-e-capabilities)
8. [MCP (Model Context Protocol)](#8-mcp-model-context-protocol)
9. [Sicurezza e permessi](#9-sicurezza-e-permessi)
10. [Workflow e modalità operative](#10-workflow-e-modalità-operative)
11. [Context engineering](#11-context-engineering)
12. [Modelli AI e flessibilità](#12-modelli-ai-e-flessibilità)
13. [Deployment e piattaforme](#13-deployment-e-piattaforme)
14. [Limiti pratici](#14-limiti-pratici)
15. [Discrepanze e note critiche](#15-discrepanze-e-note-critiche)
16. [Tabella sinottica](#16-tabella-sinottica)
17. [Quando scegliere cosa](#17-quando-scegliere-cosa)

---

## 1. Panoramica e filosofia

### VS Code + GitHub Copilot

**Filosofia:** IDE-first, estensibile, model-agnostic. Copilot è un ecosistema modulare integrato in VS Code che offre completamento codice, chat, agenti custom e automazione — tutto dentro l'editor. L'utente ha il pieno controllo sull'ambiente e può personalizzare ogni componente.

**Approccio:** architettura a componenti separati (agents, instructions, skills, prompts, hooks, MCP) che si compongono liberamente. L'ecosistema privilegia la modularità e la portabilità dei componenti. Con l'integrazione di agenti Claude, Codex e altri provider direttamente nel workflow, Copilot sta evolvendo da multi-model a **multi-agent ecosystem**.

### Claude Code

**Filosofia:** agent-runtime-first, agentic-native. Claude Code nasce come tool a riga di comando ma oggi offre interfacce multiple: CLI (l'esperienza originaria e più potente), estensioni IDE (VS Code, JetBrains), desktop app, web app (su VM remota Anthropic) e remote control da mobile. L'agente opera direttamente sul filesystem e nel terminale con autonomia elevata di default: legge, scrive, esegue comandi, naviga il web.

**Approccio:** monolitico con estensioni. Un singolo agente potente che può essere esteso con subagent, skill e tool MCP, ma il cuore è sempre la sessione con il modello Claude, indipendente dall'interfaccia.

### Differenza fondamentale

| | VS Code + Copilot | Claude Code |
|---|---|---|
| **Punto di partenza** | IDE con AI integrata | Agent runtime con interfacce multiple (CLI, IDE, web, desktop, mobile) |
| **Modello mentale** | "Copilota" che assiste nel tuo ambiente | "Agente" che opera sul tuo codebase |
| **Default UX** | GUI (editor, chat, dropdown agenti) | CLI come esperienza primaria, ma anche IDE, web e desktop |
| **Vendor lock-in modello** | Basso (multi-model e multi-agent ecosystem: GPT, Claude, Gemini, modelli custom) | Alto (solo modelli Claude: Sonnet, Opus, Haiku) |

---

## 2. Architettura

### VS Code + Copilot

```
┌──────────────────────────────────────────────────────────┐
│                    VS Code Editor                         │
│  ┌────────────────────────────────────────────────────┐  │
│  │           Copilot Chat / Agent Mode                │  │
│  │  ┌─────────┐ ┌─────────┐ ┌──────────┐            │  │
│  │  │ Agent A │ │ Agent B │ │ Agent C  │ (dropdown)  │  │
│  │  └─────────┘ └─────────┘ └──────────┘            │  │
│  │       ↓           ↓           ↓                    │  │
│  │  ┌──────────────────────────────────────┐         │  │
│  │  │    Contesto (instructions, skills)    │         │  │
│  │  └──────────────────────────────────────┘         │  │
│  │       ↓                                            │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐          │  │
│  │  │ Tools    │ │ MCP      │ │ Hooks    │          │  │
│  │  │ (built-in)│ │ (esterni)│ │(lifecycle)│          │  │
│  │  └──────────┘ └──────────┘ └──────────┘          │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────┐                                   │
│  │ Subagent (isolati)  │  fan-out/fan-in parallelo        │
│  └────────────────────┘                                   │
└──────────────────────────────────────────────────────────┘
```

- **Esecuzione:** locale nell'editor. L'AI gira su cloud (API del provider scelto), ma i tool operano localmente.
- **Contesto:** assemblato dall'editor combinando instructions, agent body, skill, file aperti, selezione, MCP resources.
- **Orchestrazione:** programmabile tramite `agents:` field e tool `agent` per subagent paralleli.

### Claude Code

```
┌──────────────────────────────────────────────────────────┐
│                  Claude Code Session (CLI)                │
│                                                           │
│  Context Window (vincolo fondamentale)                    │
│  ┌─────────────────────────────────────────────────────┐ │
│  │  System prompt (built-in, non rimovibile)            │ │
│  │  CLAUDE.md (gerarchia: managed → progetto → utente)  │ │
│  │  Auto Memory (MEMORY.md, ~200 righe)                 │ │
│  │  .claude/rules/*.md (condizionali)                   │ │
│  │  Skill descriptions + Subagent descriptions          │ │
│  │  Conversazione + Tool outputs                        │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                           │
│  Tools: Bash, Read, Write, Edit, Grep, Glob,             │
│         WebFetch, WebSearch, LSP, Agent, Skill,           │
│         PowerShell, NotebookEdit, MCP tools...            │
│                                                           │
│  Subagents → Explore (Haiku), Plan, General, custom       │
│  Agent Teams → (sperimentale) sessioni indipendenti       │
└──────────────────────────────────────────────────────────┘
```

- **Esecuzione:** locale (CLI/IDE) o remota (web app su VM Anthropic, remote tasks).
- **Contesto:** caricato all'avvio da file system locale (CLAUDE.md, rules, memory). Context window come risorsa scarsa e gestita esplicitamente.
- **Orchestrazione:** subagent (foreground/background) + Agent Teams (sperimentale, parallelismo con comunicazione diretta).

### Differenze architetturali chiave

| Aspetto | VS Code + Copilot | Claude Code |
|---|---|---|
| **Esecuzione AI** | Cloud (multi-provider) | Cloud (solo Anthropic) |
| **Esecuzione tool** | Locale (editor) | Locale (CLI/terminale) o remota (web) |
| **Context assembly** | Editor assembla da file di customizzazione + codebase | CLI carica da filesystem + auto memory |
| **Gestione contesto** | Implicita (l'editor decide cosa includere) | Esplicita (l'utente vede il context budget, compaction manuale/auto) |
| **Stato sessione** | Persistente nell'editor (storico chat) | Persistente via `/resume`, compaction automatica |
| **Compaction** | Gestita dall'editor (trasparente) | Esplicita (eventi PreCompact/PostCompact, salvabile via hook) |
| **Estensibilità** | Extension API VS Code + MCP + agent ecosystem | MCP + subagent + skill + plugin |

---

## 3. Sistema di memoria e istruzioni

Entrambi i sistemi hanno meccanismi per iniettare contesto persistente. La terminologia e la struttura differiscono:

### VS Code + Copilot

**Istruzioni always-on** (caricate ogni conversazione):

| File | Posizione | Note |
|---|---|---|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Principale. Regole coding, stack, stile |
| `AGENTS.md` | Root repo | Richiede `chat.useAgentsMdFile: true` |
| `CLAUDE.md` | Root repo | Compatibilità (richiede `chat.useClaudeMdFile: true`) |

**Istruzioni condizionali** (caricate per pattern file):

| File | Posizione | Condizione |
|---|---|---|
| `.instructions.md` | `.github/instructions/` | `applyTo: "src/**/*.ts"` (glob) |
| `.claude/rules/*.md` | `.claude/rules/` | `paths:` (compatibilità Claude) |

**Memoria persistente dell'utente:**
- **Non nativa:** Copilot non ha un sistema di auto-memory equivalente a Claude Code. Le "preferenze" sono codificate nelle instructions scritte dall'utente.
- **Memory tool (ad-hoc):** in Agent Mode, Copilot può usare un tool `memory` con 3 scope (user, session, repo), ma è un tool di sessione, non un sistema di apprendimento automatico cross-sessione.

**Gerarchia priorità:** Personale > Repository > Organizzazione.

### Claude Code

**CLAUDE.md** (scrittI dall'utente, equivalente di copilot-instructions.md):

| Posizione | Scope |
|---|---|
| Managed policy (enterprise) | Organizzazione |
| `./CLAUDE.md` o `./.claude/CLAUDE.md` | Progetto (versionabile) |
| `~/.claude/CLAUDE.md` | Utente (tutti i progetti) |

**Rules condizionali** (equivalente di .instructions.md):

| File | Condizione |
|---|---|
| `.claude/rules/*.md` | `paths: ["src/api/**/*.ts"]` (frontmatter YAML) |

**Auto Memory** (scritta da Claude automaticamente — distinta da CLAUDE.md):
- `CLAUDE.md` è **configurazione statica**, scritta dall'utente, equivalente a instructions
- La **memory directory** (`~/.claude/projects/<project>/memory/`) è un **knowledge base mutabile** scritto e aggiornato dal modello stesso
- `MEMORY.md` (index, caricato all'avvio — il limite di ~200 righe è osservato empiricamente, non un contratto stabile)
- File topic (debugging.md, patterns.md...) caricati on-demand
- **Questa è una differenza significativa:** Claude Code accumula conoscenza persistente sul progetto sessione dopo sessione (non è learning del modello, è persistenza strutturata su file)

### Confronto diretto

| Aspetto | VS Code + Copilot | Claude Code |
|---|---|---|
| **Instructions always-on** | `copilot-instructions.md` | `CLAUDE.md` |
| **Instructions condizionali** | `.instructions.md` + `applyTo` glob | `.claude/rules/*.md` + `paths` |
| **Auto-memory** | No (nessun equivalente nativo) | Sì (memory directory mutabile dal modello + MEMORY.md index) |
| **Conoscenza cross-sessione** | No | Sì (accumulo persistente via auto memory, non learning del modello) |
| **Gerarchia** | Personale > Repo > Org | Child > Parent (gerarchia directory) |
| **Import da altri file** | No | Sì (`@path/import`) |
| **Compatibilità cross-tool** | Legge CLAUDE.md e .claude/rules/ | Legge AGENTS.md via import |

---

## 4. Agenti e subagent

### Definizione agenti

Entrambi usano file Markdown con frontmatter YAML:

| Aspetto | VS Code + Copilot | Claude Code |
|---|---|---|
| **File** | `.agent.md` | `.md` (in `.claude/agents/`) |
| **Posizione workspace** | `.github/agents/` | `.claude/agents/` |
| **Posizione utente** | `~/.copilot/agents/` | `~/.claude/agents/` |
| **Formato body** | Markdown | Markdown |
| **Frontmatter** | YAML | YAML |

### Campi frontmatter — confronto

| Campo | VS Code + Copilot | Claude Code | Note |
|---|---|---|---|
| `name` | Sì | Sì | Equivalente |
| `description` | Sì (per auto-invocazione subagent) | Sì (per auto-delegazione) | Equivalente |
| `tools` | Lista con namespace (`read`, `"github/*"`) | Lista stringhe (`Read, Edit, Bash`) | Syntax diversa |
| `agents` (subagent invocabili) | Sì (`agents: [A, B]` o `'*'`) | No (non c'è campo equivalente) | **Differenza significativa** |
| `model` | Sì (multi-provider, lista prioritizzata) | Sì (`sonnet`, `opus`, `haiku`, ID completo) | Copilot: multi-model; Claude: solo Claude |
| `mcp-servers` | Sì (inline) | Sì (`mcpServers` inline) | Equivalente |
| `hooks` | Sì (scoped all'agente) | Sì (scoped all'agente) | Equivalente |
| `handoffs` | Sì (bottoni UI per workflow sequenziale) | No | Feature solo Copilot |
| `user-invocable` | Sì | No (campo `user-invocable` non presente) | Copilot ha controllo più granulare sulla visibilità |
| `disable-model-invocation` | Sì | `disable-model-invocation` (nelle skill) | Simile |
| `argument-hint` | Sì | Sì | Equivalente |
| `permissionMode` | No (gestito da VS Code) | Sì (`default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan`) | Claude: permessi per-agent |
| `maxTurns` | No (gestito dall'editor) | Sì | Claude: controllo granulare |
| `memory` | No | Sì (`user`, `project`, `local`) | Claude: memoria per-subagent |
| `background` | No | Sì (`true` = esecuzione concorrente) | Claude: subagent background |
| `isolation` | No | Sì (`worktree` = git worktree isolato) | Claude: isolamento filesystem |
| `effort` | No | Sì (`low`..`max`, solo Opus 4.6) | Claude: controllo effort computazionale |
| `skills` | No (l'agente trova da solo le skill) | Sì (pre-carica skill specifiche) | Claude: skill pre-assegnate |

### Subagent e orchestrazione

| Aspetto | VS Code + Copilot | Claude Code |
|---|---|---|
| **Meccanismo** | Tool `agent` / `runSubagent` | Tool `Agent` |
| **Contesto** | Isolato (riceve solo il prompt del task) | Isolato (proprio context window) |
| **Nesting** | Sì, fino a 5 livelli (richiede setting) | No come design policy (non confermato se sia hard limit runtime o restrizione applicativa) |
| **Parallellismo** | Sì (fan-out/fan-in nativo via tool `agent`) | Foreground (bloccante) o Background (concorrente) |
| **Auto-delegazione** | Sì (basata su `description`) | Sì (basata su `description`) |
| **Controllo invocazione** | `agents:` nel frontmatter (whitelist) | Nessun campo whitelist |
| **Model override** | Sì (nel frontmatter) | Sì (`model` nel frontmatter) |
| **Permission dei subagent** | Ereditano dal contesto VS Code | `permissionMode` specifico per subagent |

### Agent Teams (solo Claude Code)

Feature **sperimentale** esclusiva di Claude Code. A differenza dei subagent (che riportano al caller), i "teammate" sono sessioni indipendenti che:
- Condividono una **task list** con dipendenze
- Comunicano **direttamente tra loro** (mailbox)
- Sono coordinati da un **team lead**
- Possono auto-assegnarsi task non bloccati

**Copilot non ha un equivalente.** Il pattern più vicino è lanciare N subagent in parallelo da un coordinatore, ma senza comunicazione diretta tra subagent.

### Handoffs (solo VS Code + Copilot)

Feature esclusiva di Copilot: bottoni UI che guidano l'utente da un agente al successivo in un workflow sequenziale. Utile per metodologie step-by-step (es. spec-kit: Specify → Plan → Tasks → Implement).

**Claude Code non ha un equivalente UI.** Il pattern più vicino è usare `--agent` per selezionare l'agente principale e delegare manualmente.

> **Nota:** gli handoffs sono puramente UI (bottoni in chat). Non sono programmabili via API né invocabili da altri agenti — sono un meccanismo di guida utente, non di orchestrazione automatica.

---

## 5. Skills

Entrambi supportano il concetto di "Skill" come knowledge riutilizzabile, ma con formati diversi:

| Aspetto | VS Code + Copilot | Claude Code |
|---|---|---|
| **File** | `SKILL.md` in directory dedicata | `SKILL.md` in directory dedicata |
| **Posizione workspace** | `.github/skills/`, `.claude/skills/`, `.agents/skills/` | `.claude/skills/` |
| **Posizione utente** | `~/.copilot/skills/`, `~/.claude/skills/` | `~/.claude/skills/` |
| **Caricamento** | 3 fasi (discovery → instructions → resources) | On-demand o `/skill-name` |
| **Invocazione** | `/nome` o auto-load basato su rilevanza | `/nome` o auto-attivazione |
| **Risorse incluse** | Script, template, esempi nella directory | Script, template, esempi nella directory |
| **Portabilità** | VS Code + Copilot CLI + coding agent + standard `agentskills.io` | Solo Claude Code |
| **Context fork** | No (inline nel contesto corrente) | Sì (`context: fork` → subagent isolato) |
| **Preprocessing** | No | Sì (`!`command`` esegue shell, output iniettato nel prompt) |
| **Substitution** | `${input:var}`, `${selection}` | `$ARGUMENTS`, `$N`, `${CLAUDE_SESSION_ID}`, `${CLAUDE_SKILL_DIR}` |
| **Hooks scoped** | No | Sì (hooks nel frontmatter della skill) |
| **Shell specifica** | No | Sì (`shell: powershell`) |

### Skill bundled

**Claude Code** offre skill built-in potenti:
- `/batch` — orchestrazione large-scale: decompone in 5-30 unità, spawna un agent per unità in git worktree isolato
- `/simplify` — review con 3 agenti paralleli
- `/loop` — esecuzione ripetuta su schedule
- `/debug` — analisi log
- `/claude-api` — reference API

**VS Code + Copilot** non ha skill bundled equivalenti, ma l'ecosistema community (`awesome-copilot`) offre 100+ agenti, skill e workflow pronti.

> **Nota su agentskills.io:** il documento Claude Code menziona correttamente che agentskills.io propone convergenza sul formato SKILL.md, ma non è uno standard formale con governance e interoperabilità reale tra vendor. VS Code Copilot ha il proprio formato indipendente, compatibile nella struttura base ma con campi diversi.

---

## 6. Hooks e automazione deterministica

Entrambi supportano hook deterministici (codice eseguito a eventi di lifecycle), ma con livelli di granularità molto diversi.

### Confronto eventi

| Evento | VS Code + Copilot | Claude Code |
|---|---|---|
| **SessionStart** | Sì | Sì |
| **UserPromptSubmit** | Sì | Sì |
| **PreToolUse** | Sì | Sì |
| **PostToolUse** | Sì | Sì |
| **PostToolUseFailure** | No | Sì |
| **Stop** | Sì | Sì |
| **StopFailure** | No | Sì |
| **SubagentStart** | Sì | Sì |
| **SubagentStop** | Sì | Sì |
| **PreCompact** | Sì | Sì |
| **PostCompact** | No | Sì |
| **PermissionRequest** | No | Sì |
| **Notification** | No | Sì |
| **TeammateIdle** | No | Sì |
| **TaskCompleted** | No | Sì |
| **InstructionsLoaded** | No | Sì |
| **ConfigChange** | No | Sì |
| **CwdChanged** | No | Sì |
| **FileChanged** | No | Sì |
| **WorktreeCreate/Remove** | No | Sì |
| **Elicitation/Result** | No | Sì |
| **SessionEnd** | No | Sì |

**Claude Code ha ~25 eventi hook, VS Code + Copilot ne ha ~8** (conteggio basato sulle versioni correnti — Copilot aggiunge eventi frequentemente). Tuttavia, il numero di eventi non è il differenziatore principale: la vera differenza è nei **tipi di handler** (vedi sotto).

### Tipi di handler

| Tipo | VS Code + Copilot | Claude Code |
|---|---|---|
| **command** (shell) | Sì | Sì |
| **http** (webhook) | No | Sì |
| **prompt** (LLM single-turn) | No | Sì |
| **agent** (subagent con tool) | No | Sì |

Claude Code supporta 4 tipi di handler; Copilot solo comandi shell. **Questo è il vero differenziatore sugli hooks**, più del numero di eventi: poter eseguire un LLM single-turn o un subagent come hook apre scenari impossibili con soli comandi shell (gate semantici, validazione AI-powered, webhook notifiche).

### Formato e posizione

| Aspetto | VS Code + Copilot | Claude Code |
|---|---|---|
| **Formato** | JSON (`.github/hooks/*.json`) | JSON (`.claude/settings.json`) |
| **Scoped all'agente** | Sì (nel frontmatter .agent.md) | Sì (nel frontmatter subagent/skill) |
| **Cross-platform** | `windows`, `linux`, `osx` override | `shell: powershell` |
| **Async** | No | Sì (`async: true`) |
| **Timeout default** | 30s | 600s |
| **Exit code 2** | Errore bloccante | Errore bloccante |

### Compatibilità

VS Code legge `.claude/settings.json` per gli hook, ma **ignora i matcher** (esegue sempre). I nomi tool e le property differiscono (snake_case vs camelCase).

---

## 7. Tool e capabilities

### Tool built-in

| Tool | VS Code + Copilot | Claude Code | Note |
|---|---|---|---|
| **File read** | `read` | `Read` | Equivalente |
| **File edit** | `edit` | `Edit` | Equivalente |
| **File create/write** | `edit` (crea se necessario) | `Write` | Claude separa write da edit |
| **Search (testo)** | `search` (grep_search) | `Grep` | Equivalente |
| **Search (file path)** | `search` (file_search) | `Glob` | Equivalente |
| **Search (semantico)** | `search` (semantic_search) | No (usa Grep + Read) | Copilot ha ricerca semantica nativa (disponibile in Agent Mode; dipende dal provider e dalla modalità) |
| **Terminale (Unix)** | `execute` | `Bash` | Equivalente |
| **Terminale (Windows)** | `execute` | `PowerShell` (opt-in preview) | Equivalente |
| **Web fetch** | Parziale (`fetch_webpage` via tool, alcuni provider hanno browsing) | `WebFetch` | Claude built-in e più integrato |
| **Web search** | Parziale (dipende dal provider) | `WebSearch` | Claude built-in e più integrato |
| **Subagent** | `agent` / `runSubagent` | `Agent` | Equivalente |
| **Skill** | Caricamento automatico | `Skill` (tool esplicito) | Diverso meccanismo |
| **Todo list** | `todo` | `TodoWrite` | Equivalente |
| **LSP** (code intelligence) | Nativo nell'editor | `LSP` (tool esplicito) | Copilot ha accesso più ricco (editor-integrated) |
| **Git worktree** | No | `EnterWorktree` | Solo Claude Code |
| **Plan mode** | Implicito | `EnterPlanMode` | Claude lo esplicita come tool |
| **Notebook** | `run_notebook_cell`, `edit_notebook_file` | `NotebookRead`, `NotebookEdit` | Copilot ha esecuzione celle; Claude ha read/edit |
| **Memory** | `memory` (tool di sessione) | Auto (persistente) | Meccanismi diversi |
| **MCP tools** | Sì (`mcp_<server>_<tool>`) | Sì (`mcp__<server>__<tool>`) | Naming diverso |

### Differenze significative

1. **Ricerca semantica:** Copilot ha `semantic_search` nativo in Agent Mode (ricerca per significato nel codebase, basato su embeddings e code indexing). La disponibilità dipende dal provider e dalla modalità. Claude Code si affida a Grep + Read + ragionamento.
2. **Web access:** Claude Code ha `WebFetch` e `WebSearch` built-in e sempre disponibili. Copilot ha capacità web parziali (`fetch_webpage`, browsing provider-specific), ma meno integrate e non universalmente disponibili in tutte le configurazioni.
3. **LSP integration:** Copilot è nell'editor, ha accesso diretto a jump-to-definition, find-references, type checking, diagnostics. Claude Code ha un tool `LSP` esplicito, meno integrato.
4. **Git worktree:** Claude Code può creare worktree isolati per subagent (`isolation: worktree`). Feature unica per parallelismo sicuro su filesystem.

---

## 8. MCP (Model Context Protocol)

Entrambi supportano MCP come standard per tool esterni:

| Aspetto | VS Code + Copilot | Claude Code |
|---|---|---|
| **Configurazione** | `.vscode/mcp.json`, user profile, inline in agent | `claude mcp add`, `--mcp-config`, inline in agent |
| **Tipi server** | `http`, `stdio` (command) | `stdio`, `http` |
| **Capabilities** | Tools, Resources, Prompts, MCP Apps (UI) | Tools, Resources |
| **MCP Apps** | Sì (UI interattive in chat) | No |
| **Sandboxing** | Sì (filesystem + network, macOS/Linux) | No nativo |
| **Auto-trust** | Con sandbox attivo → tool auto-approvati | No |
| **Scoped al subagent** | Sì (inline nel frontmatter agent) | Sì (inline nel frontmatter subagent) |
| **Enterprise management** | Via GitHub policies | Via managed settings |
| **Discovery** | Extensions view (`@mcp`), marketplace | `claude mcp list` |

### Differenze chiave

- **MCP Apps** è esclusivo di VS Code Copilot: i server MCP possono esporre UI interattive (form, visualizzazioni) direttamente nella chat.
- **Sandboxing MCP** è più maturo in VS Code: con `sandboxEnabled` il server opera in ambiente controllato (filesystem limitato, network filtrato). Claude Code non ha un equivalente nativo.
- **MCP Resources** come feature distinta (dati read-only da aggiungere via `Add Context > MCP Resources`) è meglio integrata in VS Code.

---

## 9. Sicurezza e permessi

### Modello di permessi

| Aspetto | VS Code + Copilot | Claude Code |
|---|---|---|
| **Tool approval** | Per-action nel workspace trust model | Per-action con prompt (`default` mode) |
| **Sandboxing tool** | `tools:` whitelist per agente | `tools` allowlist + `disallowedTools` denylist |
| **Permission modes** | Gestito dal workspace trust di VS Code | 6 modalità: `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan`, `auto` |
| **Subagent sandboxing** | `agents:` whitelist (controllo chi può invocare chi) | `permissionMode` per subagent + `tools`/`disallowedTools` |
| **MCP sandboxing** | Sì (filesystem + network) | No nativo |
| **Hook security** | Stessi permessi dell'editor | Exit code 2 = gate reale |
| **Enterprise policy** | GitHub org settings + VS Code policies | Managed policy settings |

### VS Code + Copilot — Sicurezza

- **Tool sandboxing** granulare: ogni agente ha una whitelist di tool, inclusi namespace MCP (`"github/*"`, `"playwright/*"`)
- **Subagent whitelist:** `agents: [A, B]` impedisce a un agente di invocare agent non autorizzati
- **Nesting controllato:** `chat.subagents.allowInvocationsFromSubagents: true` con profondità massima 5
- **MCP sandbox:** filesystem e network limitati per server MCP (macOS/Linux)
- **Rischio:** se un agente può editare gli script degli hook, può eseguire codice arbitrario → usare `chat.tools.edits.autoApprove` per richiedere approvazione manuale

### Claude Code — Sicurezza

- **Permission modes per subagent:** ogni subagent può avere il proprio livello (da `plan` read-only a `bypassPermissions`)
- **Mode `auto`:** classificatore AI valuta ogni operazione (research preview, non stabile)
- **Git worktree isolation:** subagent operano in worktree temporanei, non toccano il codice principale
- **Hook enforcement reale:** exit code 2 in `PreToolUse` è un gate tecnico, non prompt-based (es. bloccare `rm -rf`)
- **Rischio:** `bypassPermissions` elimina tutti i controlli, `auto` mode è sperimentale

### Confronto

| | VS Code + Copilot | Claude Code |
|---|---|---|
| **Approccio dominante** | Sandboxing preventivo (whitelist tool/agent) | Permission prompting + modes |
| **Enforcement** | Hooks + tool whitelist | Hooks (exit code 2) + permission modes |
| **Isolamento filesystem** | No nativo | Git worktree |
| **MCP sandboxing** | Sì | No |
| **Granularità controllo** | Per-agent (tools, agents) | Per-agent + per-mode + per-session |
| **Enterprise** | Org policies + managed settings | Managed settings + managed policy |

---

## 10. Workflow e modalità operative

### VS Code + Copilot

**Modalità:**
- **Chat mode:** domanda/risposta, nessun tool
- **Edit mode:** inline edits su codice selezionato
- **Agent mode:** pieno accesso ai tool, agentco, multi-step

**Workflow tipico:**
1. Seleziona agente dal dropdown (o usa `/prompt-name`)
2. L'agente carica instructions, skill rilevanti, contesto editor
3. Opera con i tool disponibili (sandboxed)
4. Può delegare a subagent (paralleli o sequenziali)
5. Handoffs manuali per workflow step-by-step (es. spec-kit)

**Pattern di orchestrazione:**
- **Coordinator + Workers:** un orchestratore con tool `agent` che delega a worker specializzati
- **Multi-perspective review:** N subagent paralleli con focus diverso, risultati sintetizzati
- **Recursive:** agente invoca sé stesso per divide-and-conquer
- **Sequential handoff:** bottoni UI per passare da un agente all'altro

### Claude Code

**Modalità:**
- **Normal mode:** ogni operazione richiede conferma
- **Auto-accept edits:** conferma automatica per edit file
- **Plan mode:** read-only, nessuna modifica
- **Auto mode:** classificatore AI decide (sperimentale)
- **Headless / Remote tasks:** esecuzione non interattiva

**Workflow raccomandato (best practices):**
1. **Explore** (Plan Mode) → leggi file, capisci il codebase
2. **Plan** (Plan Mode) → crea piano di implementazione
3. **Implement** (Normal) → codifica seguendo il piano
4. **Verify** → test, lint, screenshot
5. **Commit & PR** → Claude gestisce git e PR

**Pattern di orchestrazione:**
- **Subagent foreground:** bloccante, risultato torna al main
- **Subagent background:** concorrente, più subagent in parallelo
- **Agent Teams (sperimentale):** team lead + teammate con task list condivisa
- **`/batch`:** orchestrazione large-scale con worktree isolati

**Principio chiave (documentazione ufficiale Anthropic):** *"Give Claude a way to verify its work"* — fornire test, screenshot, output attesi è la singola cosa a più alto impatto.

---

## 11. Context engineering

Entrambi richiedono context engineering consapevole, ma con leve diverse:

| Leva | VS Code + Copilot | Claude Code |
|---|---|---|
| **Istruzioni persistenti** | `copilot-instructions.md`, `AGENTS.md` | `CLAUDE.md` (gerarchia), auto memory |
| **Istruzioni per ruolo** | Body `.agent.md` | Body subagent |
| **Istruzioni per task** | `.prompt.md`, `SKILL.md` | `SKILL.md`, skill built-in |
| **Istruzioni per file type** | `.instructions.md` con `applyTo` | `.claude/rules/` con `paths` |
| **Tool esterni** | MCP (+ risorse + MCP apps) | MCP, WebFetch, WebSearch |
| **Automazione deterministica** | Hooks (8 eventi, solo command) | Hooks (25 eventi, 4 tipi handler) |
| **Isolamento contesto** | Subagent (contesto pulito) | Subagent + worktree isolation |
| **Selezione contesto manuale** | `#file:`, `#selection`, `#codebase` | Path espliciti, `/add-context` |
| **Contesto dall'editor** | File aperti, diagnostics, selezione | Limitato (l'editor passa meno contesto) |
| **Context budget visibility** | Bassa (l'editor gestisce) | Alta (l'utente vede e gestisce) |

### Differenza concettuale

In **Copilot**, il context engineering è in gran parte architetturale: si progettano i file di customizzazione e l'editor fa il lavoro di assemblaggio. Il contesto fluisce automaticamente dall'ambiente dell'editor.

In **Claude Code**, il context engineering è più esplicito e manuale: l'utente deve ragionare sulla context window come risorsa scarsa, usare compaction, scegliere quando delegare a subagent (per liberare contesto), e strutturare CLAUDE.md e rules in modo ottimale.

---

## 12. Modelli AI e flessibilità

| Aspetto | VS Code + Copilot | Claude Code |
|---|---|---|
| **Provider** | Multi-provider: OpenAI (GPT-4o, o3), Anthropic (Claude), Google (Gemini), modelli custom | Solo Anthropic |
| **Modelli** | GPT-4.1, Claude Sonnet/Opus/Haiku 4.5, Gemini 2.5 Pro/Flash, o3, o4-mini... | Claude Sonnet 4.5, Opus 4.6, Haiku 4.5 |
| **Scelta per agente** | Sì (`model:` nel frontmatter, lista prioritizzata con fallback) | Sì (`model:` nel frontmatter) |
| **Scelta per subagent** | Sì | Sì |
| **Modelli locali** | Sì (via Ollama o compatibili OpenAI) | No |
| **Modelli custom org** | Sì (enterprise) | No |
| **Effort control** | No | Sì (`effort: low/medium/high/max`, solo Opus 4.6) |
| **Lock-in** | Basso (switch modello senza cambiare workflow) | Alto (tutto l'ecosistema è Anthropic) |

**Nota:** la multi-model flexibility di Copilot è un vantaggio strategico significativo. Permette di usare il modello migliore per ogni task (es. Claude per coding, GPT per ragionamento, Gemini per contesto lungo) senza cambiare tool o workflow. Tuttavia, la disponibilità dei modelli dipende dal piano di abbonamento e dalla modalità (non tutti i modelli sono disponibili in Agent Mode o in tutte le regioni).

---

## 13. Deployment e piattaforme

| Aspetto | VS Code + Copilot | Claude Code |
|---|---|---|
| **IDE** | VS Code (nativo), Visual Studio | VS Code (estensione), JetBrains (estensione) |
| **CLI** | Copilot CLI (in evoluzione) | CLI nativa (l'esperienza principale) |
| **Web** | GitHub.com (Copilot coding agent per PR) | claude.ai (VM remota Anthropic) |
| **Mobile** | No | Remote control (iOS Claude app, mobile web) |
| **Desktop** | VS Code | App desktop |
| **Remote/headless** | GitHub coding agent (cloud) | Remote tasks, headless mode |
| **CI/CD** | GitHub Actions integration | SDK + API per automazione |
| **OS** | Windows, macOS, Linux | macOS, Linux, Windows (WSL consigliato) |

### Remote execution

- **VS Code/Copilot:** il "Copilot coding agent" (GitHub) può operare su PR in cloud come review e fix bot, senza IDE locale.
- **Claude Code:** la versione web esegue su VM Anthropic (non sulla macchina dell'utente). Remote tasks permettono esecuzione headless controllabile da mobile.

---

## 14. Limiti pratici

### VS Code + Copilot

| Limite | Impatto |
|---|---|
| **No auto-memory** | L'utente deve mantenere manualmente le instructions; Copilot non "impara" tra sessioni |
| **Hooks limitati** | Solo 8 eventi, solo command handler — meno automazione possibile |
| **No git worktree isolation** | Subagent paralleli operano sullo stesso filesystem — rischio conflitti |
| **Web access limitato** | Capacità web parziali e provider-dependent, meno integrate dei built-in di Claude Code |
| **MCP sandbox solo macOS/Linux** | Windows non ha sandboxing MCP nativo |
| **Nesting subagent richiede opt-in** | Default: subagent non possono invocare altri subagent |
| **Context window opaca** | L'utente non vede facilmente quanto contesto è stato consumato |
| **Dipendenza dall'editor** | Fuori da VS Code, le capabilities sono ridotte |

### Claude Code

| Limite | Impatto |
|---|---|
| **Solo modelli Claude** | Nessuna possibilità di usare GPT, Gemini o modelli locali |
| **Context window finita** | Compaction necessaria per sessioni lunghe → possibile perdita di contesto |
| **Subagent non nested** | I subagent non possono delegare ad altri subagent (design policy) |
| **Agent Teams sperimentale** | Feature non stabile, non in VS Code terminal, richiede tmux |
| **Auto mode non stabile** | Il classificatore AI per permessi è research preview |
| **Windows support** | WSL consigliato anziché Windows nativo; PowerShell è opt-in preview |
| **Costo token** | Ogni subagent/teammate genera chiamate API separate — il costo per workflow complessi è presumibilmente più alto (inferenza plausibile, non documentato da Anthropic) |
| **Web app ≠ local** | La versione web esegue su VM remota, non ha accesso al filesystem locale |

---

## 15. Discrepanze e note critiche

### Discrepanze tra i documenti forniti

1. **Naming tool MCP:** il documento Claude Code indica `mcp__<server>__<tool>` (doppio underscore), il documento Copilot indica `mcp_<server>_<tool>` (singolo). Entrambi sono corretti per il rispettivo sistema — è una differenza reale di naming convention.

2. **Compatibilità cross-tool hook:** il documento Copilot afferma che VS Code "legge `.claude/settings.json`" ma "ignora i matcher". Questo è corretto ma va evidenziato: in pratica significa che un hook pensato per attivarsi solo su `Bash` in Claude Code si attiverà su **tutti** i tool in VS Code. Questo può causare comportamenti inattesi in repo condivisi.

3. **agentskills.io — standard:** il documento Copilot lo descrive come "standard aperto portabile", il documento Claude Code come "iniziativa senza governance formale". La posizione di Claude Code è più accurata: agentskills.io è una proposta di convergenza, non uno standard ratificato con interoperabilità verificata tra vendor.

### Discrepanze tra documenti e fonti esterne

4. **Subagent nesting in Claude Code:** il documento afferma che i subagent "non possono avviare altri subagent" come design policy. La documentazione ufficiale Anthropic conferma questa restrizione, ma nota che non è chiaro se sia un hard limit runtime o una restrizione applicativa che potrebbe cambiare. In VS Code + Copilot, il nesting è supportato fino a 5 livelli (con opt-in setting).

5. **Auto Memory di Claude Code:** le "prime 200 righe di MEMORY.md" sono documentate nel documento come "osservato empiricamente, non come contratto stabile". Questo è corretto — la documentazione ufficiale non specifica un limite numerico esatto.

6. **Copilot hooks — numero eventi:** il documento Copilot lista 8 eventi (`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PreCompact`, `SubagentStart`, `SubagentStop`, `Stop`). Il set reale potrebbe essere più ampio nelle versioni più recenti di VS Code — la feature è in evoluzione attiva. Il sistema di hooks di Claude Code è comunque significativamente più granulare (25+ eventi).

7. **Claude Code `auto` permission mode:** descritto come "Team plan, Sonnet 4.6+" — questo è un research preview non disponibile a tutti gli utenti. Non è comparabile ai permission models stabili.

### Note di cautela

- Entrambi i sistemi evolvono su cicli mensili. Feature "preview" o "sperimentali" possono cambiare o essere rimosse.
- La compatibilità cross-tool (VS Code legge `.claude/`, Claude Code legge `AGENTS.md`) è utile ma imperfetta — testare sempre il comportamento reale.
- Il costo in token di workflow agentic complessi (specialmente Agent Teams e subagent multipli) può essere significativo.

---

## 16. Tabella sinottica

| Dimensione | VS Code + GitHub Copilot | Claude Code |
|---|---|---|
| **Filosofia** | IDE-first, modulare, multi-model/multi-agent | Agent-runtime-first (CLI + IDE + web + desktop), agentic-native, Claude-only |
| **UI principale** | Editor GUI con chat integrata | CLI REPL (primaria) + IDE, web, desktop, mobile |
| **Modelli** | Multi-provider (GPT, Claude, Gemini, locali) | Solo Claude (Sonnet, Opus, Haiku) |
| **Instructions** | `copilot-instructions.md` + `.instructions.md` | `CLAUDE.md` + `.claude/rules/` |
| **Auto-memory** | No | Sì (memory directory mutabile + MEMORY.md) |
| **Agenti** | `.agent.md` con tools, agents, mcp, hooks, handoffs | `.md` con tools, model, permissionMode, maxTurns, memory, isolation |
| **Subagent nesting** | Sì (5 livelli, opt-in) | No (design policy, non confermato hard limit) |
| **Parallelismo subagent** | Fan-out/fan-in nativo | Background subagent + Agent Teams (sperimentale) |
| **Skills** | `SKILL.md` (formato portabile, ispirato a agentskills.io — non uno standard ratificato) | `SKILL.md` (con preprocessing, context fork, hooks) |
| **Hooks** | ~8 eventi (in crescita), solo command | 25+ eventi, 4 tipi handler (il vero differenziatore) |
| **MCP** | Tools + Resources + Prompts + Apps, sandbox | Tools + Resources, scoped al subagent |
| **Web access** | Parziale (provider-dependent) | Built-in (WebFetch, WebSearch) |
| **Ricerca semantica** | Built-in | No (Grep + ragionamento) |
| **Git worktree isolation** | No | Sì |
| **Permessi** | Workspace trust + tool whitelist | 6 permission modes per-agent |
| **Remote execution** | GitHub coding agent (PR) | Remote tasks, web VM, headless |
| **Costo modello** | Varia per provider (ottimizzabile) | Solo pricing Anthropic |
| **Lock-in** | Basso | Alto |

---

## 17. Quando scegliere cosa

### VS Code + GitHub Copilot è più adatto quando:

- **Multi-model è importante:** vuoi scegliere il modello migliore per ogni task o non vuoi dipendere da un solo vendor
- **Team eterogenei:** sviluppatori con preferenze diverse riescono a lavorare nello stesso repository
- **IDE-centric:** il workflow è centrato sull'editor e l'integrazione con l'ambiente di sviluppo locale è prioritaria
- **Ecosistema esteso:** serve integrazione con GitHub (PR, issues, Actions), MCP Apps, estensioni VS Code
- **Orchestrazione complessa:** servono subagent nested (fino a 5 livelli), pattern divide-and-conquer, multi-perspective review
- **Enterprise:** servono org policies, modelli custom, managed agents
- **Portabilità:** vuoi che le customizzazioni funzionino su VS Code, Copilot CLI, e coding agent

### Claude Code è più adatto quando:

- **Autonomia massima dell'agente:** il workflow richiede che l'AI operi autonomamente per periodi estesi (remote tasks, headless)
- **CLI-first:** lo sviluppatore preferisce il terminale all'editor grafico
- **Context engineering esplicito:** vuoi controllo diretto sul context budget e sulla compaction
- **Auto-learning:** l'auto-memory che "impara" dal progetto sessione dopo sessione ha valore significativo
- **Hook complessi:** servono 25+ eventi, handler LLM/agent, webhook HTTP
- **Isolamento filesystem:** il parallelismo richiede git worktree isolati per evitare conflitti
- **Mobile/remote:** serve controllare l'agente da mobile o da remoto
- **Team collaboration AI (futuro):** Agent Teams è l'approccio più ambizioso al parallelismo multi-agente, anche se sperimentale

### Considerazioni strategiche

- **Costo:** Copilot permette di ottimizzare i costi scegliendo modelli diversi per task diversi. Claude Code ha pricing fisso Anthropic.
- **Rischio vendor:** Copilot mitiga il rischio con multi-model. Claude Code è fully dependent da Anthropic.
- **Convergenza:** i due sistemi stanno convergendo sui formati (entrambi leggono `.claude/` e `.github/`, entrambi usano MCP, entrambi supportano `SKILL.md`). Tuttavia si tratta di **best-effort parsing**, non di interoperabilità completa: Claude Code importa `AGENTS.md` ma non interpreta il formato Copilot completo; VS Code legge `.claude/` ma ignora campi non compatibili.
- **Complementarità:** è possibile usare entrambi sullo stesso codebase — Claude Code come CLI per task autonomi lunghi, Copilot per il lavoro quotidiano nell'editor.

---

## Risorse

### VS Code + GitHub Copilot
- Customization overview: https://code.visualstudio.com/docs/copilot/customization/overview
- Custom Agents: https://code.visualstudio.com/docs/copilot/customization/custom-agents
- Subagents: https://code.visualstudio.com/docs/copilot/agents/subagents
- Skills: https://code.visualstudio.com/docs/copilot/customization/agent-skills
- Hooks: https://code.visualstudio.com/docs/copilot/customization/hooks
- MCP: https://code.visualstudio.com/docs/copilot/customization/mcp-servers
- Release notes: https://code.visualstudio.com/updates

### Claude Code
- Overview: https://code.claude.com/docs/en/overview
- Subagent: https://code.claude.com/docs/en/sub-agents
- Agent Teams: https://code.claude.com/docs/en/agent-teams
- Skills: https://code.claude.com/docs/en/skills
- Memory: https://code.claude.com/docs/en/memory
- Hooks: https://code.claude.com/docs/en/hooks
- Tools: https://code.claude.com/docs/en/tools-reference

### Standard
- Model Context Protocol: https://modelcontextprotocol.io/
- Agent Skills (proposta): https://agentskills.io/
