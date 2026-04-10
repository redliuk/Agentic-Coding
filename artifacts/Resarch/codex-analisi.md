# OpenAI Codex — Analisi completa

## 1. Cos'è

Codex è un **agentic coding tool** di OpenAI. Legge il codebase, modifica file, esegue comandi, crea PR e integra tool esterni via MCP. Disponibile come:

- **Codex app** (desktop: macOS nativo + Windows nativo dal marzo 2026) — interfaccia grafica dedicata con gestione thread paralleli, review pane e worktree
- **Codex CLI** (`@openai/codex` via npm) — esperienza terminale, open-source (Rust)
- **Estensione IDE** — VS Code, Cursor, Windsurf
- **Codex Cloud** (web, via chatgpt.com/codex) — task asincroni in container cloud isolati, delegabili da qualsiasi interfaccia
- **Integrazioni esterne** — GitHub (issue/PR @codex mention), Slack (@Codex), Linear, GitHub Action, Codex SDK (TypeScript)

A differenza di un chatbot, Codex opera come **agente autonomo**: esplora il codebase, pianifica, implementa, esegue test, committa e apre PR. Nella modalità cloud, i task sono **asincroni e parallelizzabili** — si assegnano e si rivedono dopo, come si farebbe con un collega.

**Modello:** Codex è alimentato da modelli della famiglia GPT ottimizzati per il coding agentico. Il modello di default è tipicamente il reasoning model più recente disponibile (GPT-5.4 al momento della stesura, come indicato nel changelog ufficiale), ma il mapping tra versioni Codex e numerazione GPT può cambiare senza preavviso — la documentazione non garantisce una corrispondenza stabile. Modelli mini disponibili per task meno intensivi (GPT-5.4 mini, GPT-5.3-Codex-Spark).

### Disponibilità (marzo 2026)

| Piano | Accesso |
|---|---|
| ChatGPT Free / Go | Accesso limitato (promozione temporanea) |
| ChatGPT Plus | Sì |
| ChatGPT Pro | Sì (+ Codex-Spark, rate limits più alti) |
| ChatGPT Business | Sì |
| ChatGPT Edu | Sì |
| ChatGPT Enterprise | Sì (+ admin controls, managed config) |
| API key | Sì (prezzi separati) |

---

## 2. Architettura

```
┌──────────────────────────────────────────────────────────────┐
│                    Codex Ecosystem                            │
│                                                               │
│  ┌─────────────────────┐   ┌────────────────────────────┐   │
│  │   Interfacce         │   │   Integrazioni              │   │
│  │                       │   │                              │   │
│  │  • Codex app (desktop)│   │  • GitHub (@codex su issues  │   │
│  │  • CLI (terminale)    │   │    e PR)                     │   │
│  │  • IDE extension      │   │  • Slack (@Codex)            │   │
│  │  • Codex Cloud (web)  │   │  • Linear                    │   │
│  │  • GitHub Mobile      │   │  • GitHub Action             │   │
│  └─────────┬─────────────┘   │  • Codex SDK (TypeScript)    │   │
│            │                  └────────────────────────────┘   │
│            ▼                                                   │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              Sessione Agente                              │ │
│  │                                                            │ │
│  │  Contesto:                                                 │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │  System prompt (built-in, reso pubblico da OpenAI)    │ │ │
│  │  │  AGENTS.md (gerarchia: globale → progetto → CWD)      │ │ │
│  │  │  config.toml (configurazione utente/progetto)         │ │ │
│  │  │  Rules (.rules — Starlark)                            │ │ │
│  │  │  Skill descriptions (progressive disclosure)          │ │ │
│  │  │  Conversazione + Tool outputs                         │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │                                                            │ │
│  │  Tools: Bash/shell, file read/edit/create, apply_patch,   │ │
│  │         web search (cached/live), MCP tools...             │ │
│  │                                                            │ │
│  │  Subagents: default, worker, explorer, + custom (.toml)   │ │
│  │  CSV batch processing (spawn_agents_on_csv)                │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  Sandbox OS-level                                         │ │
│  │  • macOS: Seatbelt (sandbox-exec)                         │ │
│  │  • Linux: bubblewrap + seccomp                            │ │
│  │  • Windows: native sandbox (dal marzo 2026) o WSL          │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  Codex Cloud (task asincroni)                             │ │
│  │  Container isolato con codebase, 2 fasi:                  │ │
│  │  1. Setup (con rete) → installa dipendenze                │ │
│  │  2. Agent (offline default, internet opt-in)               │ │
│  └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### Differenze tra modalità di esecuzione

| Aspetto | Locale (CLI / App / IDE) | Cloud (web) |
|---|---|---|
| **Esecuzione** | Sulla macchina dell'utente | Container cloud OpenAI |
| **Sandbox** | OS-level (Seatbelt, bubblewrap, Windows sandbox) | Container isolato |
| **Network** | Default off, configurabile | Setup: on, Agent: off (opt-in con domain allowlist) |
| **Interazione** | Interattiva (approval prompts) o `--full-auto` | Asincrona (assegna → rivedi) |
| **Parallelismo** | Thread multipli (app), singolo (CLI) | Task multipli in parallelo |
| **Worktree** | Sì (Codex app) | N/A (ogni task ha il suo ambiente) |
| **Output** | File locali, commit git | Diff, PR GitHub, patch |
| **Mid-turn steering** | Sì (dal febbraio 2026) | No (task non interrompibili — limitazione attuale) |

---

## 3. Sistema di istruzioni e memoria

### AGENTS.md — Istruzioni persistenti

`AGENTS.md` è il meccanismo principale per dare a Codex contesto e regole. Analogo a `CLAUDE.md` (Claude Code) e `copilot-instructions.md` (VS Code Copilot).

**Discovery (ordine di precedenza, al lancio):**

1. **Globale:** `~/.codex/AGENTS.override.md` (se esiste) → altrimenti `~/.codex/AGENTS.md`
2. **Progetto:** dal root del repo giù fino alla CWD corrente, per ogni directory: `AGENTS.override.md` → `AGENTS.md` → fallback names
3. **Merge:** concatenazione root → CWD, i file più vicini alla CWD sovrascrivono

| Posizione | Scope |
|---|---|
| `~/.codex/AGENTS.md` | Globale (tutti i progetti) |
| `~/.codex/AGENTS.override.md` | Override globale temporaneo |
| `./AGENTS.md` (repo root) | Progetto |
| `./sub/AGENTS.md` | Sub-directory (specializzazione) |
| `./sub/AGENTS.override.md` | Override locale (prevale su AGENTS.md nella stessa dir) |

**Configurazione avanzata:**

```toml
# ~/.codex/config.toml
project_doc_fallback_filenames = ["TEAM_GUIDE.md", ".agents.md"]
project_doc_max_bytes = 65536  # default: 32768 (32 KiB)
```

- **Fallback filenames:** permette di usare nomi alternativi (es. `TEAM_GUIDE.md`) trattati come instructions
- **Limite dimensione:** il totale combinato degli AGENTS.md è troncato a `project_doc_max_bytes`
- **AGENTS.override.md:** utile per override temporanei senza modificare il file condiviso

### Contenuto tipico di AGENTS.md

```markdown
# AGENTS.md

## Setup
- Run `npm install` first
- Use Node 20+

## Testing
- Run `npm test` after every change
- E2E tests: `npm run test:e2e`

## Code style
- TypeScript strict mode
- Named exports only
- Functional components React
```

### Auto-memory

**Codex non dispone di una memoria autonoma modificabile dal modello** come Claude Code (che ha una memory directory mutata dal modello sessione dopo sessione). La persistenza del contesto è affidata a:

- `AGENTS.md` (scritto dall'utente)
- `config.toml` (configurazione esplicita)
- Hooks `SessionStart` (per iniettare contesto personalizzato)
- History/transcript persistenti (configurabili via `history.persistence` e `history.max_bytes`) — offrono una forma limitata di continuità cross-sessione
- `codex resume` (riprende la sessione precedente con il contesto accumulato)

> Codex non "impara" autonomamente dal progetto, ma la combinazione di transcript persistenti e resume permette una certa continuità operativa tra sessioni. Tuttavia, l'utente resta responsabile di codificare le convenzioni durature in `AGENTS.md`.

---

## 4. Configurazione — `config.toml`

La configurazione centrale di Codex è un file TOML con una gerarchia di precedenza:

| Priorità | Posizione | Scope |
|---|---|---|
| 1 (alta) | CLI flags (`--model`, `--sandbox`, ecc.) | Sessione corrente |
| 2 | `.codex/config.toml` (progetto) | Progetto (trusted) |
| 3 | `~/.codex/config.toml` | Utente |
| 4 | `/etc/codex/config.toml` | Sistema/admin |
| 5 (bassa) | Default built-in | — |

### Campi principali

```toml
# Modello e reasoning
model = "gpt-5.4"
model_reasoning_effort = "medium"  # low, medium, high, xhigh

# Sandbox e approvazioni
sandbox_mode = "workspace-write"     # read-only, workspace-write, danger-full-access
approval_policy = "on-request"       # untrusted, on-request, never

# Network e web search
web_search = "cached"                # cached, live, disabled
[sandbox_workspace_write]
network_access = false

# MCP servers
[mcp_servers.context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp"]

# Subagents
[agents]
max_threads = 6
max_depth = 1

# Profili salvati
[profiles.full_auto]
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[profiles.readonly_quiet]
approval_policy = "never"
sandbox_mode = "read-only"

# Features sperimentali
[features]
codex_hooks = true

# History
[history]
persistence = true
max_bytes = 10485760

# AGENTS.md discovery
project_doc_fallback_filenames = ["TEAM_GUIDE.md"]
project_doc_max_bytes = 32768

# Telemetria (opt-in)
[otel]
exporter = "none"
log_user_prompt = false
```

### Team Config

Le configurazioni condivise si distribuiscono via `.codex/` nel repo:
- `.codex/config.toml` — default di progetto
- `.codex/rules/` — regole di esecuzione comandi
- `.codex/skills/` — skill condivise
- `.codex/agents/` — custom agent condivisi
- `.codex/hooks.json` — hook condivisi

Gli admin possono forzare vincoli con `requirements.toml`, che sovrascrive qualsiasi configurazione locale.

---

## 5. Subagents — Worker specializzati

Codex supporta **subagent workflow**: spawning di agenti specializzati in parallelo, con raccolta consolidata dei risultati.

### Agenti built-in

| Nome | Scopo | Tool |
|---|---|---|
| `default` | Fallback general-purpose | Tutti |
| `worker` | Implementazione e fix | Tutti (write) |
| `explorer` | Esplorazione codebase read-heavy | Read-only |

### Custom agents — formato `.toml`

File standalone in `~/.codex/agents/` (utente) o `.codex/agents/` (progetto).

```toml
# .codex/agents/reviewer.toml
name = "reviewer"
description = "PR reviewer focused on correctness, security, and missing tests."
model = "gpt-5.4"
model_reasoning_effort = "high"
sandbox_mode = "read-only"
developer_instructions = """
Review code like an owner.
Prioritize correctness, security, behavior regressions, and missing test coverage.
Lead with concrete findings, include reproduction steps when possible.
"""
nickname_candidates = ["Atlas", "Delta", "Echo"]
```

### Schema custom agent

| Campo | Obbligatorio | Default | Funzione |
|---|---|---|---|
| `name` | Sì | — | Identificativo (match esatto per spawning) |
| `description` | Sì | — | Guida Codex su quando usare l'agente |
| `developer_instructions` | Sì | — | Istruzioni operative (equivalente del body in Copilot/Claude) |
| `nickname_candidates` | No | — | Pool di nomi display per istanze multiple |
| `model` | No | ereditato | Override modello |
| `model_reasoning_effort` | No | ereditato | `low`, `medium`, `high`, `xhigh` |
| `sandbox_mode` | No | ereditato | `read-only`, `workspace-write`, ecc. |
| `mcp_servers` | No | ereditato | Server MCP scoped all'agente |
| `skills.config` | No | ereditato | Skill abilitate/disabilitate per l'agente |

### Configurazione globale subagent

```toml
# config.toml
[agents]
max_threads = 6       # thread concorrenti massimi
max_depth = 1         # profondità nesting (0 = root, 1 = figlio diretto)
job_max_runtime_seconds = 1800  # timeout per worker CSV
```

- **`max_depth` default 1** (documentato): un agente figlio può operare, ma non può spawnare ulteriori figli. La documentazione consiglia di mantenere il default salvo necessità specifiche
- **Nesting > 1:** configurabile ma sconsigliato dalla documentazione (rischio fan-out esponenziale, costi token elevati, latenza). Il valore di default potrebbe evolvere
- **`max_threads`:** limita quanti agenti possono essere attivi contemporaneamente

### Differenze chiave con Copilot e Claude Code

| Aspetto | Codex | VS Code + Copilot | Claude Code |
|---|---|---|---|
| **Formato agente** | TOML (standalone) | Markdown + YAML frontmatter | Markdown + YAML frontmatter |
| **Tool sandboxing per agente** | `sandbox_mode` nel TOML | `tools:` whitelist | `tools` allowlist + `disallowedTools` |
| **Nesting** | Configurabile (`max_depth`) | Fino a 5 livelli (opt-in) | No (design policy) |
| **Parallelismo** | Nativo (thread paralleli) | Fan-out/fan-in via tool agent | Background subagent + Agent Teams (sperimentale) |
| **CSV batch** | `spawn_agents_on_csv` (sperimentale) | No | `/batch` (worktree isolati) |
| **Model per agente** | Sì | Sì (multi-provider) | Sì (solo Claude) |
| **Comunicazione tra agenti** | No (solo report al parent) | No (solo report al parent) | Agent Teams (sperimentale: mailbox diretta) |

### Esempio workflow multi-agente

```
Prompt: "Review this branch against main. Have pr_explorer map the affected
code paths, reviewer find real risks, and docs_researcher verify the APIs."

Codex → spawna 3 agenti in parallelo:
├── pr_explorer (gpt-5.3-codex-spark, read-only) → mappa il codice
├── reviewer (gpt-5.4, read-only, high reasoning) → trova rischi
└── docs_researcher (gpt-5.4-mini, con MCP docs) → verifica API

Codex ← raccoglie tutti i risultati → risposta consolidata
```

### CSV batch processing (sperimentale)

```
Prompt: "Create /tmp/components.csv with columns path,owner.
Then spawn_agents_on_csv to review each component."

Codex → legge CSV → spawna 1 worker per riga
├── worker 1 → review componente A
├── worker 2 → review componente B
└── worker N → review componente N
→ output: /tmp/components-review.csv con risultati strutturati
```

---

## 6. Skills — Workflow riutilizzabili

Le Skill in Codex sono cartelle con un `SKILL.md` obbligatorio, compatibili con la specifica SKILL.md promossa dalla community (`agentskills.io`). Non si tratta di uno standard formalmente ratificato con governance e interoperabilità verificata tra vendor — è una proposta di convergenza.

### Struttura

```
my-skill/
  SKILL.md                  # Obbligatorio: istruzioni + metadata
  scripts/                  # Opzionale: codice eseguibile
  references/               # Opzionale: documentazione
  assets/                   # Opzionale: template, risorse
  agents/
    openai.yaml             # Opzionale: metadata UI, policy, dipendenze
```

### Formato `SKILL.md`

```yaml
---
name: skill-name
description: Explain exactly when this skill should and should not trigger.
---

Skill instructions for Codex to follow.
```

Il frontmatter è minimale: solo `name` e `description`. I campi avanzati (policy, UI, dipendenze) sono in `agents/openai.yaml`:

```yaml
interface:
  display_name: "Optional user-facing name"
  short_description: "Optional user-facing description"
  icon_small: "./assets/small-logo.svg"
  brand_color: "#3B82F6"
  default_prompt: "Optional surrounding prompt"

policy:
  allow_implicit_invocation: false

dependencies:
  tools:
    - type: "mcp"
      value: "openaiDeveloperDocs"
      transport: "streamable_http"
      url: "https://developers.openai.com/mcp"
```

### Caricamento — progressive disclosure

1. **Discovery:** Codex legge `name`, `description`, file path e metadata da tutti i `SKILL.md`
2. **Full load:** solo quando Codex decide di usare la skill, carica il body completo

### Posizioni

| Scope | Percorso |
|---|---|
| **CWD** | `$CWD/.agents/skills/` |
| **Parent dirs** | `$CWD/../.agents/skills/` (fino alla repo root) |
| **Repo root** | `$REPO_ROOT/.agents/skills/` |
| **Utente** | `$HOME/.agents/skills/` |
| **Admin** | `/etc/codex/skills/` |
| **Sistema** | Bundled da OpenAI (`$skill-creator`, `$skill-installer`, ecc.) |

> **Nota:** Codex usa `.agents/skills/` (non `.codex/skills/`). Supporta anche symlink.

### Invocazione

- **Esplicita:** `$skill-name` nel prompt, `/skills` o `$` per menu
- **Implicita:** Codex sceglie automaticamente in base alla `description`
- **Policy:** `allow_implicit_invocation: false` in `openai.yaml` per disabilitare l'auto-attivazione

### Skill built-in

- `$skill-creator` — scaffolding nuove skill
- `$skill-installer` — installazione skill curate da https://github.com/openai/skills
- `$create-plan` — (sperimentale, da installare)

### Gestione

```toml
# Disabilitare una skill senza cancellarla
[[skills.config]]
path = "/path/to/skill/SKILL.md"
enabled = false
```

### Distribuzione — Plugins

Per distribuire skill oltre il singolo repo, si usano i **plugin** (dal marzo 2026):

```
my-plugin/
  .codex-plugin/
    plugin.json   # Manifest obbligatorio
  skills/         # Skill pacchettizzate
  .app.json       # Connettori/mappature app
  .mcp.json       # Configurazione MCP server
  assets/         # Icone, screenshot
```

Installabili via marketplace (`~/.agents/plugins/marketplace.json` utente, `.agents/plugins/marketplace.json` progetto).

---

## 7. Rules — Controllo comandi deterministico

Le Rules sono un sistema Codex-specifico (senza equivalente diretto in Copilot o Claude Code) per controllare deterministicamente quali comandi shell possono essere eseguiti fuori dalla sandbox.

### Formato

File `.rules` in sintassi **Starlark** (simile a Python, safe da eseguire):

```python
# ~/.codex/rules/default.rules o .codex/rules/default.rules

prefix_rule(
    pattern = ["gh", "pr", "view"],
    decision = "prompt",       # allow | prompt | forbidden
    justification = "Viewing PRs is allowed with approval",
    match = [
        "gh pr view 7888",
        "gh pr view --repo openai/codex",
    ],
    not_match = [
        "gh pr --repo openai/codex view 7888",
    ],
)
```

### Campi

| Campo | Obbligatorio | Funzione |
|---|---|---|
| `pattern` | Sì | Lista di prefix da matchare (supporta union di letterali) |
| `decision` | No (default: `allow`) | `allow`, `prompt` (chiedi), `forbidden` (blocca) |
| `justification` | No | Motivazione human-readable |
| `match` / `not_match` | No | Test inline per validazione |

### Priorità decisionale

Quando più rule matchano: `forbidden` > `prompt` > `allow` (vince la più restrittiva).

### Smart approvals

Quando abilitate (default), Codex può proporre una `prefix_rule` durante le richieste di approvazione. L'utente rivede e accetta/rifiuta la regola suggerita.

### Parsing comandi composti

Codex analizza comandi shell come `bash -lc "git add . && rm -rf /"`:
- Se il script è lineare (solo comandi plain con `&&`, `||`, `;`, `|`): lo **split** e valuta ogni comando separatamente
- Se usa feature avanzate (redirect, variabili, control flow): tratta tutto come `["bash", "-lc", "<script>"]`

Questo impedisce di nascondere comandi pericolosi dentro comandi safe.

### Testing

```bash
codex execpolicy check --pretty \
  --rules ~/.codex/rules/default.rules \
  -- gh pr view 7888 --json title,body,comments
```

---

## 8. Hooks — Automazione lifecycle

**Stato: sperimentale.** Richiede feature flag. Disabilitati su Windows.

```toml
[features]
codex_hooks = true
```

### Eventi supportati

| Evento | Matcher su | Può bloccare? | Quando |
|---|---|---|---|
| `SessionStart` | `source` (`startup`, `resume`) | Sì (`continue: false`) | Sessione avviata |
| `UserPromptSubmit` | — (matcher ignorato) | Sì (`decision: "block"`) | Utente invia prompt |
| `PreToolUse` | `tool_name` (attualmente solo `Bash`) | Sì (exit 2 o `permissionDecision: deny`) | Prima di un tool |
| `PostToolUse` | `tool_name` (attualmente solo `Bash`) | Parziale (`decision: block` = feedback) | Dopo un tool |
| `Stop` | — (matcher ignorato) | Sì (`decision: block` = continua) | Turno concluso |

### Configurazione

```json
// .codex/hooks.json o ~/.codex/hooks.json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 .codex/hooks/validate_bash.py",
            "timeout": 15,
            "statusMessage": "Validating command"
          }
        ]
      }
    ]
  }
}
```

### Tipo di handler

**Solo `command`** (shell). Codex non supporta handler `http`, `prompt` o `agent` — a differenza di Claude Code che ne supporta 4 tipi.

### Input/Output

Ogni hook riceve **JSON via stdin**:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/session.jsonl",
  "cwd": "/project",
  "hook_event_name": "PreToolUse",
  "model": "gpt-5.4",
  "tool_name": "Bash",
  "tool_input": { "command": "npm test" }
}
```

**Exit codes:** `0` = successo (stdout JSON), `2` = errore bloccante (stderr = reason), altro = warning.

### Confronto hooks con Copilot e Claude Code

| Aspetto | Codex | VS Code + Copilot | Claude Code |
|---|---|---|---|
| **Numero eventi** | 5 | ~8 | 25+ |
| **Maturità** | Sperimentale (feature flag) | GA (Preview per agent-scoped) | GA |
| **Tipi handler** | Solo `command` | Solo `command` | 4: `command`, `http`, `prompt`, `agent` |
| **Matcher** | Regex, ma solo Bash emette eventi | — | Regex su tool name |
| **Windows** | Disabilitato | Sì (`windows:` override) | Sì (`shell: powershell`) |
| **Posizione config** | `hooks.json` (standalone) | `.github/hooks/*.json` | `.claude/settings.json` |

> **Limite significativo:** `PreToolUse` e `PostToolUse` attualmente emettono eventi **solo per Bash**. Edit, Write e altri tool non triggerano hook. Questo limita molto l'enforcement rispetto a Claude Code.

---

## 9. MCP (Model Context Protocol)

Codex supporta MCP per connettere tool e servizi esterni. Condivide la configurazione tra CLI e IDE extension.

### Tipi di server supportati

| Tipo | Descrizione |
|---|---|
| **STDIO** | Processo locale (command + args) |
| **Streamable HTTP** | Server remoto (URL + auth) |

### Configurazione

```toml
# ~/.codex/config.toml o .codex/config.toml

# STDIO
[mcp_servers.context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp"]
[mcp_servers.context7.env]
MY_VAR = "value"

# Streamable HTTP
[mcp_servers.figma]
url = "https://mcp.figma.com/mcp"
bearer_token_env_var = "FIGMA_OAUTH_TOKEN"
http_headers = { "X-Figma-Region" = "us-east-1" }

# Opzioni avanzate
[mcp_servers.chrome_devtools]
url = "http://localhost:3000/mcp"
startup_timeout_sec = 20
tool_timeout_sec = 45
enabled = true
required = false
enabled_tools = ["open", "screenshot"]
disabled_tools = ["screenshot"]
```

### CLI per gestione

```bash
codex mcp add context7 -- npx -y @upstash/context7-mcp
codex mcp add myserver --env API_KEY=secret -- node server.js
codex mcp login <server-name>   # OAuth per server che lo supportano
codex mcp --help                # tutti i comandi
```

### MCP scoped ai subagent

Server MCP dichiarati nel file `.toml` del custom agent sono disponibili solo a quell'agente:

```toml
# .codex/agents/docs-researcher.toml
name = "docs_researcher"
developer_instructions = "Use docs MCP to verify APIs."

[mcp_servers.openaiDeveloperDocs]
url = "https://developers.openai.com/mcp"
```

### Confronto MCP con Copilot e Claude Code

| Aspetto | Codex | VS Code + Copilot | Claude Code |
|---|---|---|---|
| **Configurazione** | `config.toml` (TOML) | `.vscode/mcp.json` (JSON), inline in agent | `claude mcp add`, inline in agent |
| **Tipi** | STDIO, Streamable HTTP | STDIO, HTTP | STDIO, HTTP |
| **Capabilities** | Principalmente Tools (il protocollo MCP supporta anche Resources e Prompts, ma Codex attualmente li espone in misura limitata) | Tools, Resources, Prompts, MCP Apps | Tools, Resources |
| **MCP Apps (UI)** | No | Sì | No |
| **Sandboxing server** | No nativo | Sì (filesystem + network, macOS/Linux) | No nativo |
| **Scoped ad agente** | Sì (nel TOML del custom agent) | Sì (inline nel frontmatter) | Sì (inline nel frontmatter) |
| **Tool allow/deny list** | Sì (`enabled_tools`, `disabled_tools`) | No (sandboxing via `tools:` dell'agente) | No nativo |
| **OAuth** | Sì (`codex mcp login`) | No | No |

---

## 10. Sicurezza e permessi

### Modello a due livelli

1. **Sandbox mode** — cosa Codex può fare tecnicamente
2. **Approval policy** — quando Codex deve chiedere prima di agire

### Sandbox modes

| Modalità | Lettura | Scrittura | Comandi | Network |
|---|---|---|---|---|
| `read-only` | Workspace | — | — | — |
| `workspace-write` (default) | Workspace | Workspace | Workspace | Off (configurabile) |
| `danger-full-access` | Tutto | Tutto | Tutto | Tutto |

### Approval policies

| Policy | Comportamento |
|---|---|
| `untrusted` | Chiede approvazione per tutto |
| `on-request` (default con `--full-auto`) | Chiede solo per azioni extra-workspace o network |
| `never` | Non chiede mai (rispetta comunque la sandbox) |
| Granular | Configurazione fine: `sandbox_approval`, `rules`, `mcp_elicitations`, `request_permissions`, `skill_approval` |

### Presets di uso comune

| Preset | Comando | Comportamento |
|---|---|---|
| **Auto** | `--full-auto` | Read/write/execute in workspace, ask per extra |
| **Safe read-only** | `--sandbox read-only --ask-for-approval on-request` | Solo lettura, ask per edit |
| **CI non-interactive** | `--sandbox read-only --ask-for-approval never` | Solo lettura, nessuna domanda |
| **Full access** | `--yolo` / `--dangerously-bypass-approvals-and-sandbox` | Tutto permesso (⚠️) |

### Protected paths

Nella sandbox `workspace-write`, sono protetti in sola lettura:
- `<workspace>/.git` (directory o pointer file)
- `<workspace>/.agents`
- `<workspace>/.codex`

### OS-level sandbox

| OS | Meccanismo |
|---|---|
| macOS | **Seatbelt** (sandbox-exec con profilo) |
| Linux | **bubblewrap** + **seccomp** (default), landlock legacy disponibile |
| Windows nativo | **Windows sandbox** (unelevated/elevated, private desktop) — supporto più recente, alcune feature (hooks) ancora disabilitate |
| Windows WSL | Sandbox Linux via WSL — opzione più matura su Windows |

### Confronto sicurezza

| Aspetto | Codex | VS Code + Copilot | Claude Code |
|---|---|---|---|
| **Sandbox OS-level** | Sì (Seatbelt, bubblewrap, Windows) | No (delega a VS Code trust) | No (tranne worktree) |
| **Rules (command policy)** | Sì (Starlark `.rules`) | No | No |
| **Tool sandboxing** | `sandbox_mode` per agente | `tools:` whitelist per agente | `tools`/`disallowedTools` per agente |
| **Approval granulare** | Sì (per-categoria) | Workspace trust | 6 permission modes |
| **Protected paths** | Sì (.git, .agents, .codex) | No | No |
| **Telemetria audit** | OTel opt-in | No | No |
| **Enterprise managed** | `requirements.toml` | Org policies | Managed settings |

> **Codex è attualmente l'unico dei tre sistemi ad esporre un sandbox OS-level locale configurabile** (Seatbelt, bubblewrap, Windows sandbox). Copilot e Claude Code non documentano meccanismi equivalenti per l'esecuzione locale, ma il livello di isolamento effettivo dipende dalla piattaforma, dalla configurazione e dalla versione — il confronto di hardening non è verificabile con certezza.

---

## 11. Tools built-in

Codex espone un set di tool più essenziale rispetto a Claude Code e Copilot. Nella CLI, il modello opera primariamente tramite shell commands; nelle interfacce IDE e app desktop, Codex può usare anche API dirette per file e git:

| Tool/Capability | Meccanismo | Note |
|---|---|---|
| **File read** | Bash (`cat`, `head`, ecc.) o tool interno | Via shell |
| **File edit** | `apply_patch` (diff-based) | Formato patch strutturato |
| **File create/write** | Bash o tool interno | — |
| **Shell** | Bash (macOS/Linux), PowerShell (Windows) | Principale mezzo d'azione |
| **Web search** | Tool built-in (cached/live) | `web_search` in config |
| **Subagent** | Spawning parallelo | Thread-based |
| **MCP tools** | Via server configurati | — |
| **Git** | Bash (git CLI) | Commit, branch, diff |
| **Context compaction** | Automatico | Riassume il contesto quando si avvicina al limite |
| **Resume** | `codex resume` | Riprende sessioni precedenti |
| **Image input** | Sì (allegati prompt) | Aggiunto agosto 2025 |
| **Image output** | Solo cloud (screenshot UI) | Per task frontend |

### Differenze significative con Copilot e Claude Code

1. **Nessuna ricerca semantica nativa:** Codex usa `grep`, `find`, `rg` via shell. Copilot ha `semantic_search`, Claude usa `Grep` + ragionamento.
2. **Nessun LSP/code intelligence:** Codex non ha accesso diretto a jump-to-definition, find-references, type checking. Copilot li ha nativamente dall'editor.
3. **Web search integrata:** Codex ha web search built-in (cached o live), come Claude Code (`WebFetch`, `WebSearch`). Copilot ha capacità web limitate e provider-dependent.
4. **Apply_patch:** Codex usa un formato patch strutturato per gli edit, diverso dall'edit tool di Claude Code o Copilot.
5. **Nessun tool Plan Mode esplicito:** Codex entra in plan mode con `/permissions` per read-only, non ha un tool dedicato come Claude.

---

## 12. Workflow e modalità operative

### Interfacce e workflow tipici

**Codex App (desktop):**
1. Apri progetto nella sidebar
2. Crea thread multipli (paralleli!) per task diversi
3. L'agente lavora con approval prompts (o full-auto)
4. Review nel pane integrato (diff, terminal output)
5. Handoff tra locale ↔ cloud ↔ worktree
6. Push PR direttamente dall'app

**Codex CLI:**
1. `codex` nella directory del progetto
2. Prompt interattivo o `codex exec "task"` (non-interattivo)
3. `/model` per cambiare modello, `/permissions` per sandbox
4. `codex resume` per riprendere sessione
5. `--full-auto` per autonomia massima

**Codex Cloud:**
1. Vai su chatgpt.com/codex
2. Connetti repo GitHub
3. Assegna task (multipli in parallelo)
4. L'agente lavora in container cloud isolato
5. Rivedi diff, richiedi revisioni, oppure apri PR

**IDE Extension:**
1. Installa estensione (VS Code, Cursor, Windsurf)
2. Apri panel Codex nella sidebar
3. Agent mode: legge file, esegue comandi, scrive codice
4. Puoi delegare task al cloud dall'IDE

### Automations (Codex App)

Dal marzo 2026, la Codex app supporta **automazioni**: task che girano in background, localmente o su worktree, con modello e reasoning personalizzabili per automation. Template disponibili per ispirazione.

### Pattern di orchestrazione

- **Multi-perspective review:** spawna N agenti con focus diversi (security, correctness, test coverage)
- **Explorer → Worker:** prima mappa il codebase con un explorer read-only, poi delega all'implementer
- **CSV batch:** audit sistematico: 1 worker per componente/file/servizio
- **Cloud delegation:** invia task pesanti al cloud, continua a lavorare localmente

### Mid-turn steering

Dal febbraio 2026: puoi **inviare messaggi mentre Codex sta lavorando** per correggere la direzione senza interrompere e ricominciare. Disponibile nelle interfacce con streaming interattivo (Codex app desktop, IDE extension), non nella CLI in modalità batch (`codex exec`) né nei task Codex Cloud.

---

## 13. Codex Cloud — Dettagli architettura

### Runtime a due fasi

1. **Setup phase** (con rete):
   - Clona il repository
   - Esegue setup script personalizzabile
   - Installa dipendenze (auto-detect: npm, pnpm, pip, cargo, go mod, ecc.)
   - Secrets disponibili solo in questa fase
   - Durata max: 20 minuti (Pro/Business), 10 min (altri)

2. **Agent phase** (offline default):
   - L'agente lavora sul codebase
   - Internet disabilitato (opt-in con domain allowlist)
   - Secrets rimossi prima dell'avvio
   - Task completati tipicamente in 1-30 minuti

### Internet access (opt-in)

Configurabile per ambiente con allowlist di domini e metodi HTTP. Abilitabile per Plus, Pro, Business (Enterprise coming soon).

### Output

- **Diff** visualizzabile nell'interfaccia
- **PR GitHub** con un click
- **Citations** (riferimenti a file e terminal output verificabili)
- **Best of N:** generazione di multiple risposte per lo stesso task, per scegliere il miglior approccio

### Integrazioni

| Integrazione | Come funziona |
|---|---|
| **GitHub** | `@codex` su issue/PR → Codex lavora e risponde con link al task |
| **Slack** | `@Codex` in un canale → assegna domande o task |
| **Linear** | Assegna/menziona @Codex in issue → aggiornamenti in Linear |
| **GitHub Action** | Codex in CI/CD pipeline |
| **Codex SDK** | Integra l'agente in workflow custom TypeScript |

### Codex SDK (TypeScript)

```typescript
import { Codex } from "@openai/codex-sdk";

const agent = new Codex();
const thread = await agent.startThread();

const result = await thread.run("Explore this repo");
console.log(result);

const result2 = await thread.run("Propose changes");
console.log(result2);
```

---

## 14. Modelli AI e flessibilità

| Aspetto | Dettaglio |
|---|---|
| **Provider** | Solo OpenAI |
| **Famiglia modelli** | GPT-Codex (ottimizzati per coding agentico) |
| **Modello default (marzo 2026)** | GPT-5.4 (secondo changelog; può cambiare) |
| **Modelli disponibili** | GPT-5.4, GPT-5.4 mini, GPT-5.3-Codex, GPT-5.3-Codex-Spark, GPT-5.2-Codex, GPT-5.1-Codex-Max |
| **Reasoning effort** | `low`, `medium` (default), `high`, `xhigh` |
| **Context window** | Fino a 1M token (sperimentale con GPT-5.4), 192k standard |
| **Scelta per agente** | Sì (`model` nel TOML del custom agent) |
| **Modelli locali** | No |
| **Lock-in** | Alto (solo modelli OpenAI) |

### Progressione modelli (dal changelog ufficiale)

La numerazione dei modelli è documentata nel changelog pubblico di Codex. Non costituisce un contratto stabile — OpenAI può rinominare, sostituire o ritirare modelli senza preavviso.

```
codex-1 (maggio 2025, basato su o3)
  → GPT-5-Codex (settembre 2025)
    → GPT-5.1-Codex / GPT-5.1-Codex-Max (novembre 2025)
      → GPT-5.2-Codex (dicembre 2025)
        → GPT-5.3-Codex / GPT-5.3-Codex-Spark (febbraio 2026)
          → GPT-5.4 / GPT-5.4 mini (marzo 2026, attuale)
```

Ogni versione ottimizzata per:
- Agentic coding (long-horizon task)
- Context compaction (sessioni lunghe)
- Style alignment (patch pulite, stile PR umano)
- Tool use efficiente
- Computer use (GPT-5.4: sperimentale)

---

## 15. Deployment e piattaforme

| Aspetto | Dettaglio |
|---|---|
| **Desktop** | Codex app (macOS nativo, Windows nativo dal marzo 2026) |
| **IDE** | VS Code, Cursor, Windsurf (via estensione) |
| **CLI** | `@openai/codex` (npm, CLI open-source in Rust; runtime modello e integrazioni cloud proprietari) |
| **Web** | chatgpt.com/codex (Codex Cloud) |
| **Mobile** | ChatGPT iOS (assegna task, vedi diff, push PR) |
| **Integrazioni** | GitHub, Slack, Linear, GitHub Action, SDK |
| **OS** | macOS, Linux, Windows (nativo + WSL) |
| **CI/CD** | GitHub Action + `codex exec` (non-interactive) |
| **Remote** | Codex Cloud (container isolati OpenAI) |
| **Open source** | CLI Rust (repo: github.com/openai/codex; runtime modello e servizi cloud proprietari) |

---

## 16. Limiti pratici

| Limite | Impatto |
|---|---|
| **Solo modelli OpenAI** | Nessuna possibilità di usare Claude, Gemini o modelli locali |
| **No auto-memory** | L'utente deve mantenere AGENTS.md manualmente |
| **Hooks sperimentali** | Solo 5 eventi, solo handler command, solo Bash trigger, no Windows |
| **Rules solo per comandi shell** | Non coprono edit file o altri tool |
| **Cloud: no mid-task steering** | Non puoi correggere un task cloud mentre lavora |
| **Cloud: internet off default** | Setup script deve installare tutto prima della fase agent |
| **Cloud: no comunicazione tra task** | I task cloud sono completamente isolati tra loro |
| **PreToolUse solo Bash** | File edit e write non triggerano hook — enforcement incompleto |
| **Nessun LSP/code intelligence** | Dipende dal modello per capire la struttura del codice |
| **Plugins appena lanciati** | Ecosistema nascente (marzo 2026), meno maturo di marketplace Copilot |
| **Costo token subagent** | Ogni subagent genera chiamate API separate |
| **Context window** | Compaction automatica per sessioni lunghe → possibile perdita di info |
| **Nessuna ricerca semantica** | Si affida a grep/find/rg via shell |

---

## 17. Confronto rapido con Copilot e Claude Code

Questa sezione sintetizza le differenze principali. Per il confronto dettagliato su ogni sotto-sistema, vedi le tabelle nelle sezioni precedenti e il file `confronto-copilot-vs-claude-code.md`.

| Dimensione | Codex | VS Code + Copilot | Claude Code |
|---|---|---|---|
| **Vendor** | OpenAI | Microsoft/GitHub (multi-provider) | Anthropic |
| **Filosofia** | Agent-first (CLI + app + cloud) | IDE-first, modulare | Agent-runtime-first (CLI + IDE + web) |
| **Modelli** | Solo GPT-Codex | Multi-provider (GPT, Claude, Gemini) | Solo Claude |
| **App dedicata** | Sì (desktop macOS + Windows) | No (vive in VS Code) | Desktop + web app |
| **Cloud async** | Sì (Codex Cloud, parallelo) | GitHub coding agent (PR-focused) | Remote tasks |
| **Instructions** | `AGENTS.md` + `config.toml` | `copilot-instructions.md` + `.instructions.md` | `CLAUDE.md` + `.claude/rules/` |
| **Auto-memory** | No | No | Sì (memory directory) |
| **Formato agente** | TOML standalone | Markdown + YAML frontmatter | Markdown + YAML frontmatter |
| **Skills** | `SKILL.md` (agentskills.io) | `SKILL.md` (formato proprio) | `SKILL.md` (con preprocessing) |
| **Rules** | Starlark `.rules` (sperimentale) | No equivalente | No equivalente |
| **Hooks** | 5 eventi, solo command (sperimentale) | ~8 eventi, solo command | 25+ eventi, 4 tipi handler |
| **Sandbox OS-level** | Sì (il più maturo) | No | No (tranne worktree) |
| **MCP** | TOML config, STDIO + HTTP | JSON, STDIO + HTTP, + Apps + sandbox | CLI + inline, STDIO + HTTP |
| **Subagent nesting** | Configurabile (`max_depth`) | Fino a 5 livelli (opt-in) | No (design policy) |
| **SDK** | Sì (TypeScript) | No | Sì (Agent SDK) |
| **Integrazioni** | GitHub, Slack, Linear, Action | GitHub (coding agent, PR) | Remote tasks |
| **Open source** | CLI (Rust, open source; runtime modello e servizi cloud proprietari) | No | No |
| **Lock-in modello** | Alto | Basso | Alto |

---

## 18. Quando usare Codex

### Codex è più adatto quando:

- **Task asincroni e paralleli:** vuoi assegnare più task e rivederli dopo (Codex Cloud)
- **CI/CD e automazione:** GitHub Action + `codex exec` + SDK per pipeline
- **Integrazioni team:** Slack, Linear e GitHub come entry point per il team
- **Security-first:** il sandbox OS-level ti dà garanzie più forti
- **Desktop dedicato:** la Codex app offre thread multipli, worktree, review pane
- **Modelli GPT ottimizzati:** se il tuo uso è coding-heavy e vuoi modelli specificamente ottimizzati per agentic coding
- **Batch processing:** audit sistematici via CSV batch con subagent paralleli
- **Open source CLI:** vuoi ispezionare, estendere o contribuire al tool

### Limiti rispetto agli altri:

- **No multi-model:** non puoi usare Claude o Gemini
- **No auto-memory:** non impara cross-sessione
- **Hook immaturi:** enforcement limitato rispetto a Claude Code
- **Meno IDE-integrato di Copilot:** non ha accesso a LSP, semantic search, diagnostics dell'editor

---

## 19. Come integrarlo nel tuo workflow

### Scenario: complementarità con Copilot

Codex e Copilot in VS Code possono coesistere sullo stesso progetto:

| Tipo di lavoro | Tool |
|---|---|
| Editing quotidiano, completamento, chat veloce | VS Code + Copilot (Agent Mode) |
| Task autonomi, refactoring su larga scala | Codex app o CLI |
| Task background paralleli | Codex Cloud |
| Review PR automatizzata | Codex (GitHub integration) |
| Orchestrazione con subagent custom | Codex (TOML agents) o Copilot (.agent.md) |

### Setup raccomandato per un progetto

1. **AGENTS.md alla root** — regole coding, testing, conventions (letto da Codex e da Copilot con `chat.useAgentsMdFile: true`)
2. **`.codex/config.toml`** — configurazione sandbox, MCP, subagent
3. **`.codex/agents/`** — custom agent per task ricorrenti (reviewer, tester, ecc.)
4. **`.agents/skills/`** — skill condivise (formato agentskills.io, portabile)
5. **`.codex/rules/`** — policy comandi shell
6. **`.codex/hooks.json`** — automazione lifecycle (se necessaria)

### AGENTS.md cross-tool

`AGENTS.md` è il formato con il supporto più ampio cross-tool (Codex, Copilot, GitHub coding agent). Per massima portabilità, usare `AGENTS.md` come file primario e mantenere formati tool-specifici solo dove necessario. Vedi https://agents.md/ per lo standard emergente.

---

## 20. Nota metodologica

Questa analisi è basata sulla documentazione ufficiale disponibile a marzo 2026 (developers.openai.com/codex).

| Indicatore | Significato |
|---|---|
| _(nessuna nota)_ | Documentazione ufficiale pubblica e stabile |
| _"sperimentale"_ | Feature flag, preview, o funzionalità non GA |
| _(non documentato)_ | Comportamento inferito da changelog o uso |

Codex evolve a ritmo molto rapido (release settimanali CLI, bi-settimanali app). Verificare sempre il changelog ufficiale per lo stato corrente.

---

## 21. Risorse

### Documentazione ufficiale
- **Overview:** https://developers.openai.com/codex
- **Quickstart:** https://developers.openai.com/codex/quickstart
- **AGENTS.md:** https://developers.openai.com/codex/guides/agents-md
- **Skills:** https://developers.openai.com/codex/skills
- **Subagents:** https://developers.openai.com/codex/subagents
- **Hooks:** https://developers.openai.com/codex/hooks
- **Rules:** https://developers.openai.com/codex/rules
- **MCP:** https://developers.openai.com/codex/mcp
- **Plugins:** https://developers.openai.com/codex/plugins
- **Security:** https://developers.openai.com/codex/agent-approvals-security
- **Config basic:** https://developers.openai.com/codex/config-basic
- **Config advanced:** https://developers.openai.com/codex/config-advanced
- **Config reference:** https://developers.openai.com/codex/config-reference
- **Best practices:** https://developers.openai.com/codex/learn/best-practices
- **Pricing:** https://developers.openai.com/codex/pricing
- **Codex Cloud:** https://developers.openai.com/codex/cloud
- **Codex app:** https://developers.openai.com/codex/app
- **Windows:** https://developers.openai.com/codex/windows
- **SDK:** https://developers.openai.com/codex/sdk
- **GitHub Action:** https://developers.openai.com/codex/github-action
- **Changelog:** https://developers.openai.com/codex/changelog
- **Feature Maturity:** https://developers.openai.com/codex/feature-maturity

### Annunci ufficiali
- **Introducing Codex:** https://openai.com/index/introducing-codex/
- **Introducing Codex App:** https://openai.com/index/introducing-the-codex-app/
- **GPT-5.3-Codex:** https://openai.com/index/introducing-gpt-5-3-codex/

### Repository e standard
- **Codex CLI (open-source):** https://github.com/openai/codex
- **Curated skills:** https://github.com/openai/skills
- **Agent Skills standard:** https://agentskills.io/
- **AGENTS.md standard:** https://agents.md/
- **Model Context Protocol:** https://modelcontextprotocol.io/
