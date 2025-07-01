import requests
import pymysql
import re

OLLAMA_API_URL = "http://localhost:11434/api/chat"
MODEL_NAME = "gemma3n:e2b"

# === Load schema.sql ===
with open("D:/Imix/Lavori/2025/3SUN/IX-Monitor/pms/be/service/schema.sql", "r", encoding="utf-8") as f:
    schema_content = f.read()

# === System prompt ===
SYSTEM_PROMPT = f"""
Sei Simix, un assistente AI esperto nel monitoraggio della produzione industriale.
Parli esclusivamente in italiano. Ragiona in modo logico e strutturato.
Hai accesso a uno schema SQL del database PMS, che è il seguente:

{schema_content}

Quando ricevi una domanda basata sui dati, scrivi una query SQL tra i tag <sql></sql>.
Esempio:
<sql>
SELECT COUNT(*) FROM productions WHERE status = 'NG';
</sql>
"""

# === MySQL connector ===
def run_query(sql):
    conn = pymysql.connect(
        host="localhost",
        user="root",
        password="Master36!",   # ← Change this
        database="ix_monitor"             # ← Change this
    )
    cur = conn.cursor()
    cur.execute(sql)
    rows = cur.fetchall()
    columns = [desc[0] for desc in cur.description]
    cur.close()
    conn.close()
    return columns, rows

# === Extract SQL block from response ===
def extract_sql(text):
    match = re.search(r"<sql>(.*?)</sql>", text, re.DOTALL | re.IGNORECASE)
    return match.group(1).strip() if match else None

# === Main chat loop ===
def chat_with_simix():
    print("🇮🇹 Chatta con Simix (scrivi 'esci' per uscire)\n")

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT}
    ]

    while True:
        user_input = input("Tu: ")
        if user_input.lower() in ("esci", "exit", "quit"):
            break

        messages.append({"role": "user", "content": user_input})

        response = requests.post(OLLAMA_API_URL, json={
            "model": MODEL_NAME,
            "messages": messages,
            "stream": False
        }, timeout=30)

        if response.status_code != 200:
            print("❌ Errore nella comunicazione con Simix:", response.text)
            break

        reply = response.json()["message"]["content"]
        messages.append({"role": "assistant", "content": reply})
        print(f"\nSimix:\n{reply}\n")

        # Detect and run SQL
        sql_code = extract_sql(reply)
        if sql_code:
            print("📥 SQL rilevato. Esecuzione in corso...\n")
            try:
                columns, rows = run_query(sql_code)
                print("📊 Risultato SQL:")
                print(" | ".join(columns))
                for row in rows:
                    print(" | ".join(map(str, row)))
                # Feed results back to Simix
                messages.append({
                    "role": "user",
                    "content": f"Risultati della query SQL:\n{columns}\n{rows}"
                })
            except Exception as e:
                print("❌ Errore SQL:", e)
                messages.append({
                    "role": "user",
                    "content": f"Errore nell'esecuzione della query: {e}"
                })

if __name__ == "__main__":
    chat_with_simix()
