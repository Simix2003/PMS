from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from typing import List, Dict, Any
import logging
import os
import sys
import json
import re
from collections.abc import Iterator
from llama_cpp import Llama

sys.path.append(os.path.dirname(os.path.dirname(__file__)))

router = APIRouter()
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

MODEL_PATH = r"D:\AI\Models\gemma-3n-E4B-it-Q4_K_M.gguf"
N_THREADS = 4
MODEL_AVAILABLE = True

class DummyLLM:
    def __call__(self, *args, **kwargs):
        logger.error("Attempted to use AI model but it is unavailable.")
        return {"choices": [{"text": ""}]}  # Always empty

try:
    if not os.path.isfile(MODEL_PATH):
        raise FileNotFoundError(f"Model file not found: {MODEL_PATH}")
    logger.info(f"Loading Llama model from: {MODEL_PATH} (threads={N_THREADS})...")
    llm = Llama(
        model_path=MODEL_PATH,
        n_ctx=4096,
        n_threads=N_THREADS,
        n_batch=256,
        use_mlock=False,
        use_mmap=True,
        verbose=False,
    )
    logger.info("Llama model loaded successfully.")
except Exception as e:
    logger.error(f"Failed to load AI model: {e}")
    llm = DummyLLM()
    MODEL_AVAILABLE = False

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
  "suggestions": ["possibile causa 1","possibile causa 2","possibile causa 3"]
}
Le voci in "suggestions" DEVONO essere **possibili spiegazioni o cause**, non nuove domande.
"""

SYSTEM_PROMPT_SUMMARY = """
Il tuo nome è Simix. Sei un assistente AI che deve solo creare un breve riassunto finale della catena dei 5 Perché.
Non scrivere JSON, non ripetere le domande o risposte.
Rispondi solo con un testo semplice in italiano che spiega la causa radice individuata.
"""


class RCARequest(BaseModel):
    context: str
    why_chain: List[Dict[str, str]] = []

def build_summary_prompt(case_context: str, chain: List[Dict[str, str]]) -> str:
    logger.debug("Building summary prompt for Simix RCA...")
    prompt = f"<|system|>\n{SYSTEM_PROMPT_SUMMARY.strip()}\n<|user|>\n"
    prompt += f"Contesto: {case_context.strip()}\n\n"
    prompt += "Domande e risposte finali:\n"
    for idx, step in enumerate(chain[:5], start=1):
        prompt += f"{idx}. Q: {step['q']}\n   A: {step['a']}\n"
    prompt += "\nFornisci SOLO un breve riassunto in italiano della catena, evidenziando la causa radice.\n"
    prompt += "<|assistant|>\n"
    return prompt

def summarize_chain(case_context: str, chain: List[Dict[str, str]]) -> str:
    if not MODEL_AVAILABLE:
        logger.warning("AI model unavailable — cannot generate summary.")
        return "Il modello AI non è disponibile. Controllare il server."

    prompt = build_summary_prompt(case_context, chain)
    try:
        result = llm(prompt, max_tokens=512, stop=["<|user|>"], stream=True)
    except Exception as e:
        logger.exception(f"Error calling LLM for summary: {e}")
        return "Errore nella generazione del riassunto."

    raw_text = extract_text_from_result(result)
    raw_text = raw_text.replace("<|file_separator|>", "").strip()
    raw_text = re.sub(r"^```(?:json)?", "", raw_text, flags=re.IGNORECASE).strip()
    raw_text = re.sub(r"```$", "", raw_text).strip()
    return raw_text.strip()

def build_prompt(case_context: str, chain: List[Dict[str, str]]) -> str:
    logger.debug("Building prompt for Simix RCA...")
    logger.debug(f"Context: {case_context}")
    logger.debug(f"Why-chain: {json.dumps(chain, ensure_ascii=False)}")

    prompt = f"<|system|>\n{SYSTEM_PROMPT_RCA.strip()}\n<|user|>\n"
    prompt += f"Contesto: {case_context.strip()}\n\n"
    if chain:
        prompt += "Domande e risposte finora:\n"
        for idx, step in enumerate(chain, start=1):
            prompt += f"{idx}. Q: {step['q']}\n   A: {step['a']}\n"
        prompt += (
                "\nFornisci la **prossima domanda (iniziando con 'Perché')** e almeno 3 "
                "**possibili spiegazioni (cause)** in formato JSON, seguendo lo schema richiesto. "
                "Non generare domande nelle 'suggestions', ma solo cause.\n"
            )
    else:
        prompt += "Inizia con la **prima domanda e almeno 3 possibili spiegazioni (cause)** in formato JSON, seguendo lo schema richiesto.*\n"
    prompt += "<|assistant|>\n"

    logger.debug(f"Built prompt (first 500 chars): {prompt[:500]}...")
    return prompt

def extract_text_from_result(result):
    """Handles both streaming (Iterator) and normal Llama responses."""
    if isinstance(result, Iterator):
        logger.debug("Result is a streaming iterator; collecting chunks...")
        collected = []
        for chunk in result:
            piece = chunk.get("choices", [{}])[0].get("text", "")
            collected.append(piece)
        return "".join(collected)
    else:
        return result.get("choices", [{}])[0].get("text", "")

def ask_next(case_context: str, chain: List[Dict[str, str]]) -> Dict[str, Any]:
    if not MODEL_AVAILABLE:
        logger.warning("AI model unavailable — cannot generate RCA question.")
        return {"error": "AI model non disponibile. Controllare configurazione."}
    
    if len(chain) >= 5:
        summary = summarize_chain(case_context, chain)
        return {"summary": summary}

    prompt = build_prompt(case_context, chain)

    logger.info("Querying Llama model for RCA question...")
    try:
        # Set `stream=False` unless you explicitly want streaming
        result = llm(prompt, max_tokens=512, stop=["<|user|>"], stream=True)
        logger.debug(f"Raw LLM result object: {result}")
    except Exception as e:
        logger.exception(f"Error calling LLM: {e}")
        return {"question": "Errore durante la generazione della domanda.", "suggestions": []}

    raw_text = extract_text_from_result(result)
    logger.debug(f"Raw model text before cleaning: {raw_text}")

    # Cleanup
    raw_text = raw_text.replace("<|file_separator|>", "").strip()
    raw_text = re.sub(r"^```(?:json)?", "", raw_text, flags=re.IGNORECASE).strip()
    raw_text = re.sub(r"```$", "", raw_text).strip()
    logger.debug(f"Model text after cleanup: {raw_text}")

    try:
        # Fix trailing commas
        raw_text = re.sub(r",\s*]", "]", raw_text)
        raw_text = re.sub(r",\s*}", "}", raw_text)
        logger.debug(f"Final JSON candidate: {raw_text}")

        data = json.loads(raw_text)
        question = data.get("question", "").strip()
        suggestions = [s.strip() for s in data.get("suggestions", [])]
        logger.info(f"Generated question: {question}")
        logger.info(f"Suggestions: {suggestions}")
    except Exception as e:
        logger.exception(f"Failed parsing model output: {e}")
        question = "Errore nel parsing della domanda."
        suggestions = []

    return {"question": question, "suggestions": suggestions}

@router.post("/api/simix_rca/next")
async def api_next_question(req: RCARequest):
    if not MODEL_AVAILABLE:
        return {"error": "AI model non disponibile. Controllare configurazione."}
    
    logger.info(f"Received RCA request: context='{req.context}' (chain length={len(req.why_chain)})")
    result = ask_next(req.context, req.why_chain)
    logger.info(f"Returning RCA result: {result}")
    return result


@router.websocket("/ws/simix_rca")
async def websocket_next_question(websocket: WebSocket):
    await websocket.accept()
    if not MODEL_AVAILABLE:
        await websocket.send_text("[[ERROR]] Modello AI non disponibile. Controllare configurazione.")
        await websocket.send_text("[[END]]")
        await websocket.close()
        return
    try:
        payload = await websocket.receive_json()
        context = payload.get("context", "")
        chain = payload.get("why_chain", [])

        # Choose correct prompt based on chain length
        if len(chain) > 2:
            prompt = build_summary_prompt(context, chain)
        else:
            prompt = build_prompt(context, chain)

        collected = []
        for chunk in llm(prompt, max_tokens=512, stop=["<|user|>"], stream=True):
            if isinstance(chunk, dict):
                token = chunk.get("choices", [{}])[0].get("text", "")
            elif isinstance(chunk, str):
                token = chunk
            else:
                token = ""
            if token:
                collected.append(token)
                # Stream live text to frontend (buffer display)
                await websocket.send_text(token)

        # Combine full output from model
        full_text = "".join(collected)
        full_text = full_text.replace("<|file_separator|>", "").strip()
        full_text = re.sub(r"^```(?:json)?", "", full_text, flags=re.IGNORECASE).strip()
        full_text = re.sub(r"```$", "", full_text).strip()

        if len(chain) > 2:
            clean_summary = full_text.strip()
            payload = json.dumps({"summary": clean_summary})
        else:
            full_text = re.sub(r",\s*]", "]", full_text)
            full_text = re.sub(r",\s*}", "}", full_text)
            payload = full_text

        await websocket.send_text(f"[[JSON]]{payload}")
        await websocket.send_text("[[END]]")

    except WebSocketDisconnect:
        logger.debug("Simix RCA websocket disconnected")
    except Exception as e:
        logger.exception(f"Simix RCA websocket error: {e}")
    finally:
        await websocket.close()
