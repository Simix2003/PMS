import asyncio
from controllers.plc import OPCClient

async def main():
    opc = OPCClient("opc.tcp://192.168.1.1:4840")
    await opc.connect()

    nested = await opc.read("DB_READ", "TEST.Esito_Scarto.Difetti.Saldatura.Stringa_F[1].String_Ribbon[10]")
    print(nested)

    await opc.disconnect()

asyncio.run(main())
