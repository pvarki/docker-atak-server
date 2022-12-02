"""Configuration variables"""
from typing import Optional
import os
import logging
from dataclasses import dataclass, field
from pathlib import Path

ZIPS_DEFAULT = "/opt/tak/certs_files/files/clientpkgs"
CERTS_DEFAULT = "/opt/tak/certs_files/files"
MKZIP_DEFAULT = "/opt/scripts/make_client_zip.sh"
LOGGER = logging.getLogger(__name__)


def get_env_path(key: str, default: Optional[str] = None) -> Optional[Path]:
    """Read env key and return as Path"""
    if (pth := os.getenv(key)) is not None:
        return Path(pth)
    if default is not None:
        return Path(default)
    return None


def get_client_zips_location() -> Path:
    """Get the client zips path"""
    if pth := get_env_path("CLIENT_ZIPS_PATH", ZIPS_DEFAULT):
        if not pth.exists() or not pth.is_dir():
            LOGGER.error("{} is not a directory we can access".format(pth))
        return pth
    raise ValueError("got empty path")


def get_user_certs_location() -> Path:
    """Get the user certs path"""
    if pth := get_env_path("USER_CERTS_PATH", CERTS_DEFAULT):
        if not pth.exists() or not pth.is_dir():
            LOGGER.error("{} is not a directory we can access".format(pth))
        return pth
    raise ValueError("got empty path")


def get_zip_script_location() -> Path:
    """Get the client zip creator script path"""
    if pth := get_env_path("CLIENT_SCRIPT_PATH", MKZIP_DEFAULT):
        if not pth.exists() or not pth.is_file():
            LOGGER.error("{} is not a file we can access".format(pth))
        return pth
    raise ValueError("got empty path")


@dataclass()
class Config:
    """Keep config in one place"""

    client_zips_location: Path = field(default_factory=get_client_zips_location)
    user_certs_location: Path = field(default_factory=get_user_certs_location)
    zip_script_location: Path = field(default_factory=get_zip_script_location)


INSTANCE = Config()
