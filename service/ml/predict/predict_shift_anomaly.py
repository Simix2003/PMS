# -*- coding: utf-8 -*-
"""
Report settimanale anomalie per turno – IX-Monitor
Genera CSV, grafici e PDF con trend, heatmap e top anomalie.
"""

import pandas as pd
import joblib
from sqlalchemy import create_engine
import os
from datetime import datetime, timedelta
import matplotlib.pyplot as plt
import seaborn as sns
from matplotlib.backends.backend_pdf import PdfPages

# ────────────────────────────────────────────────────────────────────────────
# 1) Percorsi e modelli
# ────────────────────────────────────────────────────────────────────────────
MODEL_PATH    = r"D:\Imix\Lavori\2025\3SUN\IX-Monitor\ix_monitor\service\ml\models\shift_anomaly\iso_model.pkl"
ENCODERS_PATH = r"D:\Imix\Lavori\2025\3SUN\IX-Monitor\ix_monitor\service\ml\models\shift_anomaly\encoders.pkl"
OUT_DIR       = r"D:\Imix\Lavori\2025\3SUN\IX-Monitor\ix_monitor\service\ml\anomalies"
os.makedirs(OUT_DIR, exist_ok=True)

model    = joblib.load(MODEL_PATH)
encoders = joblib.load(ENCODERS_PATH)

# ────────────────────────────────────────────────────────────────────────────
# 2) Intervallo: ultimi 14 giorni
# ────────────────────────────────────────────────────────────────────────────
data_end   = datetime.now().date()
data_start = data_end - timedelta(days=14)

# ────────────────────────────────────────────────────────────────────────────
# 3) Query MySQL
# ────────────────────────────────────────────────────────────────────────────
query = f"""
SELECT
  p.id                AS production_id,
  s.name              AS station,
  pl.name             AS line,
  ls.name             AS last_station,
  p.operator_id,
  p.start_time,
  TIME_TO_SEC(p.cycle_time) AS cycle_time_sec,
  IF(od.id IS NULL,0,1)      AS is_ng
FROM productions p
JOIN stations s        ON p.station_id = s.id
JOIN production_lines pl ON s.line_id  = pl.id
LEFT JOIN stations ls   ON p.last_station_id = ls.id
LEFT JOIN object_defects od ON od.production_id = p.id
WHERE p.start_time >= '{data_start}' 
  AND p.start_time  < '{data_end}';
"""

engine = create_engine("mysql+pymysql://root:Master36!@localhost/ix_monitor")
df     = pd.read_sql(query, engine)
if df.empty:
    print(f"⚠️ Nessun dato fra {data_start} e {data_end}.")
    exit()

# ────────────────────────────────────────────────────────────────────────────
# 4) Pre‐processing
# ────────────────────────────────────────────────────────────────────────────
df["start_time"]      = pd.to_datetime(df["start_time"], errors="coerce")
df.dropna(subset=["start_time"], inplace=True)
df["date"]            = df["start_time"].dt.date
df["weekday"]         = df["start_time"].dt.day_name()
df["hour"]            = df["start_time"].dt.hour
df["operator_id"]     = df["operator_id"].fillna("UNKNOWN")

def get_shift(h):
    if 6 <= h < 14:   return "Morning"
    if 14 <= h < 22:  return "Afternoon"
    return "Night"

df["shift"] = df["hour"].apply(get_shift)

# ────────────────────────────────────────────────────────────────────────────
# 5) Aggregazione per shift‐station
# ────────────────────────────────────────────────────────────────────────────
group_cols = ["weekday","shift","station","operator_id","last_station"]
agg = (
    df.groupby(group_cols)
      .agg(total          = ("production_id","count"),
           ng_count       = ("is_ng",      "sum"),
           avg_cycle_time = ("cycle_time_sec","mean"),
           first_date     = ("start_time", "min"),
           last_date      = ("start_time", "max"))
      .reset_index()
)
agg["ng_rate"] = agg["ng_count"] / agg["total"]

# ────────────────────────────────────────────────────────────────────────────
# 6) Encode + Anomaly Detection
# ────────────────────────────────────────────────────────────────────────────
enc = agg.copy()
for col in group_cols:
    enc[col] = encoders[col].transform(enc[col].astype(str))

X = enc[group_cols + ["ng_rate","avg_cycle_time","total"]]
agg["is_anomaly"] = model.predict(X) == -1

# ────────────────────────────────────────────────────────────────────────────
# 7) Spiegazione anomalie
# ────────────────────────────────────────────────────────────────────────────
def explain(row):
    reasons=[]
    if row.ng_rate>0.20:           reasons.append(f"🔴 Scarto: {row.ng_rate:.0%}")
    if row.avg_cycle_time>120:     reasons.append(f"🐢 Ciclo: {int(row.avg_cycle_time)}s")
    if row.total<5:                reasons.append("⚠️ Pochi moduli")
    return " | ".join(reasons)

agg["reason"] = agg.apply(explain,axis=1)

# ────────────────────────────────────────────────────────────────────────────
# 8) Stampa in console
# ────────────────────────────────────────────────────────────────────────────
print("\n🔍 ANOMALIE RILEVATE (ultimi 14 gg):\n")
for _,r in agg[agg.is_anomaly].iterrows():
    periodo = f"{r.first_date.date()} → {r.last_date.date()}"
    print(f"– {r.station} | {r.shift} | 👤 {r.operator_id} | 📆 {periodo}")
    print(f"  {r.reason} (moduli: {r.total})\n")

# ────────────────────────────────────────────────────────────────────────────
# 9) Salva CSV
# ────────────────────────────────────────────────────────────────────────────
csv_path = os.path.join(OUT_DIR,f"anomalie_{data_start}_to_{data_end}.csv")
agg.to_csv(csv_path,index=False)

# ────────────────────────────────────────────────────────────────────────────
# 10) Genera grafici + PDF
# ────────────────────────────────────────────────────────────────────────────
pdf_path = os.path.join(OUT_DIR,f"report_anomalie_{data_start}_to_{data_end}.pdf")
with PdfPages(pdf_path) as pdf:

    # a) Trend NG giornaliero
    fig,ax = plt.subplots(figsize=(10,4))
    daily = df.groupby("date").agg(ng_rate=("is_ng","mean")).reset_index()
    ax.plot(daily.date, daily.ng_rate, marker="o")
    ax.set_title("📈 Trend giornaliero tasso di scarto",fontsize=12)
    ax.set_ylabel("Scarto (%)")
    ax.set_xlabel("Data")
    ax.yaxis.set_major_formatter(lambda x, pos: f"{x:.0%}")
    plt.xticks(rotation=45)
    plt.tight_layout()
    pdf.savefig(fig)

    # b) Heatmap NG per station/shift
    fig,ax = plt.subplots(figsize=(8,6))
    hm = (
      df.groupby(["station","shift"])
        .agg(ng_rate=("is_ng","mean"))
        .unstack()
        .ng_rate
    )
    sns.heatmap(hm, annot=True, fmt=".0%", cmap="YlOrRd", ax=ax)
    ax.set_title("🌡️ Heatmap scarto per stazione/turno",fontsize=12)
    plt.tight_layout()
    pdf.savefig(fig)

    # c) Heatmap NG per giorno/turno
    fig,ax = plt.subplots(figsize=(7,5))
    hm2 = (
      df.groupby(["weekday","shift"])
        .agg(ng_rate=("is_ng","mean"))
        .unstack()
        .ng_rate
        .reindex(index=["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"])
    )
    sns.heatmap(hm2,annot=True,fmt=".0%",cmap="PuRd",ax=ax)
    ax.set_title("🌡️ Heatmap scarto per giorno/turno",fontsize=12)
    plt.tight_layout()
    pdf.savefig(fig)

print(f"\n✅ Report PDF salvato in: {pdf_path}")
print(f"✅ CSV anomalie: {csv_path}")
