"""Per-container Ignite configuration with the actual TAK schema and template."""

import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from lxml import etree

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import ignite_config  # noqa: E402


class IgniteConfigTest(unittest.TestCase):
    def test_local_files_and_address_refresh_preserve_shared_configuration(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ):
            root = Path(directory)
            (root / "data").mkdir()
            shared = root / "data/TAKIgniteConfig.xml"
            shared.write_text("old shared configuration")
            shutil.copy("/opt/tak/TAKIgniteConfig.xsd", root / "TAKIgniteConfig.xsd")
            templates = Path(__file__).resolve().parents[1] / "templates"
            os.environ.pop("IGNITE_WORK_DIR", None)
            os.environ["TAK_IGNITE_SEEDS"] = "messaging.test:47500"
            with patch.object(
                ignite_config, "resolve_bind_address", return_value="192.0.2.1"
            ):
                config = ignite_config.prepare(root, templates, "config")
            os.environ.pop("IGNITE_WORK_DIR")
            with patch.object(
                ignite_config, "resolve_bind_address", return_value="192.0.2.2"
            ):
                messaging = ignite_config.prepare(root, templates, "messaging")
            self.assertNotEqual(config, messaging)
            self.assertEqual(
                etree.parse(str(config)).getroot().get("igniteHost"), "192.0.2.1"
            )
            (messaging.parent / "ready").touch()
            with patch.object(
                ignite_config, "resolve_bind_address", return_value="192.0.2.3"
            ):
                ignite_config.prepare(root, templates, "messaging")
            self.assertEqual(
                etree.parse(str(messaging)).getroot().get("igniteHost"), "192.0.2.3"
            )
            self.assertFalse((messaging.parent / "ready").exists())
            self.assertEqual(shared.read_text(), "old shared configuration")
            self.assertEqual(
                os.environ["IGNITE_TCP_DISCOVERY_ADDRESSES"], "messaging.test:47500"
            )
            self.assertTrue(Path(os.environ["IGNITE_WORK_DIR"]).is_dir())

    def test_rejects_non_routable_bind_addresses(self) -> None:
        for address in ("127.0.0.1", "0.0.0.0", "224.0.0.1"):
            with self.subTest(address=address), self.assertRaises(ValueError):
                ignite_config.resolve_bind_address(address)

    def test_rejects_an_address_not_owned_by_the_container(self) -> None:
        with patch.object(ignite_config.socket, "socket") as socket_factory:
            socket_factory.return_value.__enter__.return_value.bind.side_effect = (
                OSError("not local")
            )
            with self.assertRaisesRegex(OSError, "not local"):
                ignite_config.resolve_bind_address("192.0.2.1")
