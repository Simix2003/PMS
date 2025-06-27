## Health Check API - Documentazione Operativa
# Descrizione

L'infrastruttura espone endpoint di Health Check sia per il backend che per i vari frontend Flutter Web,
utilizzati per il monitoraggio centralizzato da parte di 3Sun.
Ogni frontend è servito su una porta dedicata e fornisce un file health.json statico accessibile via HTTPS.

## Endpoint Backend

# Metodo: GET
# URL: https://10.10.33.134:8050/api/health_check

Restituisce un oggetto JSON con stato, versioni, uptime, stato database e connessioni PLC.



## Endpoint Frontend (per ciascuna porta)

# Metodo: GET
# URL: https://10.10.33.134:{PORTA}/web_health

Tutti i frontend espongono un file health.json statico su:
Porte attive:
- 8050 -> web_home
- 8051 -> web_data
- 8052 -> web_stringatrici
- 8053 -> web_visual

Porte in sviluppo:
- 8054, 8055 (non ancora attive)

## Parametri
Nessun parametro richiesto. Tutti gli endpoint rispondono a GET.


## Risposte
Le risposte dei frontend sono in formato application/json, statiche, e includono solo informazioni sullo stato
dell'interfaccia web.

# Esempio di risposta frontend (/web_health):
{
"status": "ok",
"frontend": {
"status": "ok",
"version": "2.4.0",
"build_date": "27/06/2025",
"git_commit": "test_123"
}
}

# Esempio di risposta backend (/api/health_check):
{
"status": "ok",
"backend": {
"status": "ok",
"version": "1.0.0",
"build_date": "2025-06-16",
"git_commit": "abc123",
"uptime": "2 days, 4:12:33",
"hostname": "vm-app-01",
"ip": "192.168.10.20",
"timestamp": "2025-06-16T10:15:30Z"
},
"system": {
"cpu_usage": "15.2%",
"ram_usage": "43.5%",
"disk_free": "312.45 GB",
"disk_total": "500.00 GB"
},
"database": {
"status": "ok",
"message": "MySQL OK"

 },
"plc_connections": {
"LineaA": {
"MIN01": "CONNECTED",
"MIN02": "CONNECTED"
},
"LineaB": {
"MIN01": "CONNECTED"
}
}
}


## Note operative
- I file health.json dei frontend vengono generati staticamente e distribuiti all'interno delle cartelle build/ di
ciascun frontend durante il deploy.
- In caso di errore (file mancante), l'endpoint /web_health restituira' 404.

## Monitoraggio con Prometheus
Per il monitoraggio del sistema in ambiente Windows è possibile utilizzare l'[windows_exporter](https://github.com/prometheus-community/windows_exporter).

Lo script `windows_exporter_setup.ps1` nella cartella `service/` scarica e installa l'exporter come servizio di Windows.
Il servizio espone le metriche sulla porta `9182` di default.

### Esempio di configurazione Prometheus
Nel file `prometheus.yml` aggiungere un job di scrape simile al seguente:

```yaml
scrape_configs:
  - job_name: 'windows'
    static_configs:
      - targets: ['HOST_IP:9182']
```

Sostituire `HOST_IP` con l'indirizzo della macchina su cui è in esecuzione l'exporter.
