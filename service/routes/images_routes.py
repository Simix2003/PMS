from fastapi import APIRouter, UploadFile, File, Form
import os
from typing import List

import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from service.helpers.helpers import generate_unique_filename

router = APIRouter()

@router.post("/api/upload_images")
async def upload_images(
    object_id: str = Form(...),
    images: List[UploadFile] = File(...),
    defects: List[str] = Form(...)
):
    folder_path = f"C:/IX-Monitor/images_submitted/{object_id}"
    os.makedirs(folder_path, exist_ok=True)

    for i, image_file in enumerate(images):
        defect_name = defects[i].replace(" ", "_").replace(":", "_")
        filename = image_file.filename or f"image_{i}.jpg"
        ext = os.path.splitext(filename)[-1]
        save_path = generate_unique_filename(folder_path, defect_name, ext)

        with open(save_path, "wb") as f:
            content = await image_file.read()
            f.write(content)

    return {"status": "ok", "saved": len(images)}
