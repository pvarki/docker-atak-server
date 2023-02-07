"""Clients API implementation"""
import asyncio
import shlex
from typing import List
from pathlib import Path
import logging

from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import FileResponse

from ..config import INSTANCE as CONFIG
from .schema import ClientList, ClientPkg, CreateClientPkg
from ..security import check_bearer_token, validate_client_name

LOGGER = logging.getLogger(__name__)
CLIENT_ROUTER = APIRouter(dependencies=[Depends(check_bearer_token)])


@CLIENT_ROUTER.get("/api/v1/clients", tags=["clients"], response_model=ClientList)
async def list_clients() -> ClientList:
    """List available client zip packages"""
    pkgs: List[ClientPkg] = []
    for filepth in CONFIG.client_zips_location.glob("*.zip"):
        pkgs.append(ClientPkg(name=filepth.stem, url=f"/api/v1/clients/{filepth.stem}"))
    return ClientList(items=pkgs)


@CLIENT_ROUTER.get("/api/v1/clients/{clientname}", tags=["clients"], response_class=FileResponse)
async def read_client(clientname: str) -> FileResponse:
    """Get a specific client zip pkg"""
    pth = CONFIG.client_zips_location / Path(f"{clientname}.zip")
    if not pth.exists():
        raise HTTPException(status_code=404, detail="Client package not found")
    return FileResponse(pth)


@CLIENT_ROUTER.post("/api/v1/clients", tags=["clients"], response_class=FileResponse)
async def create_client(client: CreateClientPkg) -> FileResponse:
    """Create new client zip pkg"""
    clientname = client.name
    validate_client_name(clientname)

    pth = CONFIG.client_zips_location / Path(f"{clientname}.zip")
    if pth.exists():
        raise HTTPException(status_code=409, detail="Client package already exists")
    cmd = f"CLIENT_CERT_NAME={shlex.quote(clientname)} {CONFIG.zip_script_location}"
    proc = await asyncio.create_subprocess_shell(cmd, stderr=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE)
    stdout, stderr = await proc.communicate()
    if proc.returncode != 0 or not pth.exists():
        LOGGER.error("command '{}' exited with code {}".format(cmd, proc.returncode))
        LOGGER.info("stdout: {!r}".format(stdout))
        LOGGER.info("stderr: {!r}".format(stderr))
        LOGGER.info("path {} exists: {}".format(pth, pth.exists()))
        raise HTTPException(status_code=500, detail="Package creation failed. Contact server administration")
    return FileResponse(pth)
