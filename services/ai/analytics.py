# analytics.py

from datetime import datetime, timedelta
from db import get_db_connection, get_production_totals, get_defects, get_previous_week_data


def analyze_production_data():
    # Calculate analysis dates
    end_date = datetime.now()
    start_date = end_date - timedelta(days=7)
    previous_start_date = start_date - timedelta(days=7)

    start_date_str = start_date.strftime('%Y-%m-%d %H:%M:%S')
    previous_start_date_str = previous_start_date.strftime('%Y-%m-%d %H:%M:%S')

    connection = get_db_connection()
    cursor = connection.cursor()

    try:
        totals = get_production_totals(cursor, start_date_str) or {}

        pezzi_totali = totals.get('pezzi_totali', 0)
        pezzi_buoni = totals.get('pezzi_buoni', 0)
        pezzi_scarti = totals.get('pezzi_scarti', 0)
        tempo_ciclo_medio_sec = totals.get('tempo_ciclo_medio_sec', 0.0)

        # Format average cycle time
        minutes = int(tempo_ciclo_medio_sec // 60)
        seconds = int(tempo_ciclo_medio_sec % 60)
        tempo_ciclo_medio = f"{minutes:02d}:{seconds:02d}"

        percentuale_buoni = f"{(pezzi_buoni / pezzi_totali * 100):.2f}%" if pezzi_totali else "0%"
        percentuale_scarti = f"{(pezzi_scarti / pezzi_totali * 100):.2f}%" if pezzi_totali else "0%"

        # Defects
        defect_rows = get_defects(cursor, start_date_str)
        defects = {}
        for row in defect_rows:
            defects[row['difetto']] = defects.get(row['difetto'], 0) + row['count_scarti']

        problemi_principali = sorted(
            [{"problema": k, "numero_scarti": v} for k, v in defects.items()],
            key=lambda x: x["numero_scarti"],
            reverse=True
        )[:5]

        # Trends
        previous_data = get_previous_week_data(cursor, start_date_str, previous_start_date_str) or {}
        prev_totali = previous_data.get('pezzi_totali', 0)
        prev_buoni = previous_data.get('pezzi_buoni', 0)

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

        return {
            "start_date_str": start_date_str,
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
            }
        }

    finally:
        cursor.close()
        connection.close()
