# Critica — Strategia artifacts/ e customizzazione agenti

## Cosa funziona

- **Navigazione gerarchica con INDEX.md** risolve un problema reale: gli agenti hanno contesto limitato, leggere un indice prima di scegliere cosa approfondire evita sprechi. VS Code non offre nulla di nativo per questo.
- **Concept_shortcut come knowledge base incrementale** è una buona idea: il sapere di progetto cresce col lavoro del team.
- **Prompt di fine sessione per generare Concept_shortcut** è un pattern valido di knowledge capture.

## Cosa migliorare

### 1. Il prompt `genera-concept-shortcut.md` dovrebbe essere un `.prompt.md`

VS Code supporta nativamente i file `.prompt.md` in `.github/prompts/`. Vantaggi:
- Invocabile con `/genera-concept-shortcut` nella chat
- Supporta metadata YAML (descrizione, tools, agent)
- Integrato nell'UI

Attualmente è un `.md` generico in una cartella esterna — l'agente non lo vede a meno che non lo incolli.

### 2. Il `copilot-instructions.md` è troppo "navigazionale"

La doc ufficiale dice: usalo per *coding style, tech stack, architectural patterns, security, documentation standards*. Le istruzioni su come navigare `artifacts/` andrebbero meglio in un file `.instructions.md` dedicato o in un `AGENTS.md`.

### 3. Non si usa `AGENTS.md`

VS Code supporta `AGENTS.md` nella root del workspace. È riconosciuto da **tutti gli agenti AI** (non solo Copilot). Le istruzioni cross-agent (come navigare `artifacts/`) andrebbero qui.

### 4. Il copilot-instructions.md "generico" non è portabile come sembra

Il file in `Agentic Coding/copilot-instructions.md` non viene letto da nessun agente — deve stare dentro un workspace `.github/`. Per istruzioni globali cross-workspace, VS Code supporta **user-level instructions** in `~/.copilot/instructions/*.instructions.md` con `applyTo: "**"`.

### 5. Il pattern `artifacts/` è interamente custom

Non è uno standard di community. Ogni agente deve "imparare" che esiste tramite istruzioni. Se qualcuno clona il repo, non sa che `artifacts/` ha un ruolo speciale senza leggere le istruzioni. Non è un problema, ma va tenuto presente.

## Azioni suggerite

| Stato attuale | Migrazione suggerita |
|---------------|---------------------|
| `Agentic Coding/prompts/genera-concept-shortcut.md` | `.github/prompts/genera-concept-shortcut.prompt.md` — invocabile con `/genera-concept-shortcut` |
| `Agentic Coding/copilot-instructions.md` (generico) | `~/.copilot/instructions/artifacts-navigation.instructions.md` con `applyTo: "**"` |
| Tutto in `copilot-instructions.md` | Separare: `copilot-instructions.md` per coding standards, `AGENTS.md` per navigazione docs |

## Verdetto

La strategia è **buona nella sostanza** (context management, knowledge capture incrementale, navigazione gerarchica). L'implementazione potrebbe sfruttare meglio i meccanismi nativi VS Code (`.prompt.md`, `.instructions.md`, `AGENTS.md`, user-level instructions) per integrare il tutto nell'ambiente senza dipendere dal copia-incolla.
