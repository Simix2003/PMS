from llama_cpp import Llama
from typing import cast, Dict, Any
from datetime import datetime
import json
import requests
import re

MODEL_PATH = r"D:\AI\Models\gemma-3n-E4B-it-Q4_K_M.gguf"
N_THREADS = 4

SYSTEM_PROMPT = """
Sei Simix, un assistente tecnico per il monitoraggio della produzione industriale (PMS). Rispondi esclusivamente in italiano.

OBIETTIVO PRINCIPALE
• Generare, per ogni richiesta di visualizzazione o analisi dati, una lista di filtri JSON strutturati:
**[{"type": "TipoFiltro", "value": "Valore"}]**

DATI DISPONIBILI
• productions(id, object_id, station_id, start_time, end_time, esito, cycle_time)
• object_defects(production_id, defect_id, defect_type, ribbon_lato, photo_id)
• objects(id_modulo, creator_station_id, created_at)
• stations(name, type, line_id, config)
• defects, station_defects
• stops, stop_status_changes
• photos
• stringatrice_warnings

TIPI DI FILTRO AMMESSI (derivati da FindPage)
• Stazione
• Esito (G, NG, Escluso, In Produzione, G Operatore)
• Difetto (con sotto-tipologie: Generali, VPF, AIN, Saldatura, Disallineamento, Mancanza Ribbon, Macchie ECA, Celle Rotte, Bad Soldering, Lunghezza String Ribbon, Graffio su Cella, I Ribbon Leadwire, Altro)
• Data (giorno singolo o range, con supporto a start_time / end_time in formato ISO8601)
• Turno (1, 2, 3)
• ID Modulo
• Linea
• Operatore
• Tempo Ciclo (con condizioni: Minore Di, Minore o Uguale a, Maggiore Di, Maggiore o Uguale a, Uguale A — campo "seconds")
• Eventi (con condizioni analoghe — campo "eventi")
• Stringatrice (1, 2, 3, 4, 5)

🔁 I filtri "Tempo Ciclo" ed "Eventi" devono anche includere `condition` e `seconds` o `eventi`. Il filtro "Data" deve includere anche `start` e `end` come stringhe ISO8601.

🕒 L'AI conosce la **data e ora attuale** (es. `2025-07-09T10:00:00`) e può calcolare automaticamente riferimenti relativi come:
• "oggi" → data corrente con orario 00:00–23:59
• "ieri" → giorno precedente con 00:00–23:59
• "ultime 24 ore" → da ora-24h a ora attuale
• "questa settimana", "ultimo turno", ecc. → richiedere conferma se ambiguo

REGOLE DI COMPORTAMENTO
1. Se l’utente chiede conteggi, analisi o elenchi, restituisci solo il blocco JSON con i filtri.
2. Non scrivere testo fuori dal blocco JSON.
3. Se mancano dati essenziali (es: stazione, data, tipo difetto), chiedili direttamente.
4. Se la richiesta è troppo generale o richiede ragionamento, restituisci un piano operativo in forma di lista.

FORMATTO STANDARD
• Ogni filtro è un dizionario `{ "type": ..., "value": ... }`
• Alcuni tipi possono avere attributi aggiuntivi:
  * `Data` → anche `start`, `end` (ISO 8601)
  * `Tempo Ciclo` → anche `condition`, `seconds`
  * `Eventi` → anche `condition`, `eventi`

ESEMPI

* "Quanti NG su ELL01 ieri?"

```json
[{"type": "Stazione", "value": "ELL01"},
 {"type": "Esito", "value": "NG"},
 {"type": "Data", "value": "08 Lug 2025 – 00:00 → 08 Lug 2025 – 23:59", "start": "2025-07-08T00:00:00", "end": "2025-07-08T23:59:00"}]
```

* "Moduli con ciclo > 6s tra le 10 e le 11 di oggi su STR01"

```json
[{"type": "Stazione", "value": "STR01"},
 {"type": "Tempo Ciclo", "value": "Maggiore Di 6 secondi", "condition": "Maggiore Di", "seconds": "6"},
 {"type": "Data", "value": "09 Lug 2025 – 10:00 → 09 Lug 2025 – 11:00", "start": "2025-07-09T10:00:00", "end": "2025-07-09T11:00:00"}]
```

* "Moduli con 2 o più eventi nelle ultime 24h"

```json
[{"type": "Data", "value": "08 Lug 2025 – 10:00 → 09 Lug 2025 – 10:00", "start": "2025-07-08T10:00:00", "end": "2025-07-09T10:00:00"},
 {"type": "Eventi", "value": "Maggiore o Uguale a 2 eventi", "condition": "Maggiore o Uguale a", "eventi": "2"}]
```

* "Visualizza moduli difettosi con VPF > NG4 su linea B"

```json
[{"type": "Difetto", "value": "VPF > NG4"},
 {"type": "Linea", "value": "Linea B"}]
```

Se un filtro ha sotto-componenti (es. Difetto), puoi rappresentarlo con il valore concatenato (es: "VPF > NG3" o "Saldatura > Stringa[1] > Lato F > Pin[3]").
"""

# Load model
llm = Llama(
    model_path=MODEL_PATH,
    n_ctx=4096,
    n_threads=N_THREADS,
    n_batch=256,
    use_mlock=False,
    use_mmap=True,
    verbose=False
)

# Full warm-up with realistic context
now = datetime.now()
iso_now = now.isoformat(timespec='seconds')
date_prompt = f"Oggi è {now.strftime('%d %b %Y')} ({iso_now})."

INITIAL_PROMPT = f"<|system|>\n{SYSTEM_PROMPT}\n<|user|>\n{date_prompt}\n<|assistant|>\n"
print("⏳ Warm-up full prompt...")
_ = llm(INITIAL_PROMPT, max_tokens=1)
print("✅ Model ready.\n")

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

    response_stream = llm(prompt, max_tokens=1024, stop=["<|user|>"], stream=True)

    full_reply = ""
    for chunk in response_stream:
        chunk = cast(Dict[str, Any], chunk)
        if "choices" in chunk and len(chunk["choices"]) > 0:
            token = chunk["choices"][0]["text"]
            print(token, end="", flush=True)
            full_reply += token

    return full_reply.strip()

def try_parse_filters(reply: str):
    try:
        # Extract JSON block from markdown if present
        match = re.search(r"```json\s*(\[[\s\S]*?\])\s*```", reply)
        if match:
            reply = match.group(1)

        # Clean up any special trailing tokens like <|file_separator|>
        reply = re.sub(r"<\|.*?\|>", "", reply).strip()

        parsed = json.loads(reply)
        if isinstance(parsed, list) and all(isinstance(f, dict) and "type" in f and "value" in f for f in parsed):
            return parsed
    except Exception as e:
        print(f"❌ Errore nella chiamata all’API: {e}")
    return None

def call_search_api(filters: list, limit: int = 1000):
    payload = {
        "filters": filters,
        "limit": limit,
        "order_by": "Data",
        "order_direction": "DESC",
        "show_all_events": True
    }
    try:
        res = requests.post("http://localhost:8000/api/search", json=payload)
        return res.json()
    except Exception as e:
        print(f"❌ Errore nella chiamata all’API: {e}")
        return {"results": []}

def chat_with_simix():
    print("🤖 Chatta con Simix (CPU-only — scrivi 'esci' per uscire)\n")

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": date_prompt}
    ]

    while True:
        user_input = input("🟢 Tu: ")
        if user_input.lower() in ("esci", "exit", "quit"):
            break

        messages.append({"role": "user", "content": user_input})
        print("\nSimix: ", end="", flush=True)
        reply = get_response(messages)
        print()

        messages.append({"role": "assistant", "content": reply})

        filters = try_parse_filters(reply)
        if filters:
            print("\n🔧 Filtri JSON rilevati → chiamo `/api/search`...\n")
            results = call_search_api(filters)
            print(f"📦 {len(results.get('results', []))} risultati trovati.")
            for r in results.get("results", [])[:5]:
                latest = r["latest_event"]
                print(f"  • {r['object_id']}: {latest['station_name']} – {latest['esito']} – {latest['start_time']}")

if __name__ == "__main__":
    chat_with_simix()
