"""Client zip request and response schemas"""
from typing import List

from pydantic import BaseModel  # pylint: disable=E0611  # false-positive


# pylint: disable=R0903


class ClientPkg(BaseModel):
    """Define a client pkg"""

    name: str
    url: str


class ListClients(BaseModel):
    """List available client zip packages"""

    items: List[ClientPkg]
