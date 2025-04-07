# db.py

import pymysql
from pymysql.cursors import DictCursor
from datetime import datetime, timedelta

def get_db_connection():
    return pymysql.connect(
    host='localhost',
    user='root',
    password='Master36!',
    database='production_data',
    port=3306,
    cursorclass=DictCursor,
    autocommit=False
)


def get_production_totals(cursor, start_date_str):
    cursor.execute("""
        SELECT
            COUNT(*) AS pezzi_totali,
            SUM(CASE WHEN esito = 1 THEN 1 ELSE 0 END) AS pezzi_buoni,
            SUM(CASE WHEN esito = 6 THEN 1 ELSE 0 END) AS pezzi_scarti,
            AVG(TIME_TO_SEC(tempo_ciclo)) AS tempo_ciclo_medio_sec
        FROM productions
        WHERE data_inizio >= %s
    """, (start_date_str,))
    return cursor.fetchone()


def get_defects(cursor, start_date_str):
    def query(q):  # shortcut
        cursor.execute(q, (start_date_str,))
        return cursor.fetchall()

    ribbon = query("""
        SELECT tipo_difetto AS difetto, COUNT(*) AS count_scarti
        FROM ribbon
        WHERE scarto = 1 AND production_id IN (
            SELECT id FROM productions WHERE data_inizio >= %s
        )
        GROUP BY tipo_difetto
    """)

    saldatura = query("""
        SELECT category AS difetto, COUNT(*) AS count_scarti
        FROM saldatura
        WHERE scarto = 1 AND production_id IN (
            SELECT id FROM productions WHERE data_inizio >= %s
        )
        GROUP BY category
    """)

    cursor.execute("""
        SELECT 'Disallineamento Stringa' AS difetto, COUNT(*) AS count_scarti
        FROM disallineamento_stringa
        WHERE scarto = 1 AND production_id IN (
            SELECT id FROM productions WHERE data_inizio >= %s
        )
    """, (start_date_str,))
    disallineamento = [cursor.fetchone() or {"difetto": "Disallineamento Stringa", "count_scarti": 0}]

    cursor.execute("""
        SELECT 'Lunghezza String Ribbon' AS difetto, COUNT(*) AS count_scarti
        FROM lunghezza_string_ribbon
        WHERE scarto = 1 AND production_id IN (
            SELECT id FROM productions WHERE data_inizio >= %s
        )
    """, (start_date_str,))
    lunghezza = [cursor.fetchone() or {"difetto": "Lunghezza String Ribbon", "count_scarti": 0}]

    generali = query("""
        SELECT tipo_difetto AS difetto, COUNT(*) AS count_scarti
        FROM generali
        WHERE scarto = 1 AND production_id IN (
            SELECT id FROM productions WHERE data_inizio >= %s
        )
        GROUP BY tipo_difetto
    """)

    return ribbon + saldatura + disallineamento + lunghezza + generali


def get_previous_week_data(cursor, start_date_str, previous_start_date_str):
    cursor.execute("""
        SELECT
            COUNT(*) AS pezzi_totali,
            SUM(CASE WHEN esito = 1 THEN 1 ELSE 0 END) AS pezzi_buoni
        FROM productions
        WHERE data_inizio >= %s AND data_inizio < %s
    """, (previous_start_date_str, start_date_str))
    return cursor.fetchone()
