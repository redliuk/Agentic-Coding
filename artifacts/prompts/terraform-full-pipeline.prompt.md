---
name: "Terraform Full Pipeline: Plan → Implement → Review"
description: >
  Esegue il flusso completo Terraform in 3 fasi sequenziali:
  1) Planning dalla richiesta utente + contesto architetturale, 2) Implementazione codice .tf,
  3) Review sicurezza e qualità. Richiede conferma utente tra ogni fase.
  Utilizzabile sia per creare l'infrastruttura da zero che per modificare/evolvere codice Terraform esistente.
agent: Azure Terraform Infrastructure Planning
---

# Terraform Full Pipeline

Esegui il flusso completo dell'infrastruttura Terraform in base alla richiesta dell'utente.

> **Questo prompt è utilizzabile sia da zero che su infrastruttura esistente.** Se non esiste ancora codice Terraform, il pipeline parte dal disegno architetturale e dalle specifiche dell'utente per creare l'infrastruttura da zero. Se esiste già codice Terraform, l'utente descrive le modifiche o le evolutive da apportare. In entrambi i casi il pipeline pianifica, implementa e rivede in 3 fasi.

## Prerequisiti agenti

- **Origine**: i tre agenti richiesti provengono dal repository [awesome-copilot](https://github.com/petermsouzajr/awesome-copilot) e sono stati scaricati e adattati per questo progetto.
- **Prerequisito obbligatorio**: il prompt richiede la presenza dei seguenti agenti nella cartella `.github/agents/`: `terraform-azure-planning.agent.md`, `terraform-azure-implement.agent.md`, `terraform-iac-reviewer.agent.md`.
- **Verifica iniziale obbligatoria**: prima di avviare il workflow, verificare che i tre file esistano nella cartella `.github/agents/` e che siano utilizzabili per gli handoff tra le fasi.
- **Fail-fast**: se anche uno solo di questi agenti non esiste, il prompt **non deve partire**. Interrompi immediatamente il workflow e segnala all'utente quale agente manca. Per installare gli agenti mancanti, usare la skill `suggest-awesome-github-copilot-agents` e cercare i nomi corrispondenti.

## Prerequisiti

- **Unico prerequisito obbligatorio**: la cartella `Docs/Arichecture/` deve esistere e contenere il disegno architetturale (file draw.io e/o `.md` descrittivo). Senza il disegno architetturale il pipeline **non deve partire** — segnala all'utente che il contesto architetturale è mancante.
- **Tutte le altre cartelle di lavoro** (`terraform/`, `artifacts/`, `artifacts/artifacts_terraform/`, `artifacts/artifacts_terraform/.terraform-planning-files/`, `artifacts/artifacts_terraform/terraform-implementation-report/`, `artifacts/artifacts_terraform/terraform-review-note/`) vanno **create se non esistono**. La prima esecuzione del pipeline non richiede alcuna cartella oltre a quella del disegno architetturale.

---

## Fonti di contesto

| Cartella | Contenuto | Uso |
|----------|-----------|-----|
| `Docs/Arichecture/` | Disegno architetturale draw.io + file `.md` descrittivo | Contesto architetturale di riferimento |
| `terraform/` | Codice Terraform del progetto (root module + modules/) | Stato as-is dell'infrastruttura (può non esistere se si parte da zero) |
| `artifacts/naming-convention-proposal.md` | Naming convention aziendale | Se presente, tutte le risorse devono rispettarla |
| `artifacts/artifacts_terraform/*.md` (file nella root) | Guide e descrizioni (es. `terraform-architecture-description.md`, `terraform-variables-guide.md`) | Contesto operativo e convenzioni |
| `artifacts/artifacts_terraform/.terraform-planning-files/` | Piani di implementazione (`*.md` con suffisso incrementale) | Solo destinazione di scrittura per la Fase 1 — **non leggere** durante il planning |
| `artifacts/artifacts_terraform/terraform-implementation-report/` | Report di implementazione (`terraform-implementation-report-XX.md`) | Storico delle modifiche — la Fase 2 scrive qui il report |
| `artifacts/artifacts_terraform/terraform-review-note/` | Review notes (`*-XX.md` con suffisso incrementale) | Fase 1 legge solo l'ultima — la Fase 3 scrive qui la review |

### Convenzione sui suffissi incrementali

Tutti i file prodotti nelle 3 fasi usano un **suffisso numerico incrementale a 2 cifre** (`-01`, `-02`, ...) che indica l'ordine cronologico. Il suffisso più basso è il più vecchio. Il suffisso della sessione viene determinato in **Fase 1** e deve poi essere riutilizzato obbligatoriamente in Fase 2 e Fase 3.

I nomi dei file prodotti durante una stessa sessione devono essere **coerenti tra loro**: se il piano si chiama `plan-add-redis-03.md`, l'implementation report deve chiamarsi `terraform-implementation-report-03.md` e la review note `terraform-review-note-03.md`, condividendo lo stesso suffisso per tracciabilità. Prima di creare il piano, verificare i suffissi già presenti nelle cartelle `artifacts/artifacts_terraform/.terraform-planning-files/`, `artifacts/artifacts_terraform/terraform-implementation-report/` e `artifacts/artifacts_terraform/terraform-review-note/`; se il suffisso candidato collide con file già esistenti in una qualsiasi di queste cartelle, incrementarlo fino a trovare un suffisso libero per l'intera sessione.

---

## Fase 1 — Planning (agente: Azure Terraform Infrastructure Planning)

Sei l'agente **Azure Terraform Infrastructure Planning**. Ricevi dall'utente una richiesta di modifica o evolutiva all'infrastruttura Terraform.

### Raccolta contesto

1. **Leggi la richiesta dell'utente** e le specifiche comunicate in chat — questa è la fonte primaria di cosa va pianificato.
2. **Leggi il disegno architetturale** in `Docs/Arichecture/` (file draw.io + file `.md` descrittivo) per comprendere l'architettura target e verificare coerenza con la richiesta.
3. **Analizza il codice Terraform esistente** in `terraform/` per capire lo stato as-is: quali risorse sono già definite, quali moduli esistono, cosa va modificato per soddisfare la richiesta. Se la cartella `terraform/` è vuota o non esiste, si tratta di una creazione da zero — il piano deve definire l'intera struttura partendo dal disegno architetturale e dalle specifiche dell'utente.
4. **Leggi le guide e le descrizioni** nella root di `artifacts/artifacts_terraform/` (es. `terraform-architecture-description.md`, `terraform-variables-guide.md`) per contesto operativo e convenzioni.
5. **Leggi la naming convention** in `artifacts/naming-convention-proposal.md` (se il file esiste) e applicala a tutte le risorse, moduli e variabili del piano.
6. **Consulta lo storico degli implementation report** in `artifacts/artifacts_terraform/terraform-implementation-report/`: elenca i file presenti, leggi solo i titoli/header per contesto, e leggi per intero **solo il report più recente** (suffisso più alto). Non leggere tutti i report — diventano pesanti con lo storico.
7. **Consulta lo storico delle review note** in `artifacts/artifacts_terraform/terraform-review-note/`: elenca i file presenti, leggi solo i titoli/header per contesto, e leggi per intero **solo la review note più recente** (suffisso più alto). Questo permette di tenere conto di eventuali finding aperti o raccomandazioni del reviewer precedente.
8. **Consulta le best practices Azure Terraform** usando i tool `#azureterraformbestpractices` e `#microsoft-docs`.

> **⚠ Cartella esclusa**: NON leggere i file in `artifacts/artifacts_terraform/.terraform-planning-files/` durante la Fase 1. Quella cartella è solo la destinazione di scrittura del piano. I piani precedenti non servono come contesto — il contesto viene dal codice Terraform, dall'architettura e dalla richiesta dell'utente.

### Generazione del piano

9. **Genera il piano di implementazione** seguendo il formato strutturato: WAF assessment, risorse con AVM/Raw specification, variabili, output, dipendenze e fasi di implementazione. Se si parte da zero, il piano deve coprire l'intera infrastruttura richiesta. Se si modifica codice esistente, il piano deve rispondere specificamente alla richiesta dell'utente senza ridisegnare l'intera infrastruttura.
10. **Salva il piano** in `artifacts/artifacts_terraform/.terraform-planning-files/` con pattern `plan-<scopo>-XX.md` (es. `plan-add-redis-03.md`). Determina `XX` come suffisso di sessione in questa fase, verificando i suffissi già presenti nelle tre cartelle di output della sessione (`.terraform-planning-files/`, `terraform-implementation-report/`, `terraform-review-note/`) e scegliendo il primo suffisso libero condivisibile da tutti e tre gli artefatti.

> **STOP**: Presenta il piano all'utente e attendi conferma. Quando confermato, usa il bottone **"▶ Fase 2: Implementa Terraform"** per passare all'agente di implementazione.

---

## Fase 2 — Implementation (agente: Azure Terraform IaC Implementation Specialist)

Dopo approvazione del piano, passa all'agente **Azure Terraform IaC Implementation Specialist**.

1. **Leggi il piano** appena generato in `artifacts/artifacts_terraform/.terraform-planning-files/` (il file con il suffisso più alto, o quello specificato dall'utente).
2. **Leggi la naming convention** in `artifacts/naming-convention-proposal.md` (se il file esiste) e rispettala per naming di risorse, variabili e output.
3. **Leggi le guide e le descrizioni** nella root di `artifacts/artifacts_terraform/` (es. `terraform-architecture-description.md`, `terraform-variables-guide.md`) come contesto operativo e convenzioni — se esistono.
4. **Implementa, aggiorna o elimina i file `.tf`** nella cartella `terraform/` seguendo la gerarchia: piano INFRA → instructions → Azure best practices. Se il piano prevede la rimozione di risorse o moduli, eliminare i file corrispondenti.
5. **Usa Azure Verified Modules (AVM)** dove disponibili, altrimenti risorse raw documentando la scelta.
6. **Valida** con `terraform init`, `terraform validate`, `terraform fmt`.
7. **Non eseguire** `terraform plan` o `terraform apply` senza esplicita conferma dell'utente.
8. **Scrivi l'implementation report** in `artifacts/artifacts_terraform/terraform-implementation-report/terraform-implementation-report-XX.md` (dove `XX` è il suffisso della sessione già assegnato in Fase 1 e coerente con il piano della sessione). Il report deve contenere:
   - Elenco dei file modificati/creati e descrizione dei cambiamenti
   - Motivazione di ogni modifica (collegamento alla richiesta utente e al piano)
   - Valutazione di conformità rispetto alla richiesta dell'utente
   - Eventuali scostamenti dal piano e relative giustificazioni

> **STOP**: Mostra il riepilogo delle modifiche all'utente e attendi conferma. Quando confermato, usa il bottone **"▶ Fase 3: Review Terraform"** per passare al reviewer.

---

## Fase 3 — Review (agente: Terraform IaC Reviewer)

Dopo conferma, passa all'agente **Terraform IaC Reviewer**.

1. **Leggi le guide e le descrizioni** nella root di `artifacts/artifacts_terraform/` (es. `terraform-architecture-description.md`, `terraform-variables-guide.md`) come contesto operativo e convenzioni — se esistono.
2. **Rivedi tutto il codice Terraform** in `terraform/` con focus su:
   - State safety (backend remoto, locking, encryption)
   - Security (no hardcoded secrets, encryption at rest/in transit, least privilege IAM)
   - Module patterns (struttura, variabili con validation, output documentati)
   - Provider/module version pinning
   - Drift detection readiness
   - Tagging consistency
   - Conformità alla naming convention (`artifacts/naming-convention-proposal.md`) — se il file esiste
3. **Esegui la checklist di review** completa definita internamente dall'agente `Terraform IaC Reviewer` e segnala eventuali issue con severità (Critical/High/Medium/Low).
4. **Suggerisci fix** per ogni finding, con codice correttivo quando possibile.
5. **Produci un report finale** in chat con:
   - Summary (pass/fail per categoria)
   - Findings dettagliati
   - Comandi di validazione (`terraform fmt -check`, `terraform validate`, security scan)
   - Rollback strategy
6. **Salva la review note** in `artifacts/artifacts_terraform/terraform-review-note/` con un nome coerente con il piano e l'implementation report della sessione e suffisso incrementale (es. `terraform-review-note-03.md`). La review note deve contenere il report completo prodotto al punto 5.

### Gestione dei Critical findings

7. **Se sono presenti finding di severità Critical**: il reviewer **non applica fix al codice Terraform** in questa fase. Deve documentare i finding nella review note con severità, impatto e raccomandazione correttiva.
8. **Se i finding Critical richiedono modifiche strutturali o correttive** (nuove risorse, redesign moduli, cambio architettura, remediation di security o state safety): il reviewer documenta nella review note una sezione `## Azione richiesta` con le modifiche necessarie. L'utente può usare questa review note come input per una nuova esecuzione del pipeline (Fase 1 → 2 → 3).

---

## Output attesi

| Fase | Artefatto | Posizione |
|------|-----------|-----------|
| Planning | Piano di implementazione | `artifacts/artifacts_terraform/.terraform-planning-files/plan-<scopo>-XX.md` |
| Implementation | File .tf aggiornati | `terraform/` |
| Implementation | Report di implementazione | `artifacts/artifacts_terraform/terraform-implementation-report/terraform-implementation-report-XX.md` |
| Review | Report di review (in chat) | Output nella chat |
| Review | Review note (file persistente) | `artifacts/artifacts_terraform/terraform-review-note/terraform-review-note-XX.md` |

> **Nota**: Il suffisso `XX` è condiviso tra piano, implementation report e review note della stessa sessione per garantire tracciabilità end-to-end.
