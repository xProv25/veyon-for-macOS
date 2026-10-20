# Guida alla Sincronizzazione con il Repository Ufficiale (Fetch & Merge)

Questo documento spiega come mantenere aggiornato il tuo repository (**`origin`**) con le novità, i bugfix e le nuove versioni rilasciate dal team ufficiale di Veyon (**`upstream`**).

---

## 1. Come sono configurati i tuoi Remote

Nel tuo repository Git locale sono attivi due remote:

* **`origin`** (`https://github.com/xProv25/veyon-for-macOS.git`):  
  Il tuo repository personale su GitHub su cui hai i permessi di scrittura e su cui fai il `git push`.

* **`upstream`** (`https://github.com/veyon/veyon.git`):  
  Il repository ufficiale open source del team di Veyon, da cui scarichi (`fetch`) gli aggiornamenti del progetto originale.

Puoi verificare i tuoi remote in qualsiasi momento con il comando:
```bash
git remote -v
```

---

## 2. Procedura Passo-Passo per Sincronizzare

Quando il team di Veyon rilascia aggiornamenti e vuoi integrarli nel tuo codice:

### Passo 1: Assicurati di non avere modifiche non salvate
Prima di iniziare, assicurati che la tua directory di lavoro sia pulita:
```bash
git status
```
Se hai modifiche in sospeso, fai un commit oppure salvale temporaneamente con:
```bash
git stash
```

---

### Passo 2: Scarica i nuovi commit dal repository ufficiale
Questo comando scarica tutti i nuovi rami e commit da `upstream` senza modificare i tuoi file locali:
```bash
git fetch upstream
```

---

### Passo 3: Posizionati sul tuo ramo principale
```bash
git checkout main
```

---

### Passo 4: Integra gli aggiornamenti nel tuo ramo
Unisci le novità di `upstream/main` al tuo ramo `main`:
```bash
git merge upstream/main
```

> [!NOTE]
> * **Se non ci sono conflitti**: Git completerà il merge automaticamente.
> * **Se ci sono conflitti** (raro, a meno che non abbiano modificato le stesse identiche righe dei file generici): Git ti indicherà i file da risolvere. Apri i file in conflitto, correggili, fai `git add <file>` e poi `git commit`.

---

### Passo 5: Invia gli aggiornamenti al tuo GitHub (`origin`)
Ora che il tuo `main` locale ha integrato tutte le novità ufficiali, invialo al tuo repository remoto su GitHub:
```bash
git push origin main
```

---

## 3. Comandi Rapidi (Cheat Sheet)

La sequenza standard completa in un unico blocco:

```bash
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
```

---

## 4. Come scaricare anche i Tag e le Versioni Ufficiali

Se vuoi sincronizzare anche tutti i tag delle versioni ufficiali (es. `v4.9.0`, `v4.10.0`, ecc.):

```bash
git fetch upstream --tags
git push origin --tags
```
