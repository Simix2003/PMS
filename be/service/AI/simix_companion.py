from llama_cpp import Llama
from typing import cast, Dict, Any, List, Optional
from datetime import datetime, timedelta
import json
import os
import sys

# Setup del path per importare i moduli interni
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.append(BASE_DIR)

from service.helpers.visual_helper import compute_zone_snapshot, get_shift_label

MODEL_PATH = r"D:\AI\Models\gemma-3n-E4B-it-Q4_K_M.gguf"
N_THREADS = 4
team = 'A'

# Load LLM
llm = Llama(
    model_path=MODEL_PATH,
    n_ctx=4096,
    n_threads=N_THREADS,
    n_batch=256,
    use_mlock=False,
    use_mmap=True,
    verbose=False
)

# ──────────────────────────────────────────────────────────────
# 📦 Funzione per ridurre i dati da passare al prompt
def minify_snapshot_for_prompt(snapshot: Dict[str, Any], zone: str) -> Dict[str, Any]:
    return {
        "zone": zone,
        "yield_station_1": snapshot.get("station_1_yield"),
        "yield_station_2": snapshot.get("station_2_yield"),
        "ng_station_1": snapshot.get("station_1_out_ng"),
        "ng_station_2": snapshot.get("station_2_out_ng"),
        "top_defects_qg2": snapshot.get("top_defects_qg2", []),
        "main_stops": snapshot.get("fermi_data", [])[:3],  # Primi 3 fermi
    }

# 🎯 Prompt base per Simix (solo fatti)
SYSTEM_PROMPT = """
Sei Simix, un ingegnere virtuale per il monitoraggio della produzione industriale (PMS).
Lavori come uno "Shadow Engineer": analizzi silenziosamente i dati di produzione e **parli solo quando rilevi fatti concreti e anomali**.

Il tuo compito è analizzare i dati dell’ultima ora di produzione, suddivisi per zona (es. ELL, AIN, VPF, STR), tenendo conto del giorno, del turno e della squadra attiva.
Se trovi scostamenti numerici, cali di rendimento, ripetizioni sospette o sbilanciamenti produttivi, **genera una NOTIFICA tecnica basata solo su fatti**.

❌ Non fare supposizioni.  
❌ Non fornire cause probabili o consigli.  
✅ Riporta solo anomalie misurabili, evidenti nei dati forniti.

Se tutto è regolare, rispondi esattamente con:

"NESSUNA NOTIFICA"

---

🔍 COSA OSSERVARE (solo se rilevabile nei dati):

1. **Yield (%) basso o in calo rispetto alla media**
2. **Aumento anomalo dei moduli NG**
3. **Difetti dominanti** (es. 1 difetto >70% dei NG)
4. **Zone con produttività molto diversa**
5. **Pattern ripetitivi nel tempo (stesso difetto in stessi orari o turni)**

---

📢 FORMATTO RISPOSTA SE C'È UNA NOTIFICA:

Ogni notifica deve essere **concisa, oggettiva e tecnica**. Massimo 3 righe.  
Non usare aggettivi soggettivi. Evita commenti interpretativi.

Esempi:

📍 Zona AIN ha un yield al 61.4%, -22% rispetto alla media del turno.  
📍 Su ELL rilevati 38 moduli NG in un’ora, valore fuori scala rispetto alla media oraria.  
📍 NG4 rappresenta il 72% dei difetti su VPF nell’ultima ora.

---

Se i dati non mostrano nessun problema reale o anomalia oggettiva,  
scrivi soltanto:

"NESSUNA NOTIFICA"
"""


# ──────────────────────────────────────────────────────────────
def format_prompt(payload: Dict[str, Any]) -> str:
    header = json.dumps({
        "date": payload["date"],
        "shift": payload["shift"],
        "team": payload["team"]
    }, ensure_ascii=False)
    zones = json.dumps(payload["zones"], indent=2, ensure_ascii=False)
    return (
        f"<|system|>\n{SYSTEM_PROMPT}\n"
        f"<|user|>\nDati di contesto: {header}\n"
        f"Dati zone (ultima ora):\n{zones}\n"
        f"<|assistant|>\n"
    )

# ──────────────────────────────────────────────────────────────
def get_simix_response(prompt: str) -> str:
    response_stream = llm(prompt, max_tokens=512, stop=["<|user|>"], stream=True)
    full_reply = ""
    for chunk in response_stream:
        chunk = cast(Dict[str, Any], chunk)
        if "choices" in chunk and len(chunk["choices"]) > 0:
            full_reply += chunk["choices"][0]["text"]
    return full_reply.strip()

# ──────────────────────────────────────────────────────────────
def run_simix_companion(zones_list: Optional[List[str]] = None) -> None:
    if zones_list is None:
        zones_list = ["AIN"]  # solo AIN per test, puoi rimettere ["ELL", "AIN", "VPF"] dopo

    now = datetime.now() - timedelta(days=3)
    date_str = now.date().isoformat()
    shift = get_shift_label(now)

    zones_payload = []
    for z in zones_list:
        snapshot = compute_zone_snapshot(z, now)
        minified = minify_snapshot_for_prompt(snapshot, z)
        zones_payload.append(minified)

    payload = {
        "date": date_str,
        "shift": shift,
        "team": team,
        "zones": zones_payload
    }

    print(payload)

    prompt = format_prompt(payload)
    reply = get_simix_response(prompt)

    if reply.lower().strip() == "nessuna notifica":
        print("✅ Tutto regolare. Nessuna notifica.")
    else:
        print("📢 NOTIFICA INTELLIGENTE:\n", reply)

# ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    run_simix_companion()
