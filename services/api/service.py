import asyncio
from functools import partial
from controllers.plc import OPCClient

async def on_value_change(opc, node, val, data):
    # Only react when BOOL becomes True
    if isinstance(val, bool) and val is True:
        print(f"✅ Condition met! {node} = {val}")
        nested = await opc.read("DB_READ", "TEST.Esito_Scarto.Difetti.Saldatura.Stringa_F[1].String_Ribbon[10]")
        print(f"Nested value: {nested}")
    else:
        print(f"⚠️ Ignoring {node} = {val}")

async def main():
    opc = OPCClient("opc.tcp://192.168.1.1:4840")
    await opc.connect()
    
    await opc.subscribe("DB_READ", "TEST.Esito_Scarto.pezzoKO", partial(on_value_change, opc))
    await asyncio.sleep(20)
    await opc.disconnect()

asyncio.run(main())
