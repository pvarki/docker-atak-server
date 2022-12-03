"""pytest automagics"""
from typing import Any
from typing import Generator
import logging
from pathlib import Path
from distutils.dir_util import copy_tree

import pytest
from libadvian.logging import init_logging
from libadvian.testhelpers import nice_tmpdir  # pylint: disable=W0611
from fastapi.testclient import TestClient

import takcertsapi.config
from takcertsapi.api import APP

# pylint: disable=W0621

init_logging(logging.DEBUG)
LOGGER = logging.getLogger(__name__)

ZIPS_PATH = Path(__file__).parent / Path("data/certs_files/clientpkgs")
CERTS_PATH = Path(__file__).parent / Path("data/certs_files")
SCRIPTS_PATH = Path(__file__).parent / Path("data/scripts")
BEARER_TOKEN = "pytest-token"  # nosec


@pytest.fixture
def client() -> Generator[TestClient, None, None]:
    """Instantiated test client"""
    instance = TestClient(APP)
    instance.headers.update({"Authorization": f"Bearer {BEARER_TOKEN}"})
    yield instance


@pytest.fixture()
def muck_cert_paths(monkeypatch: Any) -> Generator[None, None, None]:
    """Set cert paths to our test ones"""
    monkeypatch.setenv("CLIENT_ZIPS_PATH", str(ZIPS_PATH))
    monkeypatch.setenv("USER_CERTS_PATH", str(CERTS_PATH))
    monkeypatch.setenv("BEARER_ACCEPT", BEARER_TOKEN)
    monkeypatch.setattr(takcertsapi.config.INSTANCE, "accept_bearer", BEARER_TOKEN)
    monkeypatch.setattr(takcertsapi.config.INSTANCE, "client_zips_location", ZIPS_PATH)
    monkeypatch.setattr(takcertsapi.config.INSTANCE, "user_certs_location", CERTS_PATH)
    yield
    monkeypatch.undo()


@pytest.fixture()
def temp_cert_path(monkeypatch: Any, nice_tmpdir: str) -> Generator[None, None, None]:
    """Make a temp directory we can write to and copy test certs there"""
    scripts_path = Path(nice_tmpdir) / Path("scripts")
    scripts_path.mkdir()
    client_script = scripts_path / Path("make_client_zip.sh")
    certs_path = Path(nice_tmpdir) / Path("certs")
    certs_path.mkdir()
    zips_path = certs_path / Path("clientpkgs")
    zips_path.mkdir()
    copy_tree(str(SCRIPTS_PATH), str(scripts_path))
    copy_tree(str(CERTS_PATH), str(certs_path))

    monkeypatch.setenv("CLIENT_ZIPS_PATH", str(zips_path))
    monkeypatch.setenv("USER_CERTS_PATH", str(certs_path))
    monkeypatch.setenv("CLIENT_SCRIPT_PATH", str(client_script))
    monkeypatch.setenv("ZIPTGT", str(zips_path))  # used by our dummy script
    monkeypatch.setenv("BEARER_ACCEPT", BEARER_TOKEN)
    monkeypatch.setattr(takcertsapi.config.INSTANCE, "accept_bearer", BEARER_TOKEN)
    monkeypatch.setattr(takcertsapi.config.INSTANCE, "client_zips_location", zips_path)
    monkeypatch.setattr(takcertsapi.config.INSTANCE, "user_certs_location", certs_path)
    monkeypatch.setattr(takcertsapi.config.INSTANCE, "zip_script_location", client_script)
    yield
    monkeypatch.undo()
