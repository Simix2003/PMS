import requests
import json
import subprocess
from typing import Optional

# Configuration
SUMMARY_API_URL = "http://localhost:8000/api/productions_summary"
OLLAMA_MODEL = "gemma:2b-instruct"
OLLAMA_URL = "http://localhost:11434/api/generate"  # ✅ Default Ollama port is 11434

def get_summary(date: Optional[str], turno: Optional[int] = None, line: Optional[str] = None):
    if date is None:
        raise ValueError("Il parametro 'date' è obbligatorio.")

    params = {"date": str(date)}
    if turno is not None:
        params["turno"] = str(turno)
    if line is not None:
        params["line_name"] = str(line)

    print("📥 Recupero dati di produzione dalla API...")
    response = requests.get(SUMMARY_API_URL, params=params)
    if response.status_code == 200:
        print("✅ Dati ricevuti con successo.")
        return response.json()
    else:
        raise Exception(f"❌ Errore chiamata API summary: {response.status_code} - {response.text}")


def build_italian_prompt(summary_data: dict) -> str:
    print("🧠 Costruzione del prompt per l'AI...")
    return f"""
Sei un assistente AI per il monitoraggio della produzione in fabbrica. Analizza i seguenti dati riepilogativi della produzione e fornisci:

1. I difetti principali e le stazioni in cui si presentano più spesso.
2. Le stazioni con il tasso di KO più alto.
3. Correlazioni sospette (es. KO solo in turno 3 o con last_station_id specifico).
4. Raccomandazioni operative per i responsabili.

Rispondi in JSON con le seguenti chiavi:
- main_defects
- worst_station
- ko_trend
- anomalies
- recommendations

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
            content = response.json()["response"].strip()
            print("✅ Risposta ricevuta dall'AI. Parsing in corso...")
            return json.loads(content)
        except Exception as e:
            raise Exception(f"❌ Errore parsing risposta AI: {e}\nContenuto: {content}")
    else:
        raise Exception(f"❌ Errore chiamata Ollama: {response.status_code} - {response.text}")


if __name__ == "__main__":
    # Esempio di esecuzione
    try:
        print("🚀 Avvio analisi AI per la produzione...")
        summary = get_summary(date="2025-04-08", turno=3)
        prompt = build_italian_prompt(summary)
        result = call_ollama(prompt)
        print("\n--- ✅ RISPOSTA AI ---\n")
        print(json.dumps(result, indent=2, ensure_ascii=False))
    except Exception as e:
        print(f"❌ Errore: {e}")
