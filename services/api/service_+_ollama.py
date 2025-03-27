from fastapi import FastAPI
from fastapi.responses import JSONResponse
import pymysql
from pymysql.cursors import DictCursor
import json
from datetime import datetime, timedelta
import ollama


app = FastAPI()

# MySQL configuration – update these values to your actual database settings
mysql_config = {
    'host': 'localhost',
    'user': 'root',
    'password': 'password',
    'database': 'your_production_db'
}

# Your database schema as provided
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

@app.get("/api/ai_report")
async def ai_report():
    try:
        connection = pymysql.connect(
            host="localhost",
            user="root",
            password="Master36!",
            database="production_data",
            port=3306,
            cursorclass=DictCursor,
            autocommit=False  # or True if you want auto-commit
        )
        cursor = connection.cursor()


        
        # Define the period: last 7 days
        end_date = datetime.now()
        start_date = end_date - timedelta(days=7)
        start_date_str = start_date.strftime('%Y-%m-%d %H:%M:%S')
        
        # --------------------------------------------------------------
        # 1. Aggregate production totals from the "productions" table
        # --------------------------------------------------------------
        query_totals = """
            SELECT
                COUNT(*) AS pezzi_totali,
                SUM(CASE WHEN esito = 1 THEN 1 ELSE 0 END) AS pezzi_buoni,
                SUM(CASE WHEN esito = 0 THEN 1 ELSE 0 END) AS pezzi_scarti,
                AVG(TIME_TO_SEC(tempo_ciclo)) AS tempo_ciclo_medio_sec
            FROM productions
            WHERE data_inizio >= %s
        """
        cursor.execute(query_totals, (start_date_str,))
        totals = cursor.fetchone() or {}

        pezzi_totali = totals.get('pezzi_totali', 0)
        pezzi_buoni = totals.get('pezzi_buoni', 0)
        pezzi_scarti = totals.get('pezzi_scarti', 0)
        tempo_ciclo_medio_sec = totals.get('tempo_ciclo_medio_sec', 0.0)

        
        # Format average cycle time as HH:MM (approximate)
        minutes = int(tempo_ciclo_medio_sec // 60)
        seconds = int(tempo_ciclo_medio_sec % 60)
        tempo_ciclo_medio = f"{minutes:02d}:{seconds:02d}"
        
        percentuale_buoni = f"{(pezzi_buoni/pezzi_totali*100):.2f}%" if pezzi_totali else "0%"
        percentuale_scarti = f"{(pezzi_scarti/pezzi_totali*100):.2f}%" if pezzi_totali else "0%"
        
        # --------------------------------------------------------------
        # 2. Retrieve defects from various tables
        # --------------------------------------------------------------
        # (A) Defects from "ribbon"
        query_ribbon = """
            SELECT tipo_difetto AS difetto, COUNT(*) AS count_scarti
            FROM ribbon
            WHERE scarto = 1 AND production_id IN (
                SELECT id FROM productions WHERE data_inizio >= %s
            )
            GROUP BY tipo_difetto
        """
        cursor.execute(query_ribbon, (start_date_str,))
        ribbon_defects = cursor.fetchall()
        
        # (B) Defects from "saldatura" (using "category" as defect type)
        query_saldatura = """
            SELECT category AS difetto, COUNT(*) AS count_scarti
            FROM saldatura
            WHERE scarto = 1 AND production_id IN (
                SELECT id FROM productions WHERE data_inizio >= %s
            )
            GROUP BY category
        """
        cursor.execute(query_saldatura, (start_date_str,))
        saldatura_defects = cursor.fetchall()
        
        # (C) Defects from "disallineamento_stringa"
        query_disallineamento = """
            SELECT 'Disallineamento Stringa' AS difetto, COUNT(*) AS count_scarti
            FROM disallineamento_stringa
            WHERE scarto = 1 AND production_id IN (
                SELECT id FROM productions WHERE data_inizio >= %s
            )
        """
        cursor.execute(query_disallineamento, (start_date_str,))
        disallineamento_defects = cursor.fetchone() or {"difetto": "Disallineamento Stringa", "count_scarti": 0}
        
        # (D) Defects from "lunghezza_string_ribbon"
        query_lunghezza = """
            SELECT 'Lunghezza String Ribbon' AS difetto, COUNT(*) AS count_scarti
            FROM lunghezza_string_ribbon
            WHERE scarto = 1 AND production_id IN (
                SELECT id FROM productions WHERE data_inizio >= %s
            )
        """
        cursor.execute(query_lunghezza, (start_date_str,))
        lunghezza_defects = cursor.fetchone() or {"difetto": "Lunghezza String Ribbon", "count_scarti": 0}
        
        # (E) Defects from "generali"
        query_generali = """
            SELECT tipo_difetto AS difetto, COUNT(*) AS count_scarti
            FROM generali
            WHERE scarto = 1 AND production_id IN (
                SELECT id FROM productions WHERE data_inizio >= %s
            )
            GROUP BY tipo_difetto
        """
        cursor.execute(query_generali, (start_date_str,))
        generali_defects = cursor.fetchall()
        
        # Merge all defects into one dictionary
        defects = {}
        def add_defects(rows):
            for row in rows:
                difetto = row['difetto']
                count = row['count_scarti']
                defects[difetto] = defects.get(difetto, 0) + count
        
        add_defects(ribbon_defects)
        add_defects(saldatura_defects)
        add_defects([disallineamento_defects])
        add_defects([lunghezza_defects])
        add_defects(generali_defects)
        
        # Create a sorted list (top 5 defects by count)
        problemi_principali = sorted(
            [{"problema": k, "numero_scarti": v} for k, v in defects.items()],
            key=lambda x: x["numero_scarti"],
            reverse=True
        )[:5]
        
        # --------------------------------------------------------------
        # 3. Trend Analysis: Compare current 7 days with the previous 7 days
        # --------------------------------------------------------------
        previous_start_date = start_date - timedelta(days=7)
        previous_start_date_str = previous_start_date.strftime('%Y-%m-%d %H:%M:%S')
        
        query_previous = """
            SELECT
                COUNT(*) AS pezzi_totali,
                SUM(CASE WHEN esito = 1 THEN 1 ELSE 0 END) AS pezzi_buoni
            FROM productions
            WHERE data_inizio >= %s AND data_inizio < %s
        """
        cursor.execute(query_previous, (previous_start_date_str, start_date_str))
        previous_totals = cursor.fetchone() or {}
        prev_totali = previous_totals['pezzi_totali'] or 0
        prev_buoni = previous_totals['pezzi_buoni'] or 0
        
        produttivita_trend = "N/A"
        if prev_totali:
            diff_prod = (pezzi_totali - prev_totali) / prev_totali * 100
            produttivita_trend = f"Aumento del {diff_prod:.1f}%" if diff_prod >= 0 else f"Riduzione del {abs(diff_prod):.1f}%"
        
        qualita_trend = "N/A"
        prev_qualita = (prev_buoni / prev_totali * 100) if prev_totali else 0
        current_qualita = (pezzi_buoni / pezzi_totali * 100) if pezzi_totali else 0
        diff_qualita = current_qualita - prev_qualita
        if prev_totali:
            qualita_trend = f"Aumento del {diff_qualita:.1f}%" if diff_qualita >= 0 else f"Riduzione del {abs(diff_qualita):.1f}%"
        
        # Close the database connection
        cursor.close()
        connection.close()
        
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})
    
    # --------------------------------------------------------------
    # 4. Build the AI prompt using the aggregated data and DB schema
    # --------------------------------------------------------------
    prompt = f"""
Sei un assistente che analizza i dati di produzione utilizzando la seguente struttura del database:
{DB_SCHEMA}

Periodo analizzato: Ultimi 7 giorni

Totali:
  - Pezzi totali: {pezzi_totali}
  - Pezzi buoni: {pezzi_buoni}
  - Pezzi scarti: {pezzi_scarti}
  - Percentuale buoni: {percentuale_buoni}
  - Percentuale scarti: {percentuale_scarti}
  - Tempo ciclo medio: {tempo_ciclo_medio} (HH:MM)

Problemi principali (top 5 difetti):
{json.dumps(problemi_principali, ensure_ascii=False, indent=2)}

Trend:
  - Produttività: {produttivita_trend}
  - Qualità: {qualita_trend}

Genera un report dettagliato in formato JSON senza testo aggiuntivo. Il report deve contenere i seguenti campi:
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
    "Osservazioni e pattern riscontrati nei dati"
  ],
  "cose_che_stanno_andando_bene": [
    "Aspetti positivi rilevati"
  ],
  "consigli_ai": [
    "Suggerimenti pratici per migliorare"
  ]
}}

Non aggiungere alcun testo extra.
    """
    
    # --------------------------------------------------------------
    # 5. Call the AI model – here we simulate its response
    # --------------------------------------------------------------
    # Replace the code below with your actual AI model call.
    # Example:
    # response = ai_model.call(prompt)
    # ai_content = response["message"]["content"]
    ai_content = json.dumps({
        "periodo_analisi": "Ultimi 7 giorni",
        "totali": {
            "pezzi_totali": pezzi_totali,
            "pezzi_buoni": pezzi_buoni,
            "pezzi_scarti": pezzi_scarti,
            "percentuale_buoni": percentuale_buoni,
            "percentuale_scarti": percentuale_scarti,
            "tempo_ciclo_medio": tempo_ciclo_medio
        },
        "problemi_principali": problemi_principali,
        "trend": {
            "produttivita": produttivita_trend,
            "qualita": qualita_trend
        },
        "analisi_approfondita": [
            "I difetti 'Disallineamento' e 'Bad Soldering' si verificano maggiormente durante il turno notturno.",
            "Esiste una correlazione tra l’aumento della produttività e una leggera riduzione della qualità."
        ],
        "cose_che_stanno_andando_bene": [
            "La linea M309 mostra buone performance con una bassa percentuale di scarti.",
            "Il tempo ciclo medio è stabile, indicando un processo produttivo regolare."
        ],
        "consigli_ai": [
            "Implementare controlli aggiuntivi durante il turno notturno per ridurre i difetti.",
            "Effettuare manutenzione preventiva sui macchinari delle linee con maggiori difetti."
        ]
    }, ensure_ascii=False)
    
    # --------------------------------------------------------------
    # 6. Validate and return the AI JSON report
    # --------------------------------------------------------------
    try:
        report_json = json.loads(ai_content)
        return report_json
    except json.JSONDecodeError:
        return JSONResponse(status_code=500, content={"error": "AI response is not valid JSON", "content": ai_content})
