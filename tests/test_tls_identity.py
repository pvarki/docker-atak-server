"""Validate separate local identities and safe HTTPS refresh with real crypto tools."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import tls_identity  # noqa: E402


class IdentityTest(unittest.TestCase):
    def setUp(self) -> None:
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.folder = Path(self.work.name)
        self.password = "test-password"  # pragma: allowlist secret
        self.environment = dict(os.environ, TEST_PASS=self.password)
        tls_identity.run(
            [
                "openssl",
                "req",
                "-new",
                "-x509",
                "-newkey",
                "ec",
                "-pkeyopt",
                "ec_paramgen_curve:P-256",
                "-keyout",
                str(self.folder / "ca-do-not-share.key"),
                "-out",
                str(self.folder / "ca.pem"),
                "-passout",
                "env:TEST_PASS",
                "-days",
                "1",
                "-subj",
                "/CN=local-root",
            ],
            env=self.environment,
        )

    def create(self, name: str, keytype: str) -> None:
        tls_identity.create_local_identity(
            self.folder, name, "tak.test", self.password, self.password, keytype
        )

    def import_store(self, name: str, destination: Path) -> None:
        tls_identity.import_identity(
            self.folder / f"{name}.key",
            self.folder / f"{name}.pem",
            destination,
            self.password,
            self.password,
        )

    def test_separate_keys_hostname_chain_and_https_refresh(self) -> None:
        self.create("takserver", "RSA")
        self.create("takserver-https", "EC")
        for name in ("takserver", "takserver-https"):
            tls_identity.run(
                [
                    "openssl",
                    "verify",
                    "-CAfile",
                    str(self.folder / "ca.pem"),
                    "-verify_hostname",
                    "tak.test",
                    "-purpose",
                    "sslserver",
                    str(self.folder / f"{name}.pem"),
                ]
            )
            self.import_store(name, self.folder / f"{name}.jks")
            listed = tls_identity.run(
                [
                    "keytool",
                    "-list",
                    "-v",
                    "-keystore",
                    str(self.folder / f"{name}.jks"),
                    "-storepass:env",
                    "TEST_PASS",
                ],
                env=self.environment,
            ).decode()
            self.assertIn("Certificate chain length: 2", listed)
        tls_identity.run(
            [
                "openssl",
                "rsa",
                "-in",
                str(self.folder / "takserver.key"),
                "-passin",
                "env:TEST_PASS",
                "-check",
                "-noout",
            ],
            env=self.environment,
        )
        tls_identity.run(
            [
                "openssl",
                "ec",
                "-in",
                str(self.folder / "takserver-https.key"),
                "-passin",
                "env:TEST_PASS",
                "-check",
                "-noout",
            ],
            env=self.environment,
        )
        cot = (self.folder / "takserver.jks").read_bytes()
        cot_key = (self.folder / "takserver.key").read_bytes()
        https_key = (self.folder / "takserver-https.key").read_bytes()
        self.create("takserver-https", "EC")
        self.assertEqual((self.folder / "takserver-https.key").read_bytes(), https_key)
        self.create("renewed-https", "EC")
        self.import_store("renewed-https", self.folder / "takserver-https.jks")
        self.assertEqual((self.folder / "takserver.jks").read_bytes(), cot)
        self.assertEqual((self.folder / "takserver.key").read_bytes(), cot_key)

    def test_invalid_pair_preserves_existing_store(self) -> None:
        self.create("first", "EC")
        self.create("second", "EC")
        destination = self.folder / "https.jks"
        self.import_store("first", destination)
        original = destination.read_bytes()
        with self.assertRaises(subprocess.CalledProcessError):
            tls_identity.import_identity(
                self.folder / "first.key",
                self.folder / "second.pem",
                destination,
                self.password,
                self.password,
            )
        self.assertEqual(destination.read_bytes(), original)

    def test_partial_identity_is_not_regenerated(self) -> None:
        key = self.folder / "partial.key"
        key.write_text("existing key")
        with self.assertRaisesRegex(ValueError, "Incomplete identity"):
            self.create("partial", "EC")
        self.assertEqual(key.read_text(), "existing key")


if __name__ == "__main__":
    unittest.main()
