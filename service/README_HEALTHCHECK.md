# Health Check API - Documentazione Operativa

## Descrizione

L’applicazione espone un endpoint di Health Check conforme ai requisiti richiesti per il monitoraggio centralizzato da parte dell’infrastruttura 3Sun.

## Endpoint

**Metodo:** `GET`  
**URL:** `https://192.168.32.138:8050/api/health_check`

---

## Parametri

L'endpoint non richiede parametri.

---

## Risposte

La risposta è in formato `application/json` strutturato.

### Esempio di risposta (OK)

```json
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
