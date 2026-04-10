# GitHub Copilot Coding Agent — Analisi completa

## 1. Cos'è

Il **Copilot coding agent** è un agente autonomo cloud-based di GitHub che lavora su issue e pull request **senza intervento umano continuo**. A differenza di Agent Mode in VS Code (che opera localmente nell'editor con supervisione), il coding agent lavora in background su un ambiente remoto, crea branch, scrive codice, esegue test e lint, e apre PR — come farebbe uno sviluppatore umano.

**Non è un chatbot interattivo in tempo reale:** è un agente asincrono — un "collega virtuale" a cui assegni issue dal backlog e che produce PR pronte per la review.

### Disponibilità

| Piano | Accesso |
|---|---|
| Copilot Pro | Sì |
| Copilot Pro+ | Sì (+ third-party coding agents) |
| Copilot Business | Sì (richiede abilitazione da admin) |
| Copilot Enterprise | Sì (richiede abilitazione da admin + policy) |

Disponibile in tutti i repository GitHub, **esclusi** quelli di managed user accounts e quelli dove è stato disabilitato esplicitamente.

---

## 2. Architettura

```
┌────────────────────────────────────────────────────────────────┐
│                  GitHub (github.com)                            │
│                                                                 │
│  ┌─────────────────────┐   ┌──────────────────────────┐       │
│  │   Entry Points       │   │   Agent Session           │       │
│  │                       │   │                            │       │
│  │  • Issue assign       │──▶│  Ambiente effimero isolato  │       │
│  │  • Agents panel/tab   │   │  (infrastruttura GH Actions)│       │
│  │  • Dashboard          │   │                            │       │
│  │  • Copilot Chat web   │   │  ┌──────────────────────┐ │       │
│  │  • VS Code (delegate) │   │  │  Codebase (read-only) │ │       │
│  │  • JetBrains/Eclipse  │   │  │  + branch di lavoro   │ │       │
│  │  • Visual Studio 2026 │   │  └──────────────────────┘ │       │
│  │  • GitHub CLI          │   │                            │       │
│  │  • GitHub Mobile       │   │  Tools:                    │       │
│  │  • GitHub MCP Server   │   │  • File read/edit/create   │       │
│  │  • Raycast             │   │  • Bash/PowerShell         │       │
│  │  • "New repository"    │   │  • Semantic code search    │       │
│  └─────────────────────┘   │  • Linters, test runners   │       │
│                              │  • MCP servers (custom)     │       │
│  ┌─────────────────────┐   │  • GitHub MCP (built-in)    │       │
│  │  Configurazione      │   │  • Playwright MCP (default) │       │
│  │                       │   │                            │       │
│  │  copilot-instructions │   │  Validazione built-in:     │       │
│  │  .instructions.md     │   │  • CodeQL                  │       │
│  │  AGENTS.md/CLAUDE.md  │   │  • Secret scanning         │       │
│  │  Custom agents        │   │  • Dependency check         │       │
│  │  Hooks                │   │  • Copilot code review      │       │
│  │  Skills               │   │                            │       │
│  │  MCP servers          │   └──────────────────────────┘ │       │
│  │  copilot-setup-steps  │          │                       │       │
│  └─────────────────────┘          ▼                       │       │
│                              ┌──────────────┐              │       │
│                              │  Draft PR     │              │       │
│                              │  copilot/*    │              │       │
│                              │  branch       │              │       │
│                              └──────┬───────┘              │       │
│                                     ▼                       │       │
│                              Review request                 │       │
│                              → Umano                        │       │
└────────────────────────────────────────────────────────────────┘
```

### Differenza fondamentale: Coding Agent vs Agent Mode

| | Coding Agent (cloud) | Agent Mode (IDE) |
|---|---|---|
| **Dove esegue** | Ambiente effimero GitHub Actions | Localmente nell'editor |
| **Interazione** | Asincrona (assegni e vai, Copilot ti notifica) | Sincrona (chat interattiva in real-time) |
| **Output** | Pull request su GitHub | Modifiche dirette ai file locali |
| **Supervisione** | Post-hoc (review PR) | Continua (approvi ogni step) |
| **Accesso a codebase** | Read-only al repo + write su un singolo branch | Full access al filesystem locale |
| **Contesto editor** | Nessuno (non vede file aperti, selezione, diagnostics) | Pieno (file aperti, errori, selezione) |
| **Customizzazione** | Stessi file (`.agent.md`, istruzioni, hooks, skill) — formato condiviso | Stessi file + features IDE-specific |
| **Collaborazione** | Team-native (PR review, `@copilot` in commenti) | Solo sviluppatore singolo |
| **Costo** | GitHub Actions minutes + premium requests | Solo premium requests |

> **Il coding agent è pensato per task "fire-and-forget"** dove assegni lavoro e lo rivedi dopo. Agent Mode è per lavoro interattivo dove vuoi guidare l'AI passo-passo.

---

## 3. Come si usa — Entry points

Il coding agent può essere invocato da **molti entry point** diversi. Tutti producono lo stesso risultato: una sessione agent che crea una PR.

### 3.1 Assegnare un'issue a Copilot (il modo principale)

1. Apri un'issue su GitHub.com
2. In "Assignees" → seleziona **Copilot**
3. (Opzionale) Aggiungi prompt aggiuntivo, scegli branch base, seleziona custom agent, scegli modello
4. Copilot reagisce con 👀 → crea branch `copilot/...` → lavora → apre draft PR → ti chiede la review

**Dove puoi assegnare issue:**
- GitHub.com (UI issue)
- GitHub Mobile
- GitHub API (GraphQL: `createIssue`, `updateIssue`, `replaceActorsForAssignable`, `addAssigneesToAssignable`; REST: endpoints issues)
- GitHub CLI: `gh issue edit`
- Raycast launcher

### 3.2 Agents panel / Agents tab

Navigando su https://github.com/copilot/agents o cliccando l'icona Agents nella navigation bar:
1. Selezioni il repository
2. Scrivi un prompt descrittivo
3. (Opzionale) scegli branch, custom agent, modello
4. Copilot avvia una sessione e crea la PR

### 3.3 Dashboard GitHub

Dalla homepage di github.com → bottone Task → stesso flusso dell'agents panel.

### 3.4 Da IDE (delegazione)

Da **VS Code**, **JetBrains**, **Eclipse**, **Visual Studio 2026**, **Xcode**:
- Scrivi un prompt in Copilot Chat
- Clicca il bottone "Delegate to Coding Agent" (accanto a Send)
- Copilot avvia una sessione cloud e ti restituisce il link alla PR

> **Nota VS Code:** se hai modifiche locali non pushate, un dialog chiede se includerle (push automatico) o ignorarle (parte dal branch default).

### 3.5 Copilot Chat su github.com

Usa `/task` seguito dal prompt. Copilot crea la sessione e la PR.

### 3.6 GitHub CLI

```bash
gh agent-task create "Implement user-friendly error messages"
gh agent-task create --base feature-branch --repo owner/repo --follow "Fix login bug"
```

`--follow` mostra i log della sessione in real-time.

> **Preview:** il comando `agent-task` è disponibile da GitHub CLI v2.80.0+ ed è in **public preview** — può cambiare senza preavviso.

### 3.7 GitHub MCP Server

Da qualsiasi IDE o tool agentico con supporto MCP remoto:
1. Installa il GitHub MCP server
2. Assicurati che il tool `create_pull_request_with_copilot` sia abilitato
3. Chiedi di aprire una PR — Copilot avvia la sessione

### 3.8 Raycast

Estensione GitHub Copilot per Raycast → comando "Create Task" → prompt → selezion repo/branch/agent → invio.

### 3.9 Creazione nuovo repository

Nella pagina "New repository" su GitHub → campo "Prompt" → Copilot crea il repo e apre una PR per popolare il contenuto.

---

## 4. Customizzazione

Il coding agent condivide il sistema di customizzazione con Agent Mode e gli altri ambienti Copilot. I file sono gli stessi documentati in dettaglio in `copilot-customization-guida.md` — qui ci si concentra sugli aspetti **specifici del coding agent**.

### 4.1 Custom instructions (lette dal coding agent)

| File | Scope | Note per il coding agent |
|---|---|---|
| `.github/copilot-instructions.md` | Repository-wide | **Il file più importante.** Include: come buildare, testare, lint, convenzioni |
| `.github/instructions/**/*.instructions.md` | Per pattern file (`applyTo` glob) | Es. regole per test Playwright, componenti React |
| `**/AGENTS.md` | Repository-wide | Letto se presente |
| `/CLAUDE.md` | Repository-wide | Compatibilità, letto se presente |
| `/GEMINI.md` | Repository-wide | Compatibilità, letto se presente |
| Organizzazione custom instructions | Org-wide | Priorità inferiore a quelle di repository |

**Suggerimento chiave:** il coding agent può generare automaticamente `copilot-instructions.md` per te. La prima volta che gli assegni un task in un repo, lascia un commento con un link per la generazione automatica.

### 4.2 Custom agents (agent profiles)

I custom agent sono versioni specializzate del coding agent, definiti come `.agent.md` — lo stesso formato documentato in `copilot-customization-guida.md`.

**Posizioni specifiche:**

| Scope | Percorso |
|---|---|
| Repository | `.github/agents/NOME.agent.md` |
| Organizzazione | `.github-private/agents/NOME.agent.md` (repo `.github-private`) |
| Enterprise | `.github-private/agents/NOME.agent.md` (repo `.github-private`) |

**Creazione da GitHub.com:**
1. Agents tab → seleziona repo → icona agent → "Create an agent"
2. Si apre un template `my-agent.agent.md` in `.github/agents/`
3. Configuri nome, description, tools, prompt
4. Commit e merge nel branch default

**Proprietà supportate dal coding agent:**

| Campo | Supportato | Note |
|---|---|---|
| `name` | Sì | Identificativo |
| `description` | Sì (**obbligatorio**) | Usato per scelta agent |
| `tools` | Sì | Whitelist tool (ometti per tutti) |
| `mcp-servers` | Sì | MCP inline, avviati con l'agente |
| `model` | Parziale | Supportato in IDE; selezione modello nel coding agent è via dropdown all'assegnazione |
| `target` | Sì | `"vscode"` o `"github-copilot"` per limitare dove è disponibile |
| `handoffs` | Solo IDE | Non rilevante nel contesto coding agent |
| `hooks` | Sì | Lifecycle hooks scoped all'agente |

**Esempio concreto — testing specialist:**

```yaml
---
name: test-specialist
description: Focuses on test coverage, quality, and testing best practices without modifying production code
---

You are a testing specialist focused on improving code quality through comprehensive testing.

- Analyze existing tests and identify coverage gaps
- Write unit tests, integration tests, and end-to-end tests
- Review test quality and suggest improvements
- Focus only on test files — avoid modifying production code unless requested
- Include clear test descriptions
```

**Esempio — implementation planner (tool limitati):**

```yaml
---
name: implementation-planner
description: Creates detailed implementation plans and technical specifications in markdown format
tools: ["read", "search", "edit"]
---

You are a technical planning specialist.
Create comprehensive implementation plans with clear steps, dependencies, and acceptance criteria.
Focus on documentation rather than implementing code.
```

### 4.3 MCP — Configurazione specifica per il coding agent

L'MCP nel coding agent ha alcune differenze rispetto alla configurazione in VS Code:

**Dove si configura:** direttamente nelle **Settings del repository** su GitHub.com:
- Settings → Code & automation → Copilot → Coding agent → "MCP configuration"

**Formato:**

```json
{
  "mcpServers": {
    "nome-server": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@example/mcp-server"],
      "tools": ["tool1", "tool2"],
      "env": {
        "API_KEY": "$COPILOT_MCP_API_KEY"
      }
    }
  }
}
```

**Differenze chiave rispetto a VS Code:**

| Aspetto | VS Code (`.vscode/mcp.json`) | Coding Agent (repo settings) |
|---|---|---|
| **Posizione config** | File nel repo | Settings UI di GitHub |
| **Campo `tools`** | Non richiesto | **Obbligatorio** — whitelist esplicita dei tool |
| **Variabili** | `inputs` | `env` con prefisso `COPILOT_MCP_` |
| **Segreti** | Variabili d'ambiente locali | Copilot environment secrets |
| **Tipi server** | `http`, `stdio` | `local`/`stdio`, `http`, `sse` |
| **Esecuzione autonoma** | Richiede approvazione per-tool | **Tool usati autonomamente** senza approvazione |

**Server MCP built-in (abilitati di default):**
- **GitHub MCP server** — accesso read-only al repo corrente (issues, PR storiche, code search)
- **Playwright MCP server** — interazione browser per test UI

**Customizzazione del GitHub MCP server built-in:**

Per accedere a dati oltre il repo corrente, puoi fornire un PAT con permessi più ampi:

```json
{
  "mcpServers": {
    "github-mcp-server": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/readonly",
      "tools": ["*"],
      "headers": {
        "X-MCP-Toolsets": "repos,issues,users,pull_requests,code_security,actions,web_search"
      }
    }
  }
}
```

Il secret `COPILOT_MCP_GITHUB_PERSONAL_ACCESS_TOKEN` va aggiunto all'ambiente `copilot` del repository.

**Copilot Environment per segreti:**
1. Repository Settings → Environments → New environment → nome: `copilot`
2. Aggiungi secrets con prefisso `COPILOT_MCP_` (es. `COPILOT_MCP_SENTRY_TOKEN`)

### 4.4 Hooks — Lifecycle nel coding agent

Gli hook nel coding agent usano un formato leggermente diverso da quello di VS Code, dettagliato in `copilot-customization-guida.md`.

**Posizione:** `.github/hooks/*.json` (stessa di VS Code)

**Formato specifico coding agent:**

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      {
        "type": "command",
        "bash": "echo 'Session started' >> logs/session.log",
        "powershell": "Add-Content -Path logs/session.log -Value 'Session started'",
        "cwd": ".",
        "timeoutSec": 10
      }
    ],
    "preToolUse": [
      {
        "type": "command",
        "bash": "./scripts/security-check.sh",
        "powershell": "./scripts/security-check.ps1",
        "cwd": "scripts",
        "timeoutSec": 15
      }
    ]
  }
}
```

**Differenze dal formato VS Code:**

| Aspetto | VS Code hooks | Coding agent hooks |
|---|---|---|
| **Campo version** | Non richiesto | **`"version": 1` obbligatorio** |
| **Comandi** | `command` (stringa unica) | `bash` + `powershell` (separati per OS) |
| **Timeout** | `timeout` (secondi) | `timeoutSec` (secondi) |
| **Override OS** | `windows`, `linux`, `osx` | `bash` / `powershell` |
| **Tipo** | `"command"` | `"command"` |
| **Env** | `env` (oggetto) | `env` (oggetto) |

**Tipi di hook disponibili:**

| Hook | Quando | Può bloccare? |
|---|---|---|
| `sessionStart` | Nuova sessione o resume | No |
| `sessionEnd` | Sessione completata/terminata | No |
| `userPromptSubmitted` | Utente invia prompt | No |
| `preToolUse` | Prima di ogni tool | **Sì** (il più potente) |
| `postToolUse` | Dopo tool (successo o fallimento) | No |
| `agentStop` | Agente principale finisce | No |
| `subagentStop` | Subagent completa | No |
| `errorOccurred` | Errore durante l'esecuzione | No |

> **Nota:** il coding agent supporta anche hooks (e skills) dal **GitHub Copilot CLI**. Lo stesso formato funziona in entrambi.

### 4.5 Environment di sviluppo (`copilot-setup-steps.yml`)

Il coding agent lavora in un ambiente effimero basato su GitHub Actions. Per assicurare che le dipendenze siano pronte:

```yaml
# .github/workflows/copilot-setup-steps.yml
on:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  copilot-setup-steps:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install dependencies
        run: npm ci
      - name: Setup database
        run: docker compose up -d db
```

**Perché è importante:** senza questo file, Copilot deve scoprire e installare le dipendenze via trial-and-error (lento e non deterministico). Con `copilot-setup-steps.yml`, l'ambiente è pronto all'avvio e le PR sono più accurate.

### 4.6 Skills

Le skill funzionano nel coding agent con lo stesso formato documentato in `copilot-customization-guida.md`. Posizione principale: `.github/skills/<nome>/SKILL.md`.

---

## 5. Copilot Memory (Public Preview)

Feature distinta dal sistema di memory/istruzioni — è una **memoria agentica** in cui Copilot **impara autonomamente** dal repository.

### Come funziona

- Copilot genera **memorie** (fatti tightly-scoped) mentre lavora su un repository
- Le memorie sono **repository-scoped**, non user-scoped: ciò che Copilot impara resta nel repo
- Ogni memoria ha **citazioni** a posizioni specifiche nel codice
- Prima di usare una memoria, Copilot **valida le citazioni** sul codebase corrente per verificare che siano ancora attuali
- Le memorie **scadono dopo 28 giorni** se non vengono rivalidate e ricreate
- Solo utenti con **write permission** e **Copilot Memory abilitato** possono generare memorie

### Cross-feature

Le memorie create dal coding agent sono disponibili anche per:
- **Copilot code review** (può applicare pattern appresi a PR non create dal coding agent)
- **Copilot CLI**

Esempio pratico: se il coding agent scopre come il tuo repo gestisce le connessioni database, il code review saprà individuare pattern inconsistenti in PR successive.

### Abilitazione

| Piano | Default |
|---|---|
| Pro / Pro+ | Abilitato di default |
| Business / Enterprise | **Disabilitato** — richiede abilitazione da admin in org/enterprise settings |

### Confronto con i sistemi di memoria degli altri tool

| | Copilot Memory | Claude Code Auto Memory | VS Code Copilot (instructions) |
|---|---|---|---|
| **Chi scrive** | Copilot (automatico) | Claude (automatico) | Utente (manuale) |
| **Scope** | Repository | Progetto (directory locale) | Repository/utente |
| **Scadenza** | 28 giorni (se non rivalidata) | Nessuna (persistente fino a cancellazione) | Nessuna |
| **Validazione** | Citazioni verificate sul codebase | Nessuna validazione automatica | N/A |
| **Cross-feature** | Sì (coding agent → code review → CLI) | No (solo sessioni Claude) | Sì (Copilot Chat, Agent Mode, coding agent) |
| **Gestione** | UI GitHub (owner può review/delete) | `/memory` nella CLI | Edit file nel repo |

---

## 6. Sicurezza — Modello di protezione

Il coding agent ha **protezioni built-in significative**, più stringenti di Agent Mode locale.

### Validazione automatica del codice

| Tool | Funzione | Disabilitabile? |
|---|---|---|
| **CodeQL** | Analisi sicurezza del codice generato | Sì (repo settings) |
| **Dependency check** | Verifica dipendenze vs GitHub Advisory Database (malware + CVSS High/Critical) | Sì |
| **Secret scanning** | Rileva API key, token, segreti nel codice | Sì |
| **Copilot code review** | "Second opinion" AI sulla qualità del codice | Sì |

Copilot tenta di risolvere i problemi identificati **prima** di completare la PR. Questi tool **non richiedono** licenze GitHub Secret Protection, Code Security o Advanced Security.

### Restrizioni di accesso

| Restrizione | Dettaglio |
|---|---|
| **Branch** | Può pushare solo su un singolo branch (`copilot/...` per nuove PR, branch esistente per `@copilot` su PR) |
| **Repository** | Read-only al repository; write solo sul branch di lavoro |
| **Rete** | Firewall che controlla l'accesso internet |
| **Credenziali** | Non può eseguire `git push` o altri comandi Git direttamente — solo operazioni push semplici |
| **Workflow Actions** | Di default, i workflow **non partono** quando Copilot pusha — richiedono approvazione manuale ("Approve and run workflows") |
| **Commenti** | Risponde **solo** a utenti con write permission al repository |

### Governance

| Garanzia | Meccanismo |
|---|---|
| **Tracciabilità commit** | Autore = Copilot, co-autore = chi ha assegnato il task. Commit message include link ai session log |
| **PR draft** | Copilot **non può** marcare PR come "Ready for review", né approvarle, né mergarle |
| **No self-approve** | Chi ha chiesto la PR non può approvarla (con "Required approvals" rule) |
| **Anti-prompt-injection** | HTML comments e caratteri nascosti in issue/commenti vengono filtrati prima di passare al modello |

### Rischi documentati

1. **Push di codice indesiderato** → mitigato da: branch limitato, draft PR, ban self-approve, workflow gating
2. **Accesso a informazioni sensibili** → mitigato da: firewall, read-only access, secret filtering
3. **Prompt injection** → mitigato da: filtraggio caratteri nascosti, HTML comment stripping

---

## 7. Modelli AI

Il modello può essere scelto al momento dell'assegnazione del task (se il piano lo permette):

| Piano | Selezione modello |
|---|---|
| Pro / Pro+ | Sì (dropdown al momento dell'assegnazione) |
| Business / Enterprise | Dipende dalle policy dell'organizzazione |

La scelta del modello è specifica per la sessione del coding agent (non per il repository). Modelli diversi possono performare meglio su tipi diversi di task.

> **Nota:** la documentazione non elenca i modelli specifici disponibili per il coding agent (la lista evolve). La selezione è tramite dropdown UI, non via campo `model` nel frontmatter dell'agent profile (che funziona invece per gli IDE).

---

## 8. Costi

Il coding agent consuma:

| Risorsa | Tipo |
|---|---|
| **GitHub Actions minutes** | Per l'ambiente effimero di esecuzione |
| **Copilot premium requests** | Per le chiamate al modello AI |

Entrambe le risorse sono incluse nell'allowance mensile del piano. Finché resti nell'allowance, non ci sono costi aggiuntivi. **L'uso oltre l'allowance può generare costi aggiuntivi**, in particolare per GitHub Actions minutes nei piani organizzativi (Business/Enterprise).

---

## 9. Workflow di iterazione — Lavorare con le PR di Copilot

### Flusso tipico

```
1. Assegna issue/task a Copilot
   ↓
2. Copilot reagisce (👀) → crea branch copilot/... → lavora
   ↓
3. Copilot apre draft PR → esegue validazione (CodeQL, etc.)
   ↓
4. Copilot ti chiede la review
   ↓
5. Tu rivedi la PR
   ├── OK → approvi e mergi
   └── Modifiche necessarie:
       ├── @copilot "correggi X" (comment singolo o batch come review)
       │   → Copilot rework e pusha nuovi commit
       └── Push manuale al branch → tu continui il lavoro
   ↓
6. Ripeti step 5 finché la PR è pronta
```

### Best practices per l'iterazione

- **Usa "Start a review"** per batchare più commenti → Copilot reagisce all'intera review, non a commenti singoli
- **@copilot nei commenti** — sii specifico su cosa cambiare
- Copilot **aggiorna title e body** della PR automaticamente per riflettere le modifiche
- Puoi **continuare tu** il lavoro sul branch se preferisci

---

## 10. Best practices

### Task ideali per il coding agent

| Adatti | Non adatti |
|---|---|
| Bug fix con descrizione chiara | Refactoring complessi cross-repo |
| Feature incrementali | Task che richiedono conoscenza di dominio profonda |
| Miglioramento test coverage | Task con requisiti ambigui |
| Aggiornamento documentazione | Incident response / production-critical |
| Riduzione technical debt | Task dove vuoi imparare |
| Accessibility improvements | Task con security/PII implications |
| Scaffolding per nuovi progetti | Task che richiedono design creativity |

### Scrivere buone issue (= buoni prompt)

Un'issue efficace per il coding agent include:
1. **Descrizione chiara** del problema/lavoro richiesto
2. **Acceptance criteria** — cosa deve essere vero nella soluzione (test unitari? copertura? formato?)
3. **Direzioni sui file** — quali file toccare (Copilot ha semantic search, ma i suggerimenti aiutano)

### Customizzazione progressiva

```
1. Inizia senza customizzazione — assegna task semplici
   ↓
2. Aggiungi copilot-instructions.md — build, test, convenzioni
   (Copilot può generarlo per te alla prima assegnazione)
   ↓
3. Aggiungi copilot-setup-steps.yml — pre-installa dipendenze
   ↓
4. Aggiungi .instructions.md per pattern — regole per tipi di file specifici
   ↓
5. Crea custom agents — agenti specializzati (testing, docs, frontend...)
   ↓
6. Configura MCP servers — integra tool esterni (Sentry, Notion, Azure, Jira...)
   ↓
7. Aggiungi hooks — automazione deterministica (security check, formatting, audit)
   ↓
8. Abilita Copilot Memory — lascia che Copilot impari dal repository
```

---

## 11. Integrazioni con tool di terze parti

Il coding agent può essere invocato da **tool esterni** tramite:
- **GitHub MCP Server** — qualsiasi IDE/tool con supporto MCP remoto può creare PR
- **GitHub API** (REST e GraphQL) — automazione programmatica
- **Raycast** — launcher per macOS/Windows con estensione GitHub Copilot
- **GitHub CLI** — `gh agent-task create`

Esempi di integrazioni MCP documentate:
| Server | Provider | Funzione |
|---|---|---|
| Sentry | Sentry | Accesso a eccezioni e bug reports |
| Notion | Notion | Accesso a note e documentazione |
| Azure | Microsoft | Risorse Azure e file Azure-specifici |
| Azure DevOps | Microsoft | Work items, pipelines |
| Cloudflare | Cloudflare | Servizi Cloudflare |
| Atlassian | Atlassian | Jira, Confluence, Compass |

---

## 12. Limitazioni

| Limitazione | Impatto |
|---|---|
| **Singolo repository** | Non può fare modifiche cross-repo in una sola sessione |
| **Una PR per task** | Ogni task produce esattamente una PR |
| **Read-only di default** | Il GitHub MCP built-in ha accesso read-only al repo corrente (ampliabile con PAT) |
| **No signed commits** | Incompatibile con ruleset "Require signed commits" (va aggiunto come bypass actor) |
| **No content exclusions** | Non rispetta le content exclusions configurate per Copilot |
| **Solo GitHub-hosted** | Funziona solo con repository su GitHub |
| **No OAuth MCP** | Non supporta server MCP remoti con autenticazione OAuth |
| **Workflow gating** | Di default Actions non girano — richiede approvazione manuale per ogni push (configurabile) |
| **Contesto limitato** | Non vede commenti aggiunti dopo l'assegnazione dell'issue (usa i commenti sulla PR per iterare) |

---

## 13. Confronto con gli altri tool analizzati

I file esistenti documentano in dettaglio Agent Mode (VS Code) e Claude Code. Ecco dove si colloca il coding agent:

| Dimensione | Coding Agent (GitHub) | Agent Mode (VS Code) | Claude Code |
|---|---|---|---|
| **Esecuzione** | Cloud (GitHub Actions) | Locale (editor) | Locale (CLI) o remota (web) |
| **Autonomia** | Alta (fire-and-forget) | Media (supervisione continua) | Variabile (normal → auto → headless) |
| **Output** | PR su GitHub | File locali | File locali + PR (opzionale) |
| **Collaborazione** | Team-native (PR review) | Singolo sviluppatore | Singolo (o remote control) |
| **Customizzazione** | instructions, agents, hooks, skill, MCP | instructions, agents, hooks, skill, MCP | CLAUDE.md, rules, subagent, hooks, skill, MCP |
| **Validazione built-in** | CodeQL, secret scanning, dep check, code review | Nessuna | Nessuna |
| **Memory** | Copilot Memory (auto, 28d TTL, con citazioni validate) | Tool memory (manuale, sessione) | Auto Memory (persistente su file, indefinita) |
| **Modelli** | Multi-model (via dropdown) | Multi-model (multi-provider) | Solo Claude |
| **Costo** | Actions minutes + premium requests | Solo premium requests | Pricing Anthropic |
| **Isolamento** | Ambiente effimero con firewall | Nessuno | Git worktree (opzionale) |
| **Entry points** | 10+ (issue, panel, dashboard, IDE, CLI, MCP, mobile, Raycast...) | Solo dall'editor | CLI, IDE extension, web, desktop, mobile |

### Quando usare il coding agent (vs le alternative)

**Usa il coding agent quando:**
- Il task è **chiaro e ben definito** (bug fix, test, docs, refactoring locale)
- Vuoi **parallelizzare** — assegnare più issue contemporaneamente
- Il lavoro è **non urgente** — puoi aspettare la PR e revisionarla dopo
- Vuoi **tracciabilità** — ogni step negli audit log, commit con co-autore
- Il team deve **collaborare** sull'output (PR review nativo)

**Usa Agent Mode quando:**
- Il task richiede **interazione continua** e steering in real-time
- Hai bisogno dell'**editor context** (file aperti, diagnostics, selezione)
- Il task è **esplorativo** e non sai bene cosa vuoi finché non lo vedi
- Vuoi **controllare ogni modifica** prima che venga applicata

**Usa Claude Code quando:**
- Servono **hook complessi** (25+ eventi, handler LLM/agent/HTTP)
- Vuoi **auto-memory persistente** senza scadenza
- Il workflow richiede **CLI-first** o automazione headless avanzata
- Serve **isolamento filesystem** con git worktree

---

## 14. Nota metodologica sulle fonti

Questa analisi è basata sulla **documentazione ufficiale GitHub** (marzo 2026). Le pagine di riferimento principali:

- About coding agent: https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent
- Creating PRs: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-a-pr
- Custom agents: https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-custom-agents
- Creating custom agents: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-custom-agents
- Custom agents config: https://docs.github.com/en/copilot/reference/custom-agents-configuration
- Hooks: https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-hooks
- Hooks config: https://docs.github.com/en/copilot/reference/hooks-configuration
- MCP extension: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/extend-coding-agent-with-mcp
- Settings: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/configuring-agent-settings
- Best practices: https://docs.github.com/en/copilot/tutorials/coding-agent/best-practices
- Copilot Memory: https://docs.github.com/en/copilot/concepts/agents/copilot-memory
- Firewall: https://docs.github.com/en/copilot/customizing-copilot/customizing-or-disabling-the-firewall-for-copilot-coding-agent
- Environment: https://docs.github.com/en/copilot/customizing-copilot/customizing-the-development-environment-for-copilot-coding-agent
- Managing access: https://docs.github.com/en/copilot/concepts/agents/coding-agent/managing-access
- Tracking sessions: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/track-copilot-sessions
- Review PR: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/review-copilot-prs
- Hands-on: https://github.com/skills/expand-your-team-with-copilot/

Per gli aspetti di customizzazione condivisi con Agent Mode (formato `.agent.md`, `.instructions.md`, `SKILL.md`, hooks nel formato VS Code, MCP in VS Code), fare riferimento a **copilot-customization-guida.md** che li documenta in dettaglio.

Per il confronto con Claude Code, fare riferimento a **confronto-copilot-vs-claude-code.md**.
