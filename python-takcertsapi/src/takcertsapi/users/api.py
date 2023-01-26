"""Users api implementation"""
from typing import List
from pathlib import Path
import logging
import shlex
import asyncio

from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import FileResponse

from ..config import INSTANCE as CONFIG
from .schema import UserList, UserCert, CreateUser
from ..security import check_bearer_token, validate_client_name

LOGGER = logging.getLogger(__name__)
USER_ROUTER = APIRouter(dependencies=[Depends(check_bearer_token)])


@USER_ROUTER.get("/api/v1/users", tags=["users"], response_model=UserList)
async def list_users() -> UserList:
    """List available user certificates (note that clients are also "users")"""
    certs: List[UserCert] = []
    for filepth in CONFIG.user_certs_location.glob("*.p12"):
        certs.append(UserCert(username=filepth.stem, url=f"/api/v1/users/{filepth.stem}"))
    return UserList(items=certs)


@USER_ROUTER.get("/api/v1/users/{username}", tags=["users"], response_class=FileResponse)
async def read_user(username: str) -> FileResponse:
    """Get a specific users p12 cert, NOTE: these are encrypted and the passwords are
    not stored here, when creating cert make sure to save the password somewhere safe"""
    pth = CONFIG.user_certs_location / Path(f"{username}.p12")
    if not pth.exists():
        raise HTTPException(status_code=404, detail="User cert not found")
    return FileResponse(pth)


@USER_ROUTER.post("/api/v1/users", tags=["users"], response_class=FileResponse)
async def create_user(user: CreateUser) -> FileResponse:
    """Create new user, remember to save the passphrase elsewhere (note that clients are also "users")"""
    username = user.username
    validate_client_name(username)

    pth = CONFIG.user_certs_location / Path(f"{username}.p12")
    if pth.exists():
        raise HTTPException(status_code=409, detail="User cert already exists")
    cmd1 = f"PASS={shlex.quote(user.passphrase)} {CONFIG.makecert_location} client {shlex.quote(username)}"
    proc1 = await asyncio.create_subprocess_shell(cmd1, stderr=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE)
    stdout1, stderr1 = await proc1.communicate()
    if proc1.returncode != 0 or not pth.exists():
        LOGGER.error("command '{}' exited with code {}".format(cmd1, proc1.returncode))
        LOGGER.info("stdout: {!r}".format(stdout1))
        LOGGER.info("stderr: {!r}".format(stderr1))
        LOGGER.info("path {} exists: {}".format(pth, pth.exists()))
        raise HTTPException(status_code=500, detail="Certificate creation failed. Contact server administration")
    cmd2 = f"ADMIN_CERT_NAME={shlex.quote(username)} {CONFIG.enableadmin_location}"
    proc2 = await asyncio.create_subprocess_shell(cmd2, stderr=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE)
    stdout2, stderr2 = await proc2.communicate()
    if proc2.returncode != 0:
        LOGGER.error("command '{}' exited with code {}".format(cmd2, proc2.returncode))
        LOGGER.info("stdout: {!r}".format(stdout2))
        LOGGER.info("stderr: {!r}".format(stderr2))
        raise HTTPException(status_code=500, detail="Could not enable user as admin. Contact server administration")

    return FileResponse(pth)
