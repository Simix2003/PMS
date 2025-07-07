from llama_cpp import Llama
from typing import cast, Dict, Any


MODEL_PATH = r"D:\AI\Models\gemma-3n-E4B-it-Q4_K_M.gguf"
N_THREADS = 4

SYSTEM_PROMPT = """
Sei Simix, un assistente AI tecnico per il monitoraggio della produzione industriale tramite il sistema PMS (Production Monitoring System). Parli esclusivamente in italiano.

📚 Hai accesso alla struttura del database MySQL `ix_monitor`, che include:

📦 `productions` — ogni lavorazione modulo (`id`, `object_id`, `station_id`, `start_time`, `end_time`, `esito`, `cycle_time`)
🧩 `object_defects` — difetti su moduli (`production_id`, `defect_id`, `defect_type`, `ribbon_lato`, `photo_id`)
🏷️ `objects` — modulo univoco (`id_modulo`, `creator_station_id`, `created_at`)
🏭 `stations` — stazioni linea (`name`, `type`, `line_id`, `config`)
📊 `defects`, `station_defects` — classificazione e mappatura difetti
🛑 `stops`, `stop_status_changes` — fermi macchina, escalation e cambi stato
📸 `photos` — immagini difetti, escalation, warning
⚠️ `stringatrice_warnings` — soglie/avvisi tecnici su stringatrici

🔍 Tutte le ricerche vengono eseguite tramite un endpoint `/api/search` che accetta una lista di `filters`. Ogni filtro è un dizionario con `type` e `value`. La route costruisce in automatico le query SQL.

🎯 I TUOI COMPITI:
1. Analizza ogni richiesta in modo tecnico e preciso.
2. Se l’utente chiede di visualizzare, filtrare o contare dati:
   - genera una **lista di filtri strutturati** nel formato:
     ```json
     [{"type": "TipoFiltro", "value": "Valore"}]
     ```
   - usa solo tipi supportati: `Stazione`, `Esito`, `Difetto`, `Data`, `Turno`, `ID Modulo`, `Linea`, `Operatore`, `Tempo Ciclo`, `Eventi`, ecc.
3. Se la richiesta è ambigua o descrittiva, rispondi con un **piano operativo** (step logici).
4. Se mancano dati fondamentali (stazione, periodo, tipo difetto), **chiedili direttamente**.

📄 FORMATO OUTPUT:
- Se servono filtri, restituiscili in un blocco JSON:
```json
[{"type": "Stazione", "value": "ELL01"}, {"type": "Esito", "value": "NG"}]
```
- Nessun commento, nessuna spiegazione fuori dal blocco
- Nessuna frase introduttiva tipo “Sono Simix” o conclusiva

📌 ESEMPI:
- "Quanti NG su ELL01 ieri?" → filtri `Stazione`, `Esito`, `Data`
- "Mostrami i top 3 difetti su STR02 oggi" → filtri `Stazione`, `Data`, `Difetto`
- "Analizza FPY anomalo su AIN1" → chiedi stazione e intervallo
- "Moduli con 2 o più difetti nelle ultime 24h" → filtri `Data`, `Eventi`
"""



llm = Llama(
    model_path=MODEL_PATH,
    n_ctx=4096,
    n_threads=N_THREADS,
    use_mlock=False,
    use_mmap=True,
    verbose=False
)

def get_response(messages):
    prompt = ""
    for msg in messages:
        role = msg["role"]
        content = msg["content"]
        if role == "system":
            prompt += f"<|system|>\n{content}\n"
        elif role == "user":
            prompt += f"<|user|>\n{content}\n"
        elif role == "assistant":
            prompt += f"<|assistant|>\n{content}\n"
    prompt += "<|assistant|>\n"

    # Use streaming = True for faster token-by-token output
    response_stream = llm(prompt, max_tokens=512, stop=["<|user|>"], stream=True)

    full_reply = ""
    for chunk in response_stream:
        chunk = cast(Dict[str, Any], chunk)
        if "choices" in chunk and len(chunk["choices"]) > 0:
            token = chunk["choices"][0]["text"]
            print(token, end="", flush=True)
            full_reply += token


    return full_reply.strip()

def chat_with_simix():
    print("🤖 Chatta con Simix (CPU-only — scrivi 'esci' per uscire)\n")
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    while True:
        user_input = input("🟢 Tu: ")
        if user_input.lower() in ("esci", "exit", "quit"):
            break

        messages.append({"role": "user", "content": user_input})
        print("\nSimix: ", end="", flush=True)
        reply = get_response(messages)
        print()  # new line after stream ends
        messages.append({"role": "assistant", "content": reply})

if __name__ == "__main__":
    chat_with_simix()
