"""Auth stuff"""
import logging

from fastapi import Security, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from .config import INSTANCE as CONFIG


LOGGER = logging.getLogger(__name__)
BEARER = HTTPBearer(description="Bearer token required for access")


async def check_bearer_token(token: HTTPAuthorizationCredentials = Security(BEARER)) -> HTTPAuthorizationCredentials:
    """Check the bearer token"""
    if not CONFIG.accept_bearer:
        raise HTTPException(status_code=403, detail="No tokens configured")
    if token.credentials == CONFIG.accept_bearer:
        return token
    raise HTTPException(status_code=403, detail="Invalid token")
