from fastapi import APIRouter
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import torch
import os
import sys
import logging
from collections import defaultdict, Counter
from dataclasses import dataclass, field
from fastapi import APIRouter
from pydantic import BaseModel
import torch
from torch.nn import functional as F
from transformers import AutoTokenizer, AutoModel

# Extend Python path for module resolution
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from service.config.config import KNOWN_DEFECTS, DEFECT_SIMILARITY_MODEL_PATH
from service.connections.mysql import get_mysql_read_connection

router = APIRouter()
logger = logging.getLogger(__name__)

# ───────────────────────────────────────────────────────────────

# Mean pooling function (same as sentence-transformers default behavior)
def mean_pooling(model_output, attention_mask):
    token_embeddings = model_output.last_hidden_state  # (batch_size, seq_len, hidden_size)
    input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
    sum_embeddings = torch.sum(token_embeddings * input_mask_expanded, 1)
    sum_mask = torch.clamp(input_mask_expanded.sum(1), min=1e-9)
    return sum_embeddings / sum_mask

# Model loader function (cleaner structure)
def load_model_and_tokenizer(model_path):
    tokenizer = AutoTokenizer.from_pretrained(model_path)
    model = AutoModel.from_pretrained(model_path)
    model.to(torch.device("cpu"))
    return tokenizer, model

# Compute embeddings function (shared for both known and input)
def compute_embeddings(sentences, tokenizer, model):
    encoded_input = tokenizer(
        sentences,
        padding=True,
        truncation=True,
        return_tensors='pt'
    )
    with torch.no_grad():
        model_output = model(**encoded_input)
    embeddings = mean_pooling(model_output, encoded_input['attention_mask'])
    return embeddings

# Load model at startup
try:
    tokenizer, model = load_model_and_tokenizer(DEFECT_SIMILARITY_MODEL_PATH)
    KNOWN_EMBEDDINGS = compute_embeddings(KNOWN_DEFECTS, tokenizer, model)
    logger.info(f"✅ Loaded ML model from: {DEFECT_SIMILARITY_MODEL_PATH}")
except Exception as e:
    logger.error(f"❌ Could not load ML model from {DEFECT_SIMILARITY_MODEL_PATH}: {e}")
    model = None
    tokenizer = None
    KNOWN_EMBEDDINGS = None

# ───────────────────────────────────────────────────────────────

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

    # Compute embedding for input text
    input_embedding = compute_embeddings([data.input_text], tokenizer, model)

    # Cosine similarity with precomputed known embeddings
    cosine_scores = F.cosine_similarity(input_embedding, KNOWN_EMBEDDINGS)

    best_idx = int(torch.argmax(cosine_scores))
    best_score = float(cosine_scores[best_idx])
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

def filter_outliers(values, factor=1.5):
    if not values:
        return values
    values_sorted = sorted(values)
    n = len(values_sorted)
    q1 = values_sorted[n // 4]
    q3 = values_sorted[3 * n // 4]
    iqr = q3 - q1
    lower_bound = q1 - factor * iqr
    upper_bound = q3 + factor * iqr
    return [v for v in values if lower_bound <= v <= upper_bound]

# ------------------- MAIN LOGIC -------------------

async def run_eta_prediction(production_id: int):
    try:
        with get_mysql_read_connection() as conn:
            with conn.cursor() as cursor:
                # Step 1: Get defects for this production_id
                cursor.execute("""
                    SELECT defect_id FROM object_defects WHERE production_id = %s
                """, (production_id,))
                current_defects_raw = cursor.fetchall()
                current_defects = Counter(row["defect_id"] for row in current_defects_raw)

                if not current_defects:
                    return JSONResponse(
                        status_code=419,
                        content={
                            "error": f"No DEFECTS found for production_id {production_id}",
                            "reason": "no_defects"
                        }
                    )



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
        raw_cycle_times = [ct for _, ct in matches]
        filtered_cycle_times = filter_outliers(raw_cycle_times)

        # Safety fallback if all filtered out
        if not filtered_cycle_times:
            filtered_cycle_times = raw_cycle_times

        # Recalculate weighted average using filtered data
        filtered_matches = [(score, ct) for (score, ct) in matches if ct in filtered_cycle_times]

        total_weight = sum(score for score, _ in filtered_matches)
        prediction = sum(score * ct for score, ct in filtered_matches) / total_weight
        avg_sec = sum(ct for _, ct in filtered_matches) / len(filtered_cycle_times)


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
        with get_mysql_read_connection() as conn:
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
