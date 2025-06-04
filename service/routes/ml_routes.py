from fastapi import APIRouter
from fastapi.responses import FileResponse
from pydantic import BaseModel
import torch

import os
import sys
import logging

from sentence_transformers import SentenceTransformer, util

# Extend Python path for module resolution
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.config import KNOWN_DEFECTS, ML_MODEL_PATH

router = APIRouter()

logger = logging.getLogger("PMS")

# Try loading the model
model = None
KNOWN_EMBEDDINGS = None

try:
    model = SentenceTransformer(ML_MODEL_PATH)
    KNOWN_EMBEDDINGS = model.encode(KNOWN_DEFECTS, convert_to_tensor=True)
    logger.info(f"✅ Loaded ML model from: {ML_MODEL_PATH}")
except Exception as e:
    logger.error(f"❌ Could not load ML model from {ML_MODEL_PATH}: {e}")
    model = None
    KNOWN_EMBEDDINGS = None

class DefectInput(BaseModel):
    input_text: str

@router.post("/api/ml/check_defect_similarity")
async def check_defect_similarity(data: DefectInput):
    if model is None or KNOWN_EMBEDDINGS is None:
        logger.warning("⚠️ ML model not available – skipping similarity check")
        return {
            "suggested_defect": None,
            "confidence": 0.0
        }

    input_embedding = model.encode(data.input_text, convert_to_tensor=True)
    cosine_scores = util.cos_sim(input_embedding, KNOWN_EMBEDDINGS)

    scores = cosine_scores[0]  # shape: (N,)
    best_idx = int(torch.argmax(scores))
    best_score = float(scores[best_idx])
    best_match = KNOWN_DEFECTS[best_idx]

    if best_score > 0.75:
        return {
            "suggested_defect": best_match,
            "confidence": round(best_score, 2)
        }
    else:
        return {
            "suggested_defect": None,
            "confidence": round(best_score, 2)
        }
