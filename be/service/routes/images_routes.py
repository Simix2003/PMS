from fastapi import APIRouter, UploadFile, File, Form
import os
from typing import List
from pathlib import Path
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from service.helpers.helpers import generate_unique_filename

router = APIRouter()

# Usa una variabile d'ambiente o default a /app/images_submitted
BASE_IMAGE_PATH = os.environ.get("IMAGES_SUBMITTED_PATH", "/app/images_submitted")

@router.post("/api/upload_images")
async def upload_images(
    object_id: str = Form(...),
    images: List[UploadFile] = File(...),
    defects: List[str] = Form(...)
):
    folder_path = Path(BASE_IMAGE_PATH) / object_id
    folder_path.mkdir(parents=True, exist_ok=True)

    for i, image_file in enumerate(images):
        defect_name = defects[i].replace(" ", "_").replace(":", "_")
        filename = image_file.filename or f"image_{i}.jpg"
        ext = os.path.splitext(filename)[-1]
        save_path = generate_unique_filename(str(folder_path), defect_name, ext)

        with open(save_path, "wb") as f:
            content = await image_file.read()
            f.write(content)

    return {"status": "ok", "saved": len(images)}