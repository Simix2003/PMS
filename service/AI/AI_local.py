import requests

prompt = (
    "Riassumi in modo chiaro e sintetico la qualità della produzione di ieri: "
    "2540 moduli prodotti, 228 KO. "
    "Commenta il tasso di difettosità e il rendimento generale."
    "Questi sono i difetti principlai riscontrati: "
    "Macchie ECA: 50, Bad Soldering: 25, Solo Poe: 2"
)

response = requests.post(
    'http://localhost:11434/api/generate',
    json={
        'model': 'steamdj/llama3.1-cpu-only',
        'prompt': prompt,
        'stream': False
    }
)

print(response.json()["response"])
