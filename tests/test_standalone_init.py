"""Standalone initialization and upgrades with the TAK distribution's local CA tools."""

import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import standalone_init  # noqa: E402
import tls_identity  # noqa: E402


class StandaloneTest(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        shutil.copytree("/opt/tak/certs", self.root / "certs")
        self.scripts = Path(__file__).resolve().parents[1] / "scripts"
        self.files = self.root / "data/certs/files"
        self.password = "standalone-test"  # pragma: allowlist secret
        environment = dict(
            TAKSERVER_CERT_PASS=self.password,
            CA_PASS=self.password,
            ADMIN_CERT_PASS=self.password,
            TAK_SERVER_ADDRESS="tak.test",
            CA_NAME="local-test-ca",
            COUNTRY="FI",
            STATE="test",
            CITY="test",
            ORGANIZATION="test",
            ORGANIZATIONAL_UNIT="test",
        )
        self.env = patch.dict(os.environ, environment)
        self.env.start()
        self.addCleanup(self.env.stop)
        self.database = patch.object(standalone_init, "upgrade_database")
        self.upgrade = self.database.start()
        self.addCleanup(self.database.stop)

    def initialize(self):
        standalone_init.initialize(self.root, self.scripts)

    def test_fresh_setup_https_rotation_and_admin_persistence(self):
        self.initialize()
        self.upgrade.assert_called_once_with(self.root)
        for name in ("takserver", "takserver-https"):
            self.assertTrue((self.files / f"{name}.jks").is_file())
        self.assertTrue((self.files / "admin.pem").is_file())
        configuration = self.root / "data/CoreConfig_config.xml"
        configuration.write_text("saved administrator configuration")
        cot_key = (self.files / "takserver.key").read_bytes()
        ca = (self.files / "ca.pem").read_bytes()
        marker = (self.root / "data/firstrun.done").read_bytes()
        tls_identity.create_local_identity(
            self.files, "external-https", "tak.test", self.password, self.password, "EC"
        )
        tls_identity.run(
            [
                "keytool",
                "-importcert",
                "-noprompt",
                "-alias",
                "admin-added-trust",
                "-file",
                str(self.files / "external-https.pem"),
                "-keystore",
                str(self.files / "fed-truststore.jks"),
                "-storepass:env",
                "CA_PASS",
            ]
        )
        trust = (self.files / "fed-truststore.jks").read_bytes()
        with patch.dict(
            os.environ,
            TAK_HTTPS_KEY_FILENAME=str(self.files / "external-https.key"),
            TAK_HTTPS_CERT_FILENAME=str(self.files / "external-https.pem"),
            TAK_HTTPS_KEY_PASSWORD=self.password,
        ):
            self.initialize()
        self.upgrade.assert_called_once()
        self.assertEqual(configuration.read_text(), "saved administrator configuration")
        self.assertEqual((self.files / "takserver.key").read_bytes(), cot_key)
        self.assertEqual((self.files / "ca.pem").read_bytes(), ca)
        self.assertEqual((self.files / "fed-truststore.jks").read_bytes(), trust)
        self.assertEqual((self.root / "data/firstrun.done").read_bytes(), marker)
        exported = tls_identity.run(
            [
                "keytool",
                "-exportcert",
                "-alias",
                "takserver-https",
                "-keystore",
                str(self.files / "takserver-https.jks"),
                "-storepass:env",
                "TAKSERVER_CERT_PASS",
            ]
        )
        expected = tls_identity.run(
            [
                "openssl",
                "x509",
                "-in",
                str(self.files / "external-https.pem"),
                "-outform",
                "DER",
            ]
        )
        self.assertEqual(exported, expected)

    def test_old_initialized_volume_gets_separate_https_store(self):
        self.initialize()
        cot = (self.files / "takserver.key").read_bytes()
        trust = (self.files / "fed-truststore.jks").read_bytes()
        for suffix in ("key", "pem", "jks"):
            (self.files / f"takserver-https.{suffix}").unlink()
        self.initialize()
        self.upgrade.assert_called_once()
        self.assertTrue((self.files / "takserver-https.jks").is_file())
        self.assertEqual((self.files / "takserver.key").read_bytes(), cot)
        self.assertEqual((self.files / "fed-truststore.jks").read_bytes(), trust)

    def test_rejects_partial_https_configuration(self):
        with patch.dict(os.environ, TAK_HTTPS_KEY_FILENAME="/missing/key.pem"):
            with self.assertRaisesRegex(ValueError, "Set both"):
                self.initialize()
        self.upgrade.assert_not_called()


if __name__ == "__main__":
    unittest.main()
