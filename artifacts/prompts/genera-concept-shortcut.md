# Prompt: Genera Concept Shortcut dalla sessione corrente

> **Quando usare questo prompt**: alla fine di una sessione in cui un agente ha risolto un problema tecnico o chiarito un argomento complesso. Incolla questo prompt nella chat dell'agente prima di chiudere la sessione.

---

## Prompt

```
Analizza ciò che hai fatto in questa sessione e valuta se hai trattato un argomento tecnico specifico che meriterebbe una guida rapida per altri agenti.

### Istruzioni

1. **Verifica duplicati**: prima di creare qualsiasi file, leggi `artifacts/docENI/Concept_shortcut/INDEX.md` e controlla se esiste già un file che copre lo stesso argomento.
   - Se esiste un file simile: **NON crearlo**. Rispondimi indicando:
     - Quale file esistente copre l'argomento
     - Se e cosa cambieresti di quel file (e perché)
     - Aspetta la mia conferma prima di modificare qualsiasi cosa
   - Se non esiste: procedi con i passi seguenti.

2. **Crea il file .md** in `artifacts/docENI/Concept_shortcut/` con queste regole:
   - **Nome file**: descrittivo, lowercase, parole separate da trattini (es. `autenticazione-oauth2-sap.md`)
   - **Contenuto**: guida rapida e autosufficiente, NON un resoconto della sessione
   - **Tono**: diretto, tecnico, senza preamboli
   - **Struttura obbligatoria**:
     ```
     # Titolo descrittivo dell'argomento

     ## Concetti chiave
     (3-5 bullet point con i concetti fondamentali — solo quelli che servono per capire il resto)

     ## [Sezione principale: Procedura / Architettura / Meccanismo / ...]
     (il contenuto utile, con schemi ASCII e comandi pratici dove applicabile)

     ## Schema riassuntivo
     (diagramma ASCII, tabella, o flow sintetico)

     ## Fonti
     (riferimenti ai file di documentazione completa da cui è estratto, se applicabile)
     ```

   **Cosa includere**: solo gli aspetti tecnici dettagliati che hai chiarito nella sessione e che sarebbero utili a un altro agente che affronta lo stesso problema.
   **Cosa NON includere**: il percorso di ragionamento, i tentativi falliti, i passaggi ovvi, le ripetizioni, le spiegazioni didattiche prolisse. Se un concetto si spiega in una riga, usa una riga.

3. **Aggiorna l'indice**: aggiungi una riga alla tabella in `artifacts/docENI/Concept_shortcut/INDEX.md` con:
   - Nome file (link relativo)
   - Argomento (max 15 parole)
   - Quando consultarlo (criteri di ricerca per un agente)

### Criteri di qualità del file

- Un agente che legge questo file deve poter risolvere lo stesso problema SENZA leggere altro.
- Se togli una frase e il file perde informazione utile, la frase è necessaria. Se non perde nulla, toglila.
- Preferisci tabelle e schemi a paragrafi di testo.
- Max 100 righe per file (esclusi blocchi di codice).
```

---

## Note

- Il prompt assume la struttura `artifacts/docENI/Concept_shortcut/` con `INDEX.md`. Adattare i path se si usa una cartella diversa.
- Per il pattern completo di organizzazione documentazione, vedi `artifacts/doc-pattern-guide.md` nel progetto.
