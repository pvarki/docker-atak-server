"""pydantic schemas for users management"""
from typing import List

from pydantic import BaseModel  # pylint: disable=E0611  # false-positive


# pylint: disable=R0903


class UserCert(BaseModel):
    """Define a user cert"""

    username: str
    url: str


class UserList(BaseModel):
    """List available user certs"""

    items: List[UserCert]
