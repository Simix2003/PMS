import pymysql
from pymysql.cursors import DictCursor
from datetime import datetime

# Connect to MySQL
conn = pymysql.connect(
    host="localhost",
    user="root",
    # password="Master36!",  # Uncomment and use securely
    database="production_data",
    port=3306,
    cursorclass=DictCursor,
    autocommit=False
)

cursor = conn.cursor()

# Select all rows with NULL tempo_ciclo
cursor.execute("""
    SELECT id, data_inizio, data_fine 
    FROM productions 
    WHERE tempo_ciclo IS NULL AND data_inizio IS NOT NULL AND data_fine IS NOT NULL
""")

rows = cursor.fetchall()

for row in rows:
    id = row['id']
    data_inizio = row['data_inizio']
    data_fine = row['data_fine']

    if data_inizio and data_fine:
        # Calculate tempo_ciclo
        tempo_ciclo = data_fine - data_inizio
        tempo_ciclo_str = str(tempo_ciclo).split('.')[0]  # Format as HH:MM:SS

        print(f"Updating ID {id} with tempo_ciclo = {tempo_ciclo_str}")

        # Update the row
        cursor.execute("""
            UPDATE productions
            SET tempo_ciclo = %s
            WHERE id = %s
        """, (tempo_ciclo_str, id))

# Commit changes and close connection
conn.commit()
cursor.close()
conn.close()
print("✅ All updates completed.")
