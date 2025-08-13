import asyncio
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Tuple
import logging, os, json, re
from llama_cpp import Llama
from sentence_transformers import SentenceTransformer
import faiss

router = APIRouter()
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# --- Parametri principali ---
MODEL_PATH = r"D:\AI\Models\gemma-3n-E4B-it-Q4_K_M.gguf"
DATA_PATH = r"D:\Imix\Lavori\2025\3SUN\IX-Monitor\pms\outgoing_test\fine_tuning.jsonl"
ML_MODEL = r"C:\PMS\models\fine-tuned-defects_V2"
CTX_PER_ANSWER = 5
N_THREADS = 4

# --- Caricamento modello LLM ---
class DummyLLM:
    def __call__(self, *args, **kwargs):
        return {"choices": [{"text": ""}]}

try:
    llm = Llama(model_path=MODEL_PATH, n_ctx=4096, n_threads=N_THREADS, use_mmap=True, verbose=False)
    logger.info("Modello LLM caricato correttamente.")
except Exception as e:
    logger.error(f"Errore caricamento LLM: {e}")
    llm = DummyLLM()

# --- Caricamento embeddings e indice ---
embedder = SentenceTransformer(ML_MODEL)
corpus_instructions: List[str] = []
corpus_outputs: List[str] = []

if not os.path.isfile(DATA_PATH):
    logger.error(f"File JSONL mancante: {DATA_PATH}")
else:
    with open(DATA_PATH, "r", encoding="utf-8") as f:
        for line in f:
            rec = json.loads(line)
            corpus_instructions.append(rec["instruction"])
            corpus_outputs.append(rec["output"])

if len(corpus_instructions) == 0:
    logger.error("Nessun esempio da indicizzare.")
    emb_matrix = None
    index = None
else:
    # Trasforma in embeddings
    emb_matrix = embedder.encode(corpus_instructions, batch_size=64, show_progress_bar=True).astype("float32")
    dim = emb_matrix.shape[1]
    index = faiss.IndexFlatIP(dim)  # metrica: inner product
    index.add(emb_matrix)
    logger.info(f"Indice FAISS creato con {len(corpus_instructions)} esempi (dim={dim}).")

# --- Prompt system ---
SYSTEM_PROMPT = """
Il tuo nome è Simix. Sei un ispettore virtuale per la Visual Inspection dei moduli fotovoltaici.
Rispondi facendo riferimento alle linee guida di classificazione A/B/C/Scarto.
Cita la regola o pagina se possibile.
Se non è chiaro, chiedi chiarimenti.
""".strip()

def build_prompt(user_q: str, ctx_pairs: List[Tuple[str, str]]) -> str:
    ctx_text = "\n".join(f"Q: {q}\nA: {a}" for q, a in ctx_pairs)
    prompt = (
        f"<|system|>\n{SYSTEM_PROMPT}\n<|user|>\n"
        f"{ctx_text}\n\nDomanda: {user_q}\n<|assistant|>\n"
    )
    return prompt

def rag_retrieve(query: str, k: int = CTX_PER_ANSWER) -> List[Tuple[str, str]]:
    if index is None:
        return []
    q_vec = embedder.encode([query]).astype("float32")  # shape (1, dim)
    D, I = index.search(q_vec, k)  # restituisce (distances, indici) #ignore
    return [(corpus_instructions[i], corpus_outputs[i]) for i in I[0]]

def call_llm(prompt: str) -> str:
    res = llm(prompt, max_tokens=256, stop=["<|user|>"], stream=False)
    text = ""
    if isinstance(res, dict):
        text = res.get("choices", [{}])[0].get("text", "")
    else:
        # fallback nel caso fosse un iterator
        text = "".join(r.get("choices", [{}])[0].get("text", "") for r in res)
    return re.sub(r"^```.*?```$", "", text, flags=re.S).strip()

class VIRequest(BaseModel):
    question: str

@router.post("/api/chatbot")
async def vi_answer(req: VIRequest):
    q = req.question.strip()
    if not q:
        return {"error": "Domanda vuota"}

    ctx = rag_retrieve(q)
    prompt = build_prompt(q, ctx)
    answer = call_llm(prompt)

    return {
        "question": q,
        "retrieved": [{"instruction": c[0], "output": c[1]} for c in ctx],
        "answer": answer
    }


async def main():
    test_input = "Materiale sulla cella di 10 mm"
    ctx = rag_retrieve(test_input)
    prompt = build_prompt(test_input, ctx)
    print("---- PROMPT INVIATO ----")
    print(prompt)
    print("------------------------")
    answer = call_llm(prompt)
    print("---- RISPOSTA MODELLO ----")
    print(answer)

if __name__ == "__main__":
    asyncio.run(main())