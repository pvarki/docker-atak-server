"""Test the config class"""

from takcertsapi.config import INSTANCE
from .conftest import ZIPS_PATH, CERTS_PATH


def test_config_mock() -> None:
    """Check that config got mocked"""
    assert INSTANCE.client_zips_location == ZIPS_PATH
    assert INSTANCE.user_certs_location == CERTS_PATH
