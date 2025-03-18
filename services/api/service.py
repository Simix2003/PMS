import asyncio
from controllers.plc import OPCClient

async def main():
    opc = OPCClient("opc.tcp://192.168.1.1:4840")
    await opc.connect()

    await opc.disconnect()

asyncio.run(main())
