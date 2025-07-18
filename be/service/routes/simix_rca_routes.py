from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Dict, Any
import logging
import os
import sys
import json
import re
from llama_cpp import Llama

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

router = APIRouter()
logger = logging.getLogger(__name__)

MODEL_PATH = r"D:\AI\Models\gemma-3n-E4B-it-Q4_K_M.gguf"
N_THREADS = 4

llm = Llama(
    model_path=MODEL_PATH,
    n_ctx=4096,
    n_threads=N_THREADS,
    n_batch=256,
    use_mlock=False,
    use_mmap=True,
    verbose=False,
)

SYSTEM_PROMPT_RCA = """
Il tuo nome è Simix. Sei un assistente AI specializzato in analisi delle cause radice (RCA) per una linea di produzione di moduli fotovoltaici.
La tua funzione principale è guidare l’utente nell’identificare la causa radice di un problema attraverso la tecnica dei 5 Perché.
—
📦 CONTESTO TECNICO DELLA FABBRICA:
La linea produttiva è composta da queste stazioni principali:
1. GLASS Loader – carico del vetro
2. STR (Stringer) – saldatura delle celle
3. AIN (Bussing) – saldatura delle interconnessioni
4. MIN (Quality Gate) – controllo qualità manuale
5. MBJ – applicazione della junction box
6. RMI – Rework (rilavorazione)
7. LMN (Laminatore) – incapsulamento
8. VPF (Visual Inspection) – ispezione finale
I moduli avanzano tramite rulliere e buffer intermedi. Ogni modulo è associato a una stazione, un operatore, un tempo ciclo, ed eventuali difetti (NG).
Difetti comuni:
- NG1 – rottura vetro
- NG2 – disallineamento celle
- NG3 – saldatura mancante
- NG4 – errore etichetta
—
📌 ISTRUZIONI:
Devi SEMPRE rispondere **solo** in formato JSON, senza testo aggiuntivo o simboli.
Segui esattamente questo schema:
{
  "question": "Perché [testo della domanda]?",
  "suggestions": ["risposta 1","risposta 2","risposta 3"]
}
"""

class RCARequest(BaseModel):
    context: str
    why_chain: List[Dict[str, str]] = []


def build_prompt(case_context: str, chain: List[Dict[str, str]]) -> str:
    prompt = f"<|system|>\n{SYSTEM_PROMPT_RCA.strip()}\n<|user|>\n"
    prompt += f"Contesto: {case_context.strip()}\n\n"
    if chain:
        prompt += "Domande e risposte finora:\n"
        for idx, step in enumerate(chain, start=1):
            prompt += f"{idx}. Q: {step['q']}\n   A: {step['a']}\n"
        prompt += "\nFornisci la **prossima domanda e almeno 3 possibili risposte** in formato JSON.\n"
    else:
        prompt += "Inizia con la **prima domanda e almeno 3 possibili risposte** in formato JSON.\n"
    prompt += "<|assistant|>\n"
    return prompt


def ask_next(case_context: str, chain: List[Dict[str, str]]) -> Dict[str, Any]:
    prompt = build_prompt(case_context, chain)
    result = llm(prompt, max_tokens=512, stop=["<|user|>"])
    raw_text = result["choices"][0]["text"]
    raw_text = raw_text.replace("<|file_separator|>", "").strip()
    raw_text = re.sub(r"^```(?:json)?", "", raw_text, flags=re.IGNORECASE).strip()
    raw_text = re.sub(r"```$", "", raw_text).strip()
    try:
        raw_text = re.sub(r",\s*]", "]", raw_text)
        raw_text = re.sub(r",\s*}", "}", raw_text)
        data = json.loads(raw_text)
        question = data.get("question", "").strip()
        suggestions = [s.strip() for s in data.get("suggestions", [])]
    except Exception as e:
        logger.error(f"Failed parsing model output: {e}")
        question = "Errore nel parsing della domanda."
        suggestions = []
    return {"question": question, "suggestions": suggestions}


@router.post("/api/simix_rca/next")
async def api_next_question(req: RCARequest):
    return ask_next(req.context, req.why_chain)

