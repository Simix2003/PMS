import requests
import json

OLLAMA_API_URL = "http://localhost:11434/api/chat"
MODEL_NAME = "gemma3n:e2b"

SYSTEM_PROMPT = """
Sei Simix, un assistente AI esperto nel monitoraggio della produzione industriale.
Parli esclusivamente in italiano. Ragiona in modo logico e strutturato.
Quando rispondi, sii chiaro, sintetico e tecnico. Fornisci analisi, insight o risposte basate sui dati.

Segui SEMPRE questi due passaggi:
1. Genera un piano ragionato a step, spiegando cosa faresti.
2. Aspetta istruzioni prima di eseguire qualsiasi passo.

Non eseguire nulla, limitati a parlare e pianificare. Se mancano informazioni, chiedile.
"""

def stream_response(messages):
    with requests.post(OLLAMA_API_URL, json={
        "model": MODEL_NAME,
        "messages": messages,
        "stream": True
    }, stream=True) as response:
        if response.status_code != 200:
            print("\n❌ Errore:", response.text)
            return ""

        full_reply = ""
        for line in response.iter_lines():
            if line:
                data = json.loads(line)
                chunk = data.get("message", {}).get("content", "")
                full_reply += chunk
                print(chunk, end="", flush=True)
        print("\n")
        return full_reply

def chat_with_simix():
    print("🤖 Chatta con Simix (solo ragionamento, senza azione — scrivi 'esci' per uscire)\n")

    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    while True:
        user_input = input("🟢 Tu: ")
        if user_input.lower() in ("esci", "exit", "quit"):
            break

        messages.append({"role": "user", "content": user_input})

        print("\n🧠 Piano di ragionamento:\nSimix: ", end="", flush=True)
        plan = stream_response(messages)
        messages.append({"role": "assistant", "content": plan})

if __name__ == "__main__":
    chat_with_simix()
