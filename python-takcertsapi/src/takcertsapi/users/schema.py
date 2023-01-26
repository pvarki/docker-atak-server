"""pydantic schemas for users management"""
from typing import List

from pydantic import BaseModel, Field  # pylint: disable=E0611  # false-positive


# pylint: disable=R0903


class UserCert(BaseModel):
    """Define a user cert"""

    username: str
    url: str


class UserList(BaseModel):
    """List available user certs"""

    items: List[UserCert]


class CreateUser(BaseModel):
    """Create a new user"""

    username: str = Field(
        regex=r"^[a-zA-Z0-9_]{3,}$",
        description="User name, ASCII characters and numbers only, minimum 3 characters",
        example="someone",
    )
    passphrase: str = Field(
        regex=r"^[a-zA-Z0-9_]{10,}$",
        description="Passphrase for cert, ASCII characters and numbers only, minimum 10 characters",
        example="This_is_a_passphrase",
    )
