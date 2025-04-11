import requests
import json
from datetime import datetime
from typing import Optional, Dict, Any

# Configuration
BASE_URL = "http://localhost:8000"
OLLAMA_MODEL = "gemma:2b-instruct"
OLLAMA_URL = "http://localhost:11434/api/generate"  # ✅ Default Ollama port is 11434

def format_date(date: datetime) -> str:
    return date.strftime("%Y-%m-%d")

def fetch_production_summary(
    selected_line: str,
    single_date: Optional[datetime] = None,
    range_start: Optional[datetime] = None,
    range_end: Optional[datetime] = None,
    selected_turno: int = 0
) -> Dict[str, Any]:
    if range_start and range_end:
        from_date = format_date(range_start)
        to_date = format_date(range_end)
        url = f"{BASE_URL}/api/productions_summary?from={from_date}&to={to_date}&line_name={selected_line}"
    else:
        date = format_date(single_date or datetime.now())
        url = f"{BASE_URL}/api/productions_summary?date={date}&line_name={selected_line}"

    if selected_turno != 0:
        url += f"&turno={selected_turno}"

    response = requests.get(url)
    if response.status_code == 200:
        json_map = response.json()
        for station in json_map.get('stations', {}).values():
            station.setdefault('last_object', 'No Data')
            station.setdefault('last_esito', 'No Data')
            station.setdefault('last_cycle_time', 'No Data')
            station.setdefault('last_in_time', 'No Data')
            station.setdefault('last_out_time', 'No Data')
        return json_map
    else:
        raise Exception(f"Errore durante il caricamento dei dati: {response.status_code} - {response.text}")

def build_italian_prompt(summary_data: dict) -> str:
    print("🧠 Costruzione del prompt per il modello Gemma...")
    return f"""
Agisci come un assistente AI specializzato nell'analisi della produzione industriale. Ti fornirò un riepilogo della produzione di una linea specifica, e il tuo compito è:

🧩 Ragionare passo-passo per:
1. Identificare i **difetti più frequenti**, indicando **quante volte** sono apparsi e **in quali stazioni**.
2. Calcolare per ogni stazione il **tasso di KO** = (pezzi KO / pezzi totali) e indicare le **peggiori stazioni**.
3. Individuare **tendenze** tra i turni, come difetti che aumentano o diminuiscono da un turno all'altro.
4. Rilevare **anomalie sospette**, ad esempio:
   - stazioni inattive che presentano difetti
   - stazioni con ciclo troppo veloce o troppo lento
   - difetti concentrati in un solo turno
5. Dare **raccomandazioni operative pratiche** per migliorare le stazioni problematiche.
6. Scrivere un **riassunto finale** chiaro e sintetico per il responsabile.

📊 Segui questo schema JSON esatto:

```json
{{
  "main_defects": [{{"nome": "...", "conteggio": ..., "stazione": "..."}}],
  "worst_stations": [{{"stazione": "...", "ko_percentuale": ..., "ko_count": ..., "totale": ...}}],
  "defect_trends": [{{"difetto": "...", "turno": "...", "variazione": "..."}}],
  "anomalies": ["..."],
  "recommendations": {{
    "nome_stazione": ["Suggerimento 1", "Suggerimento 2"]
  }},
  "summary": "..."
}}


Dati:
{json.dumps(summary_data, indent=2, ensure_ascii=False)}
"""


def call_ollama(prompt: str) -> dict:
    print("🤖 Invio del prompt al modello Ollama... Attendere la risposta...")
    payload = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False
    }

    response = requests.post(OLLAMA_URL, json=payload)
    if response.status_code == 200:
        try:
            raw_json = response.json()
            print("🧾 Risposta grezza:", raw_json)

            content = raw_json.get("response", "").strip()

            if not content:
                raise Exception("❌ Il modello ha risposto con un contenuto vuoto.")

            # 🔥 Remove triple backticks
            if content.startswith("```json"):
                content = content.removeprefix("```json").removesuffix("```").strip()
            elif content.startswith("```"):
                content = content.removeprefix("```").removesuffix("```").strip()

            print("✅ Risposta ricevuta dall'AI. Parsing in corso...")
            return json.loads(content)
        except Exception as e:
            raise Exception(f"❌ Errore parsing risposta AI: {e}\nContenuto: {content}")
    else:
        raise Exception(f"❌ Errore chiamata Ollama: {response.status_code} - {response.text}")



if __name__ == "__main__":
    try:
        print("🚀 Avvio analisi AI per la produzione...")
        summary = fetch_production_summary(
            selected_line="Linea2",
            single_date=datetime.strptime("2025-04-10", "%Y-%m-%d"),
            selected_turno=0
        )
        print(summary)
        prompt = build_italian_prompt(summary)
        result = call_ollama(prompt)
        print("\n--- ✅ RISPOSTA AI ---\n")
        print(json.dumps(result, indent=2, ensure_ascii=False))
    except Exception as e:
        print(f"❌ Errore: {e}")
