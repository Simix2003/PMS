TO START THE VIRTUAL ENVIRONMENT OF Python 3.11.2 use:
- cd services
- venv\Scripts\activate

flutter build web --web-renderer html

# Build for port 8080 (HomePage only)
flutter build web --web-renderer html --release -t lib/main_home.dart -o build/web_home

# Build for port 8081 (DataView + OverlayEditor)
flutter build web --web-renderer html --release -t lib/main_data.dart -o build/web_data

flutter run -d chrome --web-renderer html -t lib/main_home.dart
flutter run -d chrome --web-renderer html -t lib/main_data.dart


pyinstaller --onefile --add-binary="C:\Users\papar\Desktop\Prova_Comunicazione_PLC\Lib\site-packages\snap7\lib\snap7.dll;." service.py  



PS D:\Imix\Lavori\2025\3SUN\IX-Monitor\ix_monitor> & d:/Imix/Lavori/2025/3SUN/IX-Monitor/ix_monitor/services/venv/Scripts/python.exe d:/Imix/Lavori/2025/3SUN/IX-Monitor/ix_monitor/services/api/AI.py
🚀 Starting report generation...

🔌 Connecting to MySQL...
✅ Connected.
📅 Calculating analysis period...
📊 Querying production totals...
✅ Totals fetched.
🔍 Gathering defect data...
✅ Defect analysis complete.
📈 Calculating productivity and quality trend...
📉 Produttività: N/A, Qualità: N/A
🔒 Database connection closed.
🤖 Sending prompt to Ollama...
✅ AI response received.
🧠 Parsing AI JSON response...
❌ Failed to parse AI JSON.

❌ ERROR returned:
{
  "error": "AI response is not valid JSON",
  "content": "```json\n{\n  \"periodo_analisi\": \"Ultimi 7 giorni\",\n  \"totali\": {\n    \"pezzi_totali\": 163,\n    \"pezzi_buoni\": 154,\n    \"pezzi_scarti\": 0,\n    \"percentuale_buoni\": 94.48,\n    \"percentuale_scarti\": 0.00,\n    \"tempo_ciclo_medio\": \"01:35\"\n  },\n  \"problemi_principali\": [\n    {\n      \"problema\": \"Stringa_M_B\",\n      \"numero_scarti\": 9\n    },\n    {\n      \"problema\": \"Disallineamento Stringa\",\n      \"numero_scarti\": 0\n    },\n    {\n      \"problema\": \"Lunghezza String Ribbon\",\n      \"numero_scarti\": 0\n    }\n  ],\n  \"trend\": {\n    \"produttivita\": \"N/A\",\n    \"qualita\": \"N/A\"\n  },\n  \"analisi_approfondita\": [\n    \"Il periodo analizzato comprende gli ultimi 7 giorni. Il numero di pezzi totali, buoni e scarti è di 163, con un percentuale di produzione del 94,48%.\",\n    \"I problemi principali sono il difetto stringa M_B (9 scarti), il disallineamento stringa (0 scarti) e la lunghezza della stringa ribbon (0 scarti).\"\n  ],\n  \"cose_che_stanno_andando_bene\": [\n    \"La produzione è stata stabile negli ultimi 7 giorni.\"\n  ],\n  \"consigli_ai\": [\n    \"Analizzare il database più a fondo per identificare altre aree di miglioramento.\"\n  ]\n}\n```"
}