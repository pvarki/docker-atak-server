"""API implementation"""
from typing import List
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from ..config import INSTANCE as CONFIG
from .schema import ListClients, ClientPkg


CLIENT_ROUTER = APIRouter()


@CLIENT_ROUTER.get("/api/v1/clients", tags=["clients"], response_model=ListClients)
async def read_clients() -> ListClients:
    """List available client zip packages"""
    pkgs: List[ClientPkg] = []
    for filepth in CONFIG.client_zips_location.glob("*.zip"):
        pkgs.append(ClientPkg(name=filepth.stem, url=f"/api/v1/clients/{filepth.stem}"))
    return ListClients(items=pkgs)


@CLIENT_ROUTER.get("/api/v1/clients/{clientname}", tags=["clients"], response_class=FileResponse)
async def read_user(clientname: str) -> FileResponse:
    """Get a specific client zip pkg"""
    pth = CONFIG.client_zips_location / Path(f"{clientname}.zip")
    if not pth.exists():
        raise HTTPException(status_code=404, detail="Client package not found")
    return FileResponse(pth)
