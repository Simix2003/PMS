from fastapi import APIRouter
from fastapi.responses import FileResponse

router = APIRouter()

@router.get("/api/ml/shift_anomaly_report")
async def get_latest_shift_report():
    import glob
    files = sorted(glob.glob("ml/anomalies/anomalies_*.csv"))
    if not files:
        return {"error": "No report found"}
    return FileResponse(files[-1])
