from fastapi import APIRouter
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer, util
import torch

import os
import sys

# Extend Python path for module resolution
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.config import KNOWN_DEFECTS, ML_MODEL_PATH

router = APIRouter()

# Load the model once when the router is imported
model = SentenceTransformer(ML_MODEL_PATH)

# Precompute embeddings once
KNOWN_EMBEDDINGS = model.encode(KNOWN_DEFECTS, convert_to_tensor=True)

class DefectInput(BaseModel):
    input_text: str

@router.post("/api/ml/check_defect_similarity")
async def check_defect_similarity(data: DefectInput):
    input_embedding = model.encode(data.input_text, convert_to_tensor=True)
    cosine_scores = util.cos_sim(input_embedding, KNOWN_EMBEDDINGS)  # shape: (1, N)

    scores = cosine_scores[0]  # 1D tensor: (N,)
    
    best_idx_tensor = torch.argmax(scores)
    best_idx = int(best_idx_tensor)  # Explicitly cast to int for Pylance
    best_score = float(scores[best_idx])  # Also cast result to float for clarity

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

#TEST DA FARE : 
    
    # matrice con solo poe
    # matrice con solo vetro
    # frammenti
    # 