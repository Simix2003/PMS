import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import LabelEncoder
from sqlalchemy import create_engine
import joblib
import os

# === LOAD DATA FROM MYSQL ===
query = """
SELECT
  p.id AS production_id,
  s.name AS station,
  s.id AS station_id,
  s.type AS station_type,
  pl.name AS line,
  ls.name AS last_station,
  ls.id AS last_station_id,
  p.operator_id,
  p.start_time,
  TIME_TO_SEC(p.cycle_time) AS cycle_time_sec,
  IF(od.id IS NULL, 0, 1) AS is_ng
FROM productions p
JOIN stations s ON p.station_id = s.id
JOIN production_lines pl ON s.line_id = pl.id
LEFT JOIN stations ls ON p.last_station_id = ls.id
LEFT JOIN object_defects od ON od.production_id = p.id;
"""

engine = create_engine("mysql+pymysql://root:Master36!@localhost/ix_monitor")
df = pd.read_sql(query, engine)

# === FEATURE ENGINEERING ===
df["start_time"] = pd.to_datetime(df["start_time"])
df["weekday"] = df["start_time"].dt.day_name()
df["hour"] = df["start_time"].dt.hour

def get_shift(hour):
    if 6 <= hour < 14:
        return "Morning"
    elif 14 <= hour < 22:
        return "Afternoon"
    else:
        return "Night"

df["shift"] = df["hour"].apply(get_shift)

# === AGGREGATE NG RATE PER SHIFT-GROUP ===
group_cols = ["weekday", "shift", "station", "operator_id", "last_station"]
agg = df.groupby(group_cols).agg(
    total=("production_id", "count"),
    ng_count=("is_ng", "sum"),
    avg_cycle_time=("cycle_time_sec", "mean")
).reset_index()

agg["ng_rate"] = agg["ng_count"] / agg["total"]

# === ENCODE CATEGORICAL FEATURES ===
encoders = {}
encoded_df = agg.copy()
for col in group_cols:
    le = LabelEncoder()
    encoded_df[col] = le.fit_transform(encoded_df[col].astype(str))
    encoders[col] = le

X = encoded_df[group_cols + ["ng_rate", "avg_cycle_time", "total"]]

# === TRAIN ISOLATION FOREST ===
model = IsolationForest(n_estimators=100, contamination=0.05, random_state=42)
model.fit(X)

# === SAVE MODEL AND ENCODERS ===
os.makedirs(r"D:\Imix\Lavori\2025\3SUN\IX-Monitor\ix_monitor\service\ml\models\shift_anomaly", exist_ok=True)
joblib.dump(model, r"D:\Imix\Lavori\2025\3SUN\IX-Monitor\ix_monitor\service\ml\models\shift_anomaly\iso_model.pkl")
joblib.dump(encoders, r"D:\Imix\Lavori\2025\3SUN\IX-Monitor\ix_monitor\service\ml\models\shift_anomaly\encoders.pkl")

print("✅ Shift Anomaly Model & Encoders Saved.")
