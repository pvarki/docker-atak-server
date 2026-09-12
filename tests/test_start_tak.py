"""Configuration-service ownership and shared startup behavior."""

import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import coreconfig  # noqa: E402
import start_tak  # noqa: E402


class StartupTest(unittest.TestCase):
    """Exercise shared files and readiness without requiring a running database."""

    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        self.data = self.root / "data"
        self.data.mkdir()

    def test_readiness_requires_current_live_owner(self):
        (self.data / ".coreconfig-ready").write_text("stale")
        with self.assertRaises(TimeoutError):
            start_tak.wait_for_configuration(self.data, timeout=0)
        lock, generation = start_tak.acquire_config_lock(self.data)
        self.addCleanup(lock.close)
        self.assertTrue(os.get_inheritable(lock.fileno()))
        with self.assertRaises(RuntimeError):
            start_tak.acquire_config_lock(self.data)
        with self.assertRaises(TimeoutError):
            start_tak.wait_for_configuration(self.data, timeout=0)
        coreconfig.atomic_write(self.data / ".coreconfig-ready", generation.encode())
        start_tak.wait_for_configuration(self.data, timeout=0)
        lock.close()
        with self.assertRaises(TimeoutError):
            start_tak.wait_for_configuration(self.data, timeout=0)

    def test_prepares_one_authority_and_preserves_admin_restart_changes(self):
        shutil.copy("/opt/tak/CoreConfig.xsd", self.root / "CoreConfig.xsd")
        templates = Path(__file__).resolve().parents[1] / "templates"
        environment = {
            "TAKSERVER_CERT_PASS": "test",  # pragma: allowlist secret
            "CA_PASS": "test",  # pragma: allowlist secret
            "POSTGRES_USER": "tak",
            "POSTGRES_PASSWORD": "test",  # pragma: allowlist secret
            "TAK_SERVER_ADDRESS": "tak.test",
        }
        with patch.dict(os.environ, environment):
            start_tak.prepare_configuration(self.root, templates)
            canonical = self.data / "CoreConfig_config.xml"
            common = self.data / "CoreConfig.xml"
            self.assertEqual(common.resolve(), canonical)
            self.assertTrue((self.data / "TAKIgniteConfig.xml").is_file())
            saved = coreconfig.read_xml(canonical)
            coreconfig.one(saved, "federation").set("allowMissionFederation", "false")
            from lxml import etree

            canonical.write_bytes(etree.tostring(saved))
            start_tak.prepare_configuration(self.root, templates)
            self.assertEqual(
                coreconfig.one(coreconfig.read_xml(common), "federation").get(
                    "allowMissionFederation"
                ),
                "false",
            )
            start_tak.link_file(self.root / "CoreConfig.xml", canonical)
            self.assertEqual((self.root / "CoreConfig.xml").resolve(), canonical)
            self.assertFalse((self.data / "CoreConfig_api.xml").exists())


if __name__ == "__main__":
    unittest.main()
