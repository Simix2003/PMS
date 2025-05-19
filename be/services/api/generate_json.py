import json
import os

from service import ISSUE_TREE 
output = {}
safe_folder = "Linea2"  # same as in your API

def slugify(value):
    return value.lower().replace(" ", "_")

def recursive_generate(tree, path_list, depth=0):
    image_name = slugify("_".join(path_list)) + ".jpg"
    path = ".".join(["Dati", "Esito", "Esito_Scarto", "Difetti"] + path_list)

    # If current node has children
    if isinstance(tree, dict):
        children = list(tree.items())

        # Add config for this level
        output[image_name] = {
            "path": path,
            "rectangles": []
        }

        # Create rectangles with placeholder coords
        for i, (key, value) in enumerate(children):
            output[image_name]["rectangles"].append({
                "name": key,
                "type": "folder" if isinstance(value, dict) else "leaf",
                "x": round(0.05 + (i % 5) * 0.18, 3),     # Simple spread pattern
                "y": round(0.1 + (i // 5) * 0.15, 3),
                "width": 0.15,
                "height": 0.1
            })

            if isinstance(value, dict):
                recursive_generate(value, path_list + [key], depth + 1)

# Start from ISSUE_TREE["Dati"]["Esito"]["Esito_Scarto"]["Difetti"]
root = ISSUE_TREE["Dati"]["Esito"]["Esito_Scarto"]["Difetti"]
recursive_generate(root, [])

# Save the file
output_path = os.path.join("C:/IX-Monitor/images", safe_folder, "overlay_config.json")
with open(output_path, "w") as f:
    json.dump(output, f, indent=2)

print(f"✅ overlay_config.json saved with {len(output)} image entries!")
