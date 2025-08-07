import json

with open("fine_tuning.jsonl", "r", encoding="utf-8") as f:
    lines = f.readlines()

converted = []
for line in lines:
    data = json.loads(line)
    conv = {
        "conversations": [
            {"role": "user", "content": data["instruction"]},
            {"role": "assistant", "content": data["output"]}
        ]
    }
    converted.append(conv)

# Salva nel nuovo formato
with open("converted_dataset.jsonl", "w", encoding="utf-8") as f:
    for item in converted:
        f.write(json.dumps(item, ensure_ascii=False) + "\n")
