import os
import logging
from llama_cpp import Llama
from typing import cast, Dict, Any

# === Configurazione ===
MODEL_PATH = r"D:\AI\Models\gemma-3n-E4B-it-Q4_K_M.gguf"
N_THREADS = 4
MODEL_AVAILABLE = True

# === System prompt iniziale (Simix) ===
SYSTEM_PROMPT = (
    "Tu sei Simix, un assistente AI dedicato alla postazione Outgoing di controllo qualità. "
    "Il tuo compito è aiutare l'operatore a decidere se un modulo fotovoltaico è accettabile, "
    "va declassato o scartato, in base al manuale difetti. Rispondi sempre in italiano, "
    "in modo tecnico e sintetico. Se possibile, fornisci riferimenti al tipo di difetto, "
    "alle soglie di accettabilità, e alle pagine del manuale. Non inventare mai risposte: "
    "se non sei sicuro, invita l'utente a consultare il responsabile qualità."
)

# === Logger ===
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# === Dummy fallback ===
class DummyLLM:
    def __call__(self, *args, **kwargs):
        logger.error("AI model is not available.")
        return {"choices": [{"text": ""}]}

# === Caricamento modello ===
try:
    if not os.path.isfile(MODEL_PATH):
        raise FileNotFoundError(f"Model file not found: {MODEL_PATH}")
    logger.info(f"Loading model from: {MODEL_PATH} (threads={N_THREADS})...")
    llm = Llama(
        model_path=MODEL_PATH,
        n_ctx=4096,
        n_threads=N_THREADS,
        n_batch=256,
        use_mlock=False,
        use_mmap=True,
        verbose=False,
    )
    logger.info("Model loaded successfully.")
except Exception as e:
    logger.error(f"Error loading model: {e}")
    llm = DummyLLM()
    MODEL_AVAILABLE = False

# === Funzione con streaming ===
def chat_with_model(user_prompt: str) -> str:
    if not MODEL_AVAILABLE:
        return "[MODEL NOT AVAILABLE]"

    # Prompt completo con system prompt solo all'inizio
    full_prompt = f"""<start_of_turn>user
{SYSTEM_PROMPT}

{user_prompt}<end_of_turn>
<start_of_turn>model
"""

    response = ""
    for chunk in llm(
        prompt=full_prompt,
        max_tokens=512,
        temperature=0.7,
        top_k=50,
        top_p=0.9,
        stop=["<end_of_turn>"],
        stream=True,
    ):
        chunk = cast(Dict[str, Any], chunk)
        token = chunk["choices"][0]["text"]
        print(token, end="", flush=True)
        response += token

    print()
    return response.strip()

# === Loop interattivo ===
if __name__ == "__main__":
    print("🔁 Scrivi una domanda per Simix (digita 'exit' per uscire)\n")

    try:
        while True:
            user_input = input("🧾 Tu: ")
            if user_input.strip().lower() in {"exit", "quit"}:
                print("👋 Uscita.")
                break

            response = chat_with_model(user_input)
            print("🤖 Simix:", response)
            print()

    except KeyboardInterrupt:
        print("\n👋 Interrotto dall'utente.")
