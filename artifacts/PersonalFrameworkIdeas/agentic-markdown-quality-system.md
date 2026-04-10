# Agentic Markdown Quality System

Quality control per file Markdown agentici (`.agent.md`, `.prompt.md`, `SKILL.md`, `.instructions.md`, hooks). 4 agenti specializzati + hook di validazione garantiscono che i file di customizzazione in `.github/` seguano le migliori norme di scrittura da fonti autorevoli.

**Problemi risolti:** (1) nessuno standard unico tra VS Code Copilot, Claude Code e Codex; (2) file copiati da community senza controllo qualità; (3) norme che evolvono ma file che restano fermi.

## Architettura

```
.github/
├── agents/
│   ├── source-scout.agent.md       ← Cura l'indice delle fonti
│   ├── norms-builder.agent.md      ← Costruisce norme concordate per tipo
│   ├── md-auditor.agent.md         ← Audita i file locali (read-only)
│   └── md-fixer.agent.md           ← Corregge le violazioni (con approvazione)
├── hooks/
│   ├── quality-validation.json     ← Hook PostToolUse per .github/quality/
│   └── scripts/validate-quality.ps1
└── quality/
    ├── README.md
    ├── sources.md                  ← Registro curato delle fonti
    └── norms/
        ├── INDEX.md
        └── <tipo>.md               ← Un file norme per tipo (generato da norms-builder)
```

## I tre layer

### Layer 1: Registro Fonti (`sources.md`)

Due sezioni tabellari. Ogni entry ha URL, data verifica, rating (★), note.

| Sezione | Fonti seed | Contenuto |
|---------|-----------|-----------|
| **Repository Sources** | awesome-copilot, spec-kit, anthropics/skills | Dove scaricare file .md di qualità |
| **Norm Sources** | VS Code Copilot Docs (6 pagine), Claude Code Docs, Codex Docs, MCP Spec, agentskills.io | Come scrivere ogni tipo di file |

### Layer 2: Norme Concordate (`norms/`)

Un file per tipo. Contiene norme approvate dall'utente dopo confronto tra fonti. Struttura **enforced dall'hook**:

- `## Required` — norme obbligatorie (violazione = Critical)
- `## Recommended` — raccomandate (violazione = Warning)
- `## Avoid` — anti-pattern
- `## Template` — skeleton di riferimento

### Layer 3: Audit e Fix

Auditor confronta file locali contro norme concordate → report violazioni → fixer corregge con approvazione.

## I 4 agenti

| Agente | Invocazione | Cosa fa | Tools | Handoff verso |
|--------|-------------|---------|-------|---------------|
| **source-scout** | `verify` · `discover` · `report` | Verifica URL fonti, cerca nuove fonti, presenta stato registro | read, search, edit, execute | norms-builder, md-auditor |
| **norms-builder** | `agent-md` · `prompt-md` · `skill-md` · ... · `all` | Fetcha direttive da fonti, classifica in ✅Consenso/⚠️Conflitto/ℹ️Esclusiva, itera con utente, scrive norme | read, search, edit, execute | md-auditor |
| **md-auditor** | `agents` · `prompts` · `skills` · `all` · `<path>` | Carica norme, scansiona file locali, produce report con severity e righe | read, search | md-fixer, norms-builder |
| **md-fixer** | via handoff | Legge report, per ogni violazione mostra fix → attende approvazione → applica | read, search, edit | md-auditor (re-audit) |

**Principi comuni:** nessun agente modifica dati senza approvazione utente. L'auditor è strettamente read-only. Il fixer procede un fix alla volta.

### Norms Builder — dettaglio workflow

1. Legge `sources.md`, filtra fonti per il tipo richiesto
2. Fetcha ogni pagina documentazione con `curl`, estrae le direttive
3. Classifica: ✅ Consenso (auto-accettato) · ⚠️ Conflitto (utente decide) · ℹ️ Esclusiva (utente decide)
4. Presenta comparazione tabellare → itera fino ad approvazione
5. Scrive `quality/norms/<tipo>.md` e aggiorna `INDEX.md`

## Catena di handoff

```
source-scout ──→ norms-builder ──→ md-auditor ──→ md-fixer ──→ md-auditor (loop)
```

Ogni handoff è un **bottone UI** in chat. A differenza dei subagent (stateless), gli handoff preservano tutto il contesto della conversazione — report, decisioni, approvazioni. Non serve copiare nulla.

## Hook di validazione

**Trigger:** `PostToolUse` su file in `.github/quality/` (altrimenti exit silenzioso). Timeout 15s.

**4 check:**
1. `sources.md` esiste e ha contenuto (>50 chars)
2. `norms/INDEX.md` esiste
3. Ogni `.md` in `norms/` è listato in `INDEX.md`
4. Ogni file norme ha `## Required`, `## Recommended`, `## Avoid`

**Output errori:** JSON con `additionalContext` iniettato nella conversazione — l'agente lo vede e sa di dover correggere. Non blocca, avvisa.

## Workflow tipici

**Setup iniziale:** `@source-scout verify` → `@norms-builder agent-md` → `@norms-builder prompt-md` → ...

**Audit di routine:** `@md-auditor agents` → review report → [Fix violations] handoff → [Re-audit] handoff

**Aggiornamento fonti:** `@source-scout discover` → approva candidati → `@norms-builder all`

**File scaricato da community:** copia in `.github/agents/` → `@md-auditor agents` → [Fix violations] handoff

## Design decisions

| Decisione | Motivazione |
|-----------|-------------|
| 4 agenti separati | Responsabilità singola, tool minimi per agente, facile da debuggare |
| `.github/quality/` separata da memory | Dati operativi ≠ conoscenza di progetto. Lifecycle diverso |
| Norme per-tipo | Aggiornamento/audit selettivo senza ricostruire tutto |
| Handoff (non subagent) | Servono contesto precedente (report → fixer). Handoff lo preservano |
| Hook strutturale, non semantico | Rete di sicurezza veloce (<15s). Analisi semantica = auditor on-demand |
| Consenso utente obbligatorio | Fonti in conflitto → utente decide. Nessuna regola imposta automaticamente |

## Relazione con il Memory System

**Complementare** al [Agent Memory System](agent-memory-system.md). Pattern condivisi: hook PostToolUse, read-only reviewer → fixer con approvazione, INDEX.md per navigazione, handoff per contesto.

| | Memory System | Quality System |
|---|---|---|
| **Gestisce** | Conoscenza progetto | Qualità file customizzazione |
| **Dove** | `.github/memory/` | `.github/quality/` |
| **Agenti** | reviewer, fixer, importer | source-scout, norms-builder, auditor, fixer |

## Limiti e evoluzioni possibili

- Le fonti vanno verificate manualmente (no scheduling). Possibile: `.prompt.md` periodico di reminder
- Il fetch dipende da `curl` e dal formato pagine. Possibile: skill di lint integrata nel workflow di creazione agenti
- Norme statiche dopo costruzione. Possibile: norme multi-tool (VS Code/Claude/Codex) e AGENTS.md centrale
