"""Auth stuff"""
import logging
import shlex

from fastapi import Security, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from .config import INSTANCE as CONFIG


LOGGER = logging.getLogger(__name__)
BEARER = HTTPBearer(description="Bearer token required for access")
EXCLUDE_CERT_NAMES = ("takserver", "truststore-root")


async def check_bearer_token(token: HTTPAuthorizationCredentials = Security(BEARER)) -> HTTPAuthorizationCredentials:
    """Check the bearer token"""
    if not CONFIG.accept_bearer:
        raise HTTPException(status_code=403, detail="No tokens configured")
    if token.credentials == CONFIG.accept_bearer:
        return token
    raise HTTPException(status_code=403, detail="Invalid token")


def validate_client_name(clientname: str, auto_error: bool = True) -> bool:
    """Make sure the client/user name is safe to use with the fragile takserver distribution scripts"""
    try:
        parsed = list(shlex.shlex(clientname))
        if len(parsed) == 3 and parsed[1] in ("_",):
            if f"{parsed[0]}{parsed[1]}{parsed[2]}" != clientname:
                LOGGER.warning("shlex 3-part {} != {}".format(parsed, clientname))
                if auto_error:
                    raise HTTPException(status_code=403, detail="Keep to safe single-word names")
                return False
        elif parsed[0] != clientname:
            LOGGER.warning("shlex parsed {} != {}".format(parsed, clientname))
            if auto_error:
                raise HTTPException(status_code=403, detail="Keep to safe single-word names")
            return False
    except ValueError as exc:
        LOGGER.warning("shlex could not parse {}".format(clientname))
        if auto_error:
            raise HTTPException(status_code=403, detail="Keep to safe single-word names") from exc
        return False
    return True
