from fastapi import APIRouter
from fastapi.responses import FileResponse, JSONResponse
import pandas as pd
from pydantic import BaseModel
import torch
import os
import sys
import logging
from sentence_transformers import SentenceTransformer, util
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error
import joblib
from decimal import Decimal

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

class TrainingRequest(BaseModel):
    station_name: str

@router.post("/api/ml/generate_eta_dataset")
async def generate_eta_dataset(req: TrainingRequest):
    try:
        conn = get_mysql_connection()
        with conn.cursor() as cursor:
            query = """
            SELECT
              p.id AS production_id,
              p.object_id,
              TIME_TO_SEC(p.cycle_time) AS cycle_time_sec,
              COUNT(od.id) AS total_defects,
              COUNT(DISTINCT od.stringa) AS unique_stringhe,
              MAX(od.photo_id IS NOT NULL) AS has_photo,
              SUM(od.defect_id IN (2, 10)) AS saldatura_count,
              SUM(od.defect_id = 5) AS macchie_eca_count,
              SUM(od.defect_id = 4) AS mancanza_ribbon_count,
              SUM(od.defect_id = 6) AS celle_rotte_count,
              SUM(od.defect_id = 3) AS disallineamento_count,
              SUM(od.defect_id = 7) AS lunghezza_ribbon_count,
              SUM(od.defect_id = 8) AS leadwire_count,
              SUM(od.defect_id = 9) AS graffi_count,
              SUM(od.defect_id IN (1, 99)) AS altro_count
            FROM productions p
            JOIN object_defects od ON od.production_id = p.id
            WHERE
              p.station_id = (SELECT id FROM stations WHERE name = %s LIMIT 1)
              AND p.start_time IS NOT NULL
              AND p.end_time IS NOT NULL
            GROUP BY p.id
            """
            cursor.execute(query, (req.station_name,))
            rows = cursor.fetchall()

        # Convert to DataFrame
        df = pd.DataFrame(rows)

        # Convert Decimal to float
        for col in df.columns:
            df[col] = df[col].apply(lambda x: float(x) if isinstance(x, Decimal) else x)


        if df.empty:
            return JSONResponse(content={"message": "No data found for this station."})

        # Train model
        features = df.drop(columns=["production_id", "object_id", "cycle_time_sec"])
        target = df["cycle_time_sec"]

        X_train, X_test, y_train, y_test = train_test_split(
            features, target, test_size=0.2, random_state=42
        )

        model = RandomForestRegressor(n_estimators=100, random_state=42)
        model.fit(X_train, y_train)

        y_pred = model.predict(X_test)
        mae = mean_absolute_error(y_test, y_pred)

        # Save model
        # Ensure the directory exists before saving any model
        os.makedirs(ML_MODELS_DIR, exist_ok=True)

        model_path = ETA_MODEL_PATH_TEMPLATE(req.station_name)
        joblib.dump(model, model_path)
        

        return {
            "message": f"✅ Model trained and saved for station {req.station_name}",
            "rows_used": len(df),
            "features": list(features.columns),
            "mae_sec": round(float(mae), 2),
            "model_path": model_path,
        }

    except Exception as e:
        logger.error(f"❌ Error generating ETA model: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})
    
class PredictionRequest(BaseModel):
    production_id: int

@router.post("/api/ml/predict_eta")
async def predict_eta(req: PredictionRequest):
    try:
        conn = get_mysql_connection()
        with conn.cursor() as cursor:
            # Get defects + station for this production
            cursor.execute("""
                SELECT
                  p.station_id,
                  COUNT(od.id) AS total_defects,
                  COUNT(DISTINCT od.stringa) AS unique_stringhe,
                  MAX(od.photo_id IS NOT NULL) AS has_photo,
                  SUM(od.defect_id IN (2, 10)) AS saldatura_count,
                  SUM(od.defect_id = 5) AS macchie_eca_count,
                  SUM(od.defect_id = 4) AS mancanza_ribbon_count,
                  SUM(od.defect_id = 6) AS celle_rotte_count,
                  SUM(od.defect_id = 3) AS disallineamento_count,
                  SUM(od.defect_id = 7) AS lunghezza_ribbon_count,
                  SUM(od.defect_id = 8) AS leadwire_count,
                  SUM(od.defect_id = 9) AS graffi_count,
                  SUM(od.defect_id IN (1, 99)) AS altro_count
                FROM productions p
                JOIN object_defects od ON od.production_id = p.id
                WHERE p.id = %s
                GROUP BY p.id
            """, (req.production_id,))
            row = cursor.fetchone()

            if not row:
                return JSONResponse(status_code=404, content={"error": "Production ID not found or has no defects"})

            station_name = "RMI01"  # Hardcoded for now

        # Load model
        model_path = ETA_MODEL_PATH_TEMPLATE(station_name)
        if not os.path.exists(model_path):
            return JSONResponse(status_code=404, content={"error": f"No trained model found for station {station_name}"})

        model = joblib.load(model_path)

        # Define features
        feature_cols = [
            "total_defects", "unique_stringhe", "has_photo",
            "saldatura_count", "macchie_eca_count", "mancanza_ribbon_count",
            "celle_rotte_count", "disallineamento_count", "lunghezza_ribbon_count",
            "leadwire_count", "graffi_count", "altro_count"
        ]

        feature_vector = []
        reasoning = {}

        for col in feature_cols:
            value = float(row[col]) if col != "has_photo" else int(row[col])
            feature_vector.append(value)
            if value != 0:
                reasoning[col] = round(value, 2)

        prediction = model.predict([feature_vector])[0]

        # ------------------------------
        # Historical average logic
        # ------------------------------
        def get_average_for_signature(conn, total_defects, unique_stringhe, saldatura_count):
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT 
                        AVG(TIME_TO_SEC(p.cycle_time)) AS avg_cycle_time_sec,
                        COUNT(*) AS sample_size
                    FROM productions p
                    JOIN object_defects od ON od.production_id = p.id
                    WHERE p.station_id = (SELECT id FROM stations WHERE name = 'RMI01' LIMIT 1)
                      AND p.start_time IS NOT NULL
                      AND p.end_time IS NOT NULL
                    GROUP BY p.id
                    HAVING 
                        COUNT(od.id) = %s
                        AND COUNT(DISTINCT od.stringa) = %s
                        AND SUM(od.defect_id IN (2, 10)) = %s
                    LIMIT 1
                """, (
                    reasoning.get("total_defects", 0),
                    reasoning.get("unique_stringhe", 0),
                    reasoning.get("saldatura_count", 0)
                ))
                match = cursor.fetchone()
                if match:
                    return float(match["avg_cycle_time_sec"]), match["sample_size"]
                return None, 0

        avg_sec, sample_size = get_average_for_signature(
            conn,
            reasoning.get("total_defects", 0),
            reasoning.get("unique_stringhe", 0),
            reasoning.get("saldatura_count", 0)
        )

        return {
            "eta_sec": round(float(prediction), 2),
            "eta_min": round(float(prediction) / 60, 2),
            "model_used": os.path.basename(model_path),
            "reasoning": reasoning,
            "similar_average_sec": round(avg_sec, 2) if avg_sec else None,
            "similar_average_min": round(avg_sec / 60, 2) if avg_sec else None,
            "historical_samples": sample_size,
            "confidence": "low" if sample_size < 3 else "high"
        }

    except Exception as e:
        logger.error(f"❌ ETA prediction error: {e}")
        return JSONResponse(status_code=500, content={"error": str(e)})