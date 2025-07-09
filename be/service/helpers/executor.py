import asyncio
from service.state import global_state

async def run_in_thread(func, *args, **kwargs):
    loop = asyncio.get_running_loop()
    executor = global_state.executor
    return await loop.run_in_executor(executor, lambda: func(*args, **kwargs))
