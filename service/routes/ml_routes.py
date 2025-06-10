from fastapi import APIRouter
from fastapi.responses import  JSONResponse
from pydantic import BaseModel
import torch
import os
import sys
import logging
from sentence_transformers import SentenceTransformer, util
from collections import defaultdict, Counter
from dataclasses import dataclass, field

# Extend Python path for module resolution
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.config import KNOWN_DEFECTS, DEFECT_SIMILARITY_MODEL_PATH, ML_MODELS_DIR, ETA_MODEL_PATH_TEMPLATE
from service.connections.mysql import get_mysql_connection

router = APIRouter()

logger = logging.getLogger("PMS")

# Try loading the model
model = None
KNOWN_EMBEDDINGS = None

try:
    model = SentenceTransformer(DEFECT_SIMILARITY_MODEL_PATH)
    KNOWN_EMBEDDINGS = model.encode(KNOWN_DEFECTS, convert_to_tensor=True)
    logger.info(f"✅ Loaded ML model from: {DEFECT_SIMILARITY_MODEL_PATH}")
except Exception as e:
    logger.error(f"❌ Could not load ML model from {DEFECT_SIMILARITY_MODEL_PATH}: {e}")
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

# ------------------- MODELS -------------------

class PredictionRequest(BaseModel):
    production_id: int

class EtaByModuloRequest(BaseModel):
    id_modulo: str

@dataclass
class DefectHistory:
    defects: Counter = field(default_factory=Counter)
    cycle_time_sec: float | None = None

def time_to_seconds(t):
    return t.total_seconds() if t else None

# ------------------- MAIN LOGIC -------------------

async def run_eta_prediction(production_id: int):
    try:
        conn = get_mysql_connection()
        with conn.cursor() as cursor:
            # Step 1: Get defects for this production_id
            cursor.execute("""
                SELECT defect_id FROM object_defects WHERE production_id = %s
            """, (production_id,))
            current_defects_raw = cursor.fetchall()
            current_defects = Counter(row["defect_id"] for row in current_defects_raw)

            if not current_defects:
                return JSONResponse(status_code=404, content={"error": "No defects found for this production_id"})

            # Step 2: Get historical rework station defects and cycle times
            cursor.execute("""
                SELECT od.production_id, od.defect_id, p.cycle_time
                FROM object_defects od
                JOIN productions p ON od.production_id = p.id
                JOIN stations s ON p.station_id = s.id
                WHERE s.type = 'rework'
                  AND p.start_time >= NOW() - INTERVAL 90 DAY
                  AND p.cycle_time IS NOT NULL
            """)
            rows = cursor.fetchall()

        # Step 3: Group by production_id
        history = defaultdict(DefectHistory)
        for row in rows:
            entry = history[row["production_id"]]
            entry.defects[row["defect_id"]] += 1
            entry.cycle_time_sec = time_to_seconds(row["cycle_time"])

        # Step 4: Match by frequency-based similarity
        matches = []
        for pid, data in history.items():
            if data.cycle_time_sec is None:
                continue
            intersection = current_defects & data.defects
            shared_count = sum(intersection.values())
            total_count = sum(current_defects.values())
            score = shared_count / max(1, total_count)
            if score >= 0.5:
                matches.append((score, data.cycle_time_sec))

        sample_size = len(matches)

        if sample_size == 0:
            return {
                "eta_sec": None,
                "eta_min": None,
                "model_used": "defect_frequency_lookup",
                "reasoning": "No similar past defects found at rework stations",
                "similar_average_sec": None,
                "similar_average_min": None,
                "historical_samples": 0,
                "confidence": "low"
            }

        # Step 5: Weighted average
        total_weight = sum(score for score, _ in matches)
        prediction = sum(score * ct for score, ct in matches) / total_weight
        avg_sec = sum(ct for _, ct in matches) / sample_size

        reasoning = f"{sample_size} similar rework cases matched using >=50% defect frequency similarity."

        return {
            "eta_sec": round(prediction, 2),
            "eta_min": round(prediction / 60, 2),
            "model_used": "defect_frequency_lookup",
            "reasoning": reasoning,
            "similar_average_sec": round(avg_sec, 2),
            "similar_average_min": round(avg_sec / 60, 2),
            "historical_samples": sample_size,
            "confidence": "high" if sample_size >= 3 else "low"
        }

    except Exception as e:
        logger.error(f"❌ ETA prediction error: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})

# ------------------- ROUTES -------------------

@router.post("/api/ml/predict_eta")
async def predict_eta(req: PredictionRequest):
    return await run_eta_prediction(req.production_id)

@router.post("/api/ml/predict_eta_by_id_modulo")
async def predict_eta_by_id_modulo(req: EtaByModuloRequest):
    try:
        conn = get_mysql_connection()
        with conn.cursor() as cursor:
            # Step 1: Resolve id_modulo → object.id
            cursor.execute("""
                SELECT id FROM objects WHERE id_modulo = %s
            """, (req.id_modulo,))
            object_row = cursor.fetchone()

            if not object_row:
                return JSONResponse(status_code=404, content={"error": f"id_modulo '{req.id_modulo}' not found in object table"})

            object_id = object_row["id"]

            # Step 2: Find latest QC production for this object
            cursor.execute("""
                SELECT p.id AS production_id
                FROM productions p
                JOIN stations s ON p.station_id = s.id
                WHERE p.object_id = %s AND s.type = 'qc'
                ORDER BY p.start_time DESC
                LIMIT 1
            """, (object_id,))
            prod_row = cursor.fetchone()

            if not prod_row:
                return JSONResponse(status_code=404, content={"error": f"No production at QC for object_id {object_id}"})

            production_id = prod_row["production_id"]

        return await run_eta_prediction(production_id)

    except Exception as e:
        logger.error(f"❌ predict_eta_by_id_modulo error: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})
