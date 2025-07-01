# PMS

## PMS – Avvio Backend e Frontend

## Configurazione Iniziale

Per avviare il sistema in modalità di sviluppo **senza connessione al PLC**, è necessario abilitare la modalità debug:

1. Apri il file di configurazione:

   ```
   service/config/config.py
   ```

2. Imposta la seguente variabile:

   ```python
   debug = True
   ```

Questo bypassa la connessione al PLC e consente l’esecuzione in locale.

---

## Configurazione Database

Prima di avviare il backend, è necessario creare lo schema del database. Utilizza il file schema.sql incluso nel progetto:

```
service\schema.sql
```


## Avvio del Backend

Esegui il backend tramite:

```bash
python service/main.py
```

Assicurati di avere tutte le dipendenze installate tramite:

```bash
pip install -r service/requirements.txt
```

### Log JSON

Ogni richiesta HTTP generata dal backend viene registrata in formato JSON.
Nel terminale (o nei log del container) compariranno record simili a:

```json
{"method": "GET", "path": "/api/health_check", "status_code": 200, "duration_ms": 3.5}
```

Questi log di accesso sono prodotti tramite un middleware FastAPI e
sono inviati allo standard output. Se avvii l'applicazione in Docker,
puoi leggerli con `docker logs`.

---

## Avvio del Frontend (Flutter Web)

A seconda della pagina che vuoi visualizzare, esegui uno dei seguenti comandi:

* **Home Page**:

  ```bash
  flutter run -d chrome --web-renderer html -t lib/main_home.dart
  ```

* **Pagina Dati Produzione**:

  ```bash
  flutter run -d chrome --web-renderer html -t lib/main_data.dart
  ```

* **Pagina Stringatrici**:

  ```bash
  flutter run -d chrome --web-renderer html -t lib/main_stringatrici.dart
  ```

* **Visualizzazione in Tempo Reale**:

  ```bash
  flutter run -d chrome --web-renderer html -t lib/main_visual.dart
  ```

> ℹ️ Verifica che Flutter sia installato correttamente con:
>
> ```bash
> flutter doctor
> ```

---

## Struttura Progetto (Base)

```
/lib                    # Codice Flutter frontend
/service                # Backend Python
```

---

## ✅ Note Finali

* Modalità debug = solo per sviluppo. Disabilitare (`debug = False`) per ambiente di produzione.
* Verifica eventuali porte occupate prima di avviare il backend.

## Changelog
Versions:
"2.1.0" — Moved Visuals Data to global state, made main.py faster
"2.1.1" — Added ETA prediction, added ETA explanation dialog, added MBJ warning
"2.2.0" - Visual Management
"2.1.1" - Visual Management added Date and Time Visualization
"2.2.2" - Fixed "MaybeMBJ" visual bug and Fixed Stringatrice last STATION bug
"2.2.3" - Added Fermi Data to Visual page
"2.2.4" - Fixed Fermi task to iterate thru PLC and not each Station
"2.2.5" - Fixed bugs and LOCK problem
"2.2.6" - Added Export visuals and VPF
"2.3.0" - Added Mini Bro for Daily export
"2.3.1" - Fixed Mini Bro, Fixed Visual, added Process Eng & Capgemini, Added "Difetto" filter for VPF
"2.3.2" - Added AIN filter and AIN NG2 & NG3
"2.3.3" - Visual Improvements, small fixes
"2.3.4" - MBJ Defects and new Averages
"2.4.0" - Visual Management for ELL
"2.4.1" - Improvements on MBJ view

## OWASP dependency verification

Per verificare la presenza di vulnerabilità note nelle dipendenze Python è
possibile utilizzare `pip-audit`. L'esecuzione di `pip-audit` consente di
confrontare le versioni dichiarate in `service/requirements.txt` con il
database CVE mantenuto da PyPA.

```bash
# installazione dello strumento (richiede connettività a PyPI)
pip install pip-audit

# scansione delle dipendenze
pip-audit -r service/requirements.txt

#Se il Venv è attivo basta fare : 
pip-audit
```

Se vengono rilevate librerie affette da vulnerabilità, è necessario aggiornarle
alla versione corretta, modificando `service/requirements.txt` e verificando che
la nuova versione non riporti alert.

Last run: 26/06/2023 18:42:00
(venv) PS D:\Imix\Lavori\2025\3SUN\IX-Monitor\ix_monitor> pip-audit
Found 2 known vulnerabilities in 1 package
Name  Version ID                  Fix Versions
----- ------- ------------------- ------------
torch 2.7.0   GHSA-887c-mr87-cxwp
torch 2.7.0   GHSA-3749-ghw9-m3mg 2.7.1rc1

## Log Collection on Windows

Per istruzioni sull'installazione e configurazione dell'agente di raccolta log (Filebeat) consultare [service/README_LOGGING.md](service/README_LOGGING.md).

