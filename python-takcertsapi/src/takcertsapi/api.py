"""Main API entrypoint"""
from typing import Mapping
from fastapi import FastAPI

from .clients.api import CLIENT_ROUTER

APP = FastAPI()
APP.include_router(CLIENT_ROUTER)


@APP.get("/api/v1")
async def hello() -> Mapping[str, str]:
    """Say hello"""
    return {"message": "Hello World"}
