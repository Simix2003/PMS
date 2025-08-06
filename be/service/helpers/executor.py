import asyncio
from service.state import global_state

async def run_in_thread(func, *args, **kwargs):
    loop = asyncio.get_running_loop()
    executor = global_state.executor
    return await loop.run_in_executor(executor, lambda: func(*args, **kwargs))


async def run_plc_read(func, *args, **kwargs):
    """Run PLC read operation in the dedicated executor."""
    loop = asyncio.get_running_loop()
    executor = global_state.plc_read_executor
    return await loop.run_in_executor(executor, lambda: func(*args, **kwargs))


async def run_plc_write(func, *args, **kwargs):
    """Run PLC write operation in the dedicated executor."""
    loop = asyncio.get_running_loop()
    executor = global_state.plc_write_executor
    return await loop.run_in_executor(executor, lambda: func(*args, **kwargs))
