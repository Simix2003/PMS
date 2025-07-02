import requests
import json
import os

OLLAMA_API_URL = "http://localhost:11434/api/chat"
MODEL_NAME = "gemma3n:e2b"
SCHEMA_FILE = r"be\service\schema.sql"

SYSTEM_PROMPT = """
Sei Simix, un assistente AI esperto nel monitoraggio della produzione industriale.
Parli esclusivamente in italiano. Ragiona in modo logico e strutturato.
Hai accesso a uno schema SQL del database che descrive il sistema produttivo (PMS).
Quando rispondi, sii chiaro, sintetico e tecnico. Fornisci analisi, insight o risposte basate sui dati.

Segui SEMPRE questi due passaggi:
1. Prima genera un piano ragionato a step, spiegando cosa farai.
2. Poi, se richiesto, esegui i passi e dai la risposta finale.

Se non hai abbastanza contesto, chiedi informazioni aggiuntive prima di rispondere.
"""

def stream_response(messages):
    with requests.post(OLLAMA_API_URL, json={
        "model": MODEL_NAME,
        "messages": messages,
        "stream": True
    }, stream=True) as response:
        if response.status_code != 200:
            print("\n❌ Errore:", response.text)
            return ""

        full_reply = ""
        for line in response.iter_lines():
            if line:
                data = json.loads(line)
                chunk = data.get("message", {}).get("content", "")
                full_reply += chunk
                print(chunk, end="", flush=True)
        print("\n")
        return full_reply

def inject_sql_context_if_needed(messages):
    # Evita reinvio multiplo dello schema
    if not any("CREATE TABLE" in m["content"] for m in messages if m["role"] == "user"):
        if os.path.exists(SCHEMA_FILE):
            with open(SCHEMA_FILE, "r", encoding="utf-8") as f:
                schema_sql = f.read()
                print('Schema read, len:', len(schema_sql))

            messages.append({
                "role": "user",
                "content": f"Ecco lo schema SQL del database PMS:\n\n{schema_sql}"
            })

            messages.append({
                "role": "user",
                "content": "Nel PMS, la tabella principale della produzione è `productions`, e il campo da usare per filtrare per data è `productions.timestamp`."
            })
        else:
            print("⚠️ File schema.sql non trovato — Simix potrebbe chiedere contesto.")

def chat_with_simix():
    print("🇮🇹 Chatta con Simix (scrivi 'esci' per uscire)\n")

    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    while True:
        user_input = input("Tu: ")
        if user_input.lower() in ("esci", "exit", "quit"):
            break

        inject_sql_context_if_needed(messages)

        # --- PHASE 1: Reasoning Plan ---
        messages.append({"role": "user", "content": user_input})
        print("\n🧠 Piano di ragionamento:\nSimix: ", end="", flush=True)
        plan = stream_response(messages)
        messages.append({"role": "assistant", "content": plan})

        # --- PHASE 2: Execute Plan ---
        proceed = input("👉 Vuoi che Simix esegua il piano? (s/n): ").lower()
        if proceed == "s":
            exec_prompt = "Esegui ora il piano passo per passo, come descritto sopra."
            messages.append({"role": "user", "content": exec_prompt})
            print("\n⚙️ Risultato:\nSimix: ", end="", flush=True)
            result = stream_response(messages)
            messages.append({"role": "assistant", "content": result})

if __name__ == "__main__":
    chat_with_simix()

#3SBHBGHC25700769