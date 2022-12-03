"""Client zip request and response schemas"""
from typing import List

from pydantic import BaseModel, Field  # pylint: disable=E0611  # false-positive


# pylint: disable=R0903


class ClientPkg(BaseModel):
    """Define a client pkg"""

    name: str
    url: str


class ClientList(BaseModel):
    """List available client zip packages"""

    items: List[ClientPkg]


class CreateClientPkg(BaseModel):
    """Create a new client pkg"""

    name: str = Field(
        regex=r"^[a-zA-Z0-9_]{3,}$",
        description="Client name, ASCII characters and numbers only, minimum 3 characters",
        example="FOX_2",
    )
