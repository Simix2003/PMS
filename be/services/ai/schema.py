# schema.py

DB_SCHEMA = """
Il database contiene le seguenti tabelle:

1 `productions`
- id (PK)
- linea (INT)
- station (ENUM: 'M308', 'M309', 'M326')
- stringatrice (INT)
- id_modulo (VARCHAR)
- id_utente (VARCHAR)
- data_inizio (DATETIME)
- data_fine (DATETIME)
- esito (BOOLEAN)
- tempo_ciclo (TIME)

2 `ribbon`
- id (PK)
- production_id (FK to productions.id)
- tipo_difetto (ENUM: 'Disallineamento', 'Mancanza')
- tipo (ENUM: 'F', 'M', 'B')
- position (INT)
- scarto (BOOLEAN)

3 `saldatura`
- id (PK)
- production_id (FK)
- category ENUM('Stringa_F', 'Stringa_M_F', 'Stringa_M_B', 'Stringa_B')
- stringa (INT)
- ribbon (INT)
- scarto (BOOLEAN)

4 `disallineamento_stringa`
- id (PK)
- production_id (FK)
- position (INT)
- scarto (BOOLEAN)

5 `lunghezza_string_ribbon`
- id (PK)
- production_id (FK)
- position (INT)
- scarto (BOOLEAN)

6 `generali`
- id (PK)
- production_id (FK)
- tipo_difetto ENUM('Non Lavorato Poe Scaduto', 'Non Lavorato da Telecamere', 'Materiale Esterno su Celle', 'Bad Soldering', 'Macchie ECA', 'Cella Rotta')
- scarto (BOOLEAN)
"""

AI_PROMPT_TEMPLATE = """
Sei un assistente esperto in analisi di produzione industriale. Utilizza la struttura del database e i dati forniti per generare un'analisi completa.

Prima analizza i difetti più comuni, cerca correlazioni tra tempo ciclo medio, produttività e qualità.
Evidenzia eventuali stazioni critiche o pattern nei dati.

Struttura il report in formato JSON con questi campi:
{{
  "periodo_analisi": "Ultimi 7 giorni",
  "totali": {{
    "pezzi_totali": numero,
    "pezzi_buoni": numero,
    "pezzi_scarti": numero,
    "percentuale_buoni": "x.x%",
    "percentuale_scarti": "y.y%",
    "tempo_ciclo_medio": "HH:MM"
  }},
  "problemi_principali": [
    {{"problema": "nome difetto", "numero_scarti": numero}}, ...
  ],
  "trend": {{
    "produttivita": "aumento/riduzione ...",
    "qualita": "aumento/riduzione ..."
  }},
  "analisi_approfondita": [
    "Osservazioni sui pattern"
  ],
  "cose_che_stanno_andando_bene": [
    "Aspetti positivi"
  ],
  "consigli_ai": [
    "Suggerimenti pratici"
  ]
}}

Non scrivere testo fuori dal JSON. Concentrati su insight utili.
"""
