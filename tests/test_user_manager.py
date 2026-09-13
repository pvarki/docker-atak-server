"""TAKCL must not reuse the server's multicast discovery configuration."""

import sys
import tempfile
import unittest
from pathlib import Path

from lxml import etree

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import user_manager  # noqa: E402


class UserManagerTest(unittest.TestCase):
    def test_private_xml_preserves_server_configuration_and_escapes_paths(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / "server & certs"
            root.mkdir()
            shared = root / "TAKIgniteConfig.xml"
            shared.write_text("server XML stays unchanged")
            client = Path(folder) / "client"
            client.mkdir()
            path = user_manager.write_configuration(root, client, "192.0.2.1")
            config = etree.parse(str(path)).getroot()
            server = config.find(
                "{http://bbn.com/marti/takcl/config/common}RunnableTAKServerConfig"
            )
            assert server is not None
            self.assertEqual(
                server.get("certificateDirectory"), str(root / "data/certs/files")
            )
            ignite = etree.parse(str(client / "TAKIgniteConfig.xml")).getroot()
            self.assertEqual(ignite.get("igniteHost"), "192.0.2.1")
            self.assertEqual(ignite.get("igniteMulticast"), "false")
            self.assertEqual(shared.read_text(), "server XML stays unchanged")
