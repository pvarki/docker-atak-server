"""Users api implementation"""
from typing import List
from pathlib import Path
import logging

from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import FileResponse

from ..config import INSTANCE as CONFIG
from .schema import UserList, UserCert
from ..security import check_bearer_token

LOGGER = logging.getLogger(__name__)
USER_ROUTER = APIRouter(dependencies=[Depends(check_bearer_token)])


@USER_ROUTER.get("/api/v1/users", tags=["users"], response_model=UserList)
async def list_users() -> UserList:
    """List available user certificates"""
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
