import requests
import json

OLLAMA_API_URL = "http://localhost:11434/api/chat"
MODEL_NAME = "gemma3n:e2b"

SYSTEM_PROMPT = """
Sei Simix, un assistente AI esperto nel monitoraggio della produzione industriale.
Parli esclusivamente in italiano. Ragiona in modo logico e strutturato.
Hai accesso a uno schema SQL del database che descrive il sistema produttivo (PMS).
Quando rispondi, sii chiaro, sintetico e tecnico. Fornisci analisi, insight o risposte basate sui dati.

Se non hai abbastanza contesto, chiedi informazioni aggiuntive prima di rispondere.
"""

def chat_with_simix():
    print("🇮🇹 Chatta con Simix (scrivi 'esci' per uscire)\n")

    # Optional: Check if model exists
    resp = requests.get("http://localhost:11434/api/tags")
    tags = resp.json()
    print("✅ Modelli disponibili:", [t["name"] for t in tags.get("models", [])], "\n")

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT}
    ]

    while True:
        user_input = input("Tu: ")
        if user_input.lower() in ("esci", "exit", "quit"):
            break

        messages.append({"role": "user", "content": user_input})

        print("\nSimix: ", end="", flush=True)

        # Send request with stream=True
        with requests.post(OLLAMA_API_URL, json={
            "model": MODEL_NAME,
            "messages": messages,
            "stream": True
        }, stream=True) as response:
            if response.status_code != 200:
                print("\n❌ Errore:", response.text)
                break

            full_reply = ""
            for line in response.iter_lines():
                if line:
                    data = json.loads(line)
                    chunk = data.get("message", {}).get("content", "")
                    full_reply += chunk
                    print(chunk, end="", flush=True)

            print("\n")
            messages.append({"role": "assistant", "content": full_reply})

if __name__ == "__main__":
    chat_with_simix()