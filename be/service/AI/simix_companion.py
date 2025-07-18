from llama_cpp import Llama
from typing import List, Dict, Any
from datetime import datetime
import json
import re

MODEL_PATH = r"D:\AI\Models\gemma-3n-E4B-it-Q4_K_M.gguf"
N_THREADS = 4

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
Segui esattamente questo schema (senza mai aggiungere <|file_separator|> o testo extra):

{
  "question": "Perché [testo della domanda]?",
  "suggestions": [
    "risposta 1",
    "risposta 2",
    "risposta 3"
  ]
}
"""

# Inizializza il modello
llm = Llama(
    model_path=MODEL_PATH,
    n_ctx=4096,
    n_threads=N_THREADS,
    n_batch=256,
    use_mlock=False,
    use_mmap=True,
    verbose=False
)

def build_prompt_with_suggestions(case_context: str, why_chain: List[Dict[str, str]]) -> str:
    prompt = f"<|system|>\n{SYSTEM_PROMPT_RCA.strip()}\n<|user|>\n"
    prompt += f"Contesto: {case_context.strip()}\n\n"
    if why_chain:
        prompt += "Domande e risposte finora:\n"
        for idx, step in enumerate(why_chain, start=1):
            prompt += f"{idx}. Q: {step['q']}\n   A: {step['a']}\n"
        prompt += "\nFornisci la **prossima domanda e almeno 3 possibili risposte** in formato JSON.\n"
    else:
        prompt += "Inizia con la **prima domanda e almeno 3 possibili risposte** in formato JSON.\n"
    prompt += "<|assistant|>\n"
    return prompt

def ask_next_why_with_suggestions(case_context: str, why_chain: List[Dict[str, str]]) -> Dict[str, Any]:
    prompt = build_prompt_with_suggestions(case_context, why_chain)
    response_stream = llm(prompt, max_tokens=512, stop=["<|user|>"], stream=True)

    raw_text = ""
    print("🤖 Simix (streaming):\n")
    for chunk in response_stream:
        if isinstance(chunk, dict):
            choices = chunk.get("choices")
            if choices and isinstance(choices, list) and "text" in choices[0]:
                token = choices[0]["text"]
                raw_text += token
                print(token, end="", flush=True)
        elif isinstance(chunk, str):
            raw_text += chunk
            print(chunk, end="", flush=True)
    print("\n")

    # Clean output (remove garbage like file separators and markdown fences)
    raw_text = raw_text.replace("<|file_separator|>", "").strip()
    # Remove Markdown ```json ... ``` wrappers if present
    raw_text = re.sub(r"^```(?:json)?", "", raw_text, flags=re.IGNORECASE).strip()
    raw_text = re.sub(r"```$", "", raw_text).strip()

    # Try to parse JSON
    try:
        # Fix potential trailing commas
        raw_text = re.sub(r",\s*]", "]", raw_text)
        raw_text = re.sub(r",\s*}", "}", raw_text)
        data = json.loads(raw_text)
        question = data.get("question", "").strip()
        suggestions = [s.strip() for s in data.get("suggestions", [])]
    except Exception:
        question = "Errore nel parsing della domanda."
        suggestions = []


    return {"question": question, "suggestions": suggestions}

def run_rca_chat():
    print("\n🧠 Avvio Simix RCA (5 Why) con suggerimenti AI (output JSON)\n")
    case_context = input("📌 Inserisci contesto (es: NG2 su STR01, modulo #1234...):\n> ").strip()
    why_chain = []

    while True:
        print("\n🟦 Simix sta pensando alla prossima domanda e suggerimenti...\n")
        result = ask_next_why_with_suggestions(case_context, why_chain)
        next_q = result["question"]
        suggestions = result["suggestions"]

        print(f"🔵 {next_q}")
        if suggestions:
            print("📋 Suggerimenti AI:")
            for i, s in enumerate(suggestions, start=1):
                print(f"  {i}. {s}")
        
        user_input = input("🟢 Scrivi la risposta oppure digita il numero del suggerimento (Enter per uscire):\n> ").strip()

        if user_input == "":
            break
        elif user_input.isdigit() and 1 <= int(user_input) <= len(suggestions):
            selected = suggestions[int(user_input) - 1]
            print(f"✅ Hai selezionato: {selected}")
            why_chain.append({"q": next_q, "a": selected})
        else:
            why_chain.append({"q": next_q, "a": user_input})

    print("\n✅ Catena completa 5 Why:\n")
    for idx, step in enumerate(why_chain, start=1):
        print(f"{idx}. {step['q']}")
        print(f"   ↳ {step['a']}")
    print("\n💾 (In futuro: salveremo questa RCA nel database.)")

if __name__ == "__main__":
    run_rca_chat()
