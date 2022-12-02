"""pytest automagics"""
from typing import Any
from typing import Generator
import logging
from pathlib import Path


import pytest
from libadvian.logging import init_logging
from fastapi.testclient import TestClient

import takcertsapi.config
from takcertsapi.api import APP


init_logging(logging.DEBUG)
LOGGER = logging.getLogger(__name__)

ZIPS_PATH = Path(__file__).parent / Path("data/certs_files/clientpkgs")
CERTS_PATH = Path(__file__).parent / Path("data/certs_files")


@pytest.fixture
def client() -> Generator[TestClient, None, None]:
    """Instantiated test client"""
    instance = TestClient(APP)
    yield instance


@pytest.fixture(autouse=True)
def muck_cert_paths(monkeypatch: Any) -> Generator[None, None, None]:
    """Set cert paths to our test ones"""
    monkeypatch.setenv("CLIENT_ZIPS_PATH", str(ZIPS_PATH))
    monkeypatch.setenv("USER_CERTS_PATH", str(CERTS_PATH))
    LOGGER.debug("takcertsapi.config.INSTANCE before mock {}".format(takcertsapi.config.INSTANCE))
    monkeypatch.setattr(takcertsapi.config.INSTANCE, "client_zips_location", ZIPS_PATH)
    monkeypatch.setattr(takcertsapi.config.INSTANCE, "user_certs_location", CERTS_PATH)
    LOGGER.debug("takcertsapi.config.INSTANCE after mock {}".format(takcertsapi.config.INSTANCE))
    yield
    monkeypatch.undo()
    LOGGER.debug("takcertsapi.config.INSTANCE after undo {}".format(takcertsapi.config.INSTANCE))
