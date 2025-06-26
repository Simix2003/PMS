# PMS

Production Monitoring System
A web application to monitor productions in a factory.

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