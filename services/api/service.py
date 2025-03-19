import asyncio
from functools import partial
from fastapi import FastAPI
from controllers.plc import OPCClient
import uvicorn
from contextlib import asynccontextmanager

opc = OPCClient("opc.tcp://192.168.1.1:4840")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # STARTUP logic
    await opc.connect()
    yield
    # SHUTDOWN logic
    await opc.disconnect()

app = FastAPI(lifespan=lifespan)

async def on_value_change(opc, node, val, data):
    if isinstance(val, bool) and val is True:
        moduloId = await opc.read("SLS Interblocchi", "Da Bottero A CapGemini.M308_QG2.Id_Modulo")
        print(f"ID Modulo value: {moduloId}")
    else:
        print(f"⚠️ Ignoring {node} = {val}")

@app.post("/subscribe/M308")
async def subscribe():
    try:
        await opc.subscribe("SLS Interblocchi", "Da Bottero A CapGemini.M308_QG2.Inizio Lavorazione in Automatico", partial(on_value_change, opc))
        return {"status": "Subscribed to M308!"}
    except Exception as e:
        return {"status": "Failed", "error": str(e)}

if __name__ == "__main__":
    uvicorn.run("service:app", host="0.0.0.0", port=8000)
