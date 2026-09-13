"""Exercise outbound trust renewal and isolation with real Java keystores."""

import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import java_truststore  # noqa: E402
from tls_identity import run  # noqa: E402


class JavaTruststoreTest(unittest.TestCase):
    def setUp(self) -> None:
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.folder = Path(self.work.name)
        self.ca = self.folder / "ca_public"
        self.ca.mkdir()
        self.root = self.folder / "tak"
        certs = self.root / "data/certs/files"
        certs.mkdir(parents=True)
        self.cot = certs / "truststore-root.jks"
        self.federation = certs / "fed-truststore.jks"
        self.cot.write_bytes(b"CoT trust must not change")
        self.federation.write_bytes(b"Administrator federation trust must not change")
        self.java_home = self.folder / "jdk"
        self.base = self.java_home / "lib/security/cacerts"
        self.base.parent.mkdir(parents=True)
        public = self.certificate("public-root")
        run(
            [
                "keytool",
                "-importcert",
                "-noprompt",
                "-storetype",
                "JKS",
                "-keystore",
                str(self.base),
                "-storepass",
                java_truststore.STORE_PASSWORD,
                "-alias",
                "public-root",
                "-file",
                str(public),
            ]
        )

    def certificate(self, name: str) -> Path:
        """Create independent test CA certificates."""
        certificate = self.folder / f"{name}.pem"
        run(
            [
                "openssl",
                "req",
                "-new",
                "-x509",
                "-newkey",
                "ec",
                "-pkeyopt",
                "ec_paramgen_curve:P-256",
                "-noenc",
                "-keyout",
                str(self.folder / "test.key"),
                "-out",
                str(certificate),
                "-days",
                "1",
                "-subj",
                f"/CN={name}",
            ]
        )
        return certificate

    def listing(self, store: Path) -> str:
        return run(
            [
                "keytool",
                "-list",
                "-v",
                "-keystore",
                str(store),
                "-storepass",
                java_truststore.STORE_PASSWORD,
            ]
        ).decode()

    def test_combines_all_chain_certificates_and_refreshes_without_widening_client_trust(
        self,
    ) -> None:
        base = self.base.read_bytes()
        root = self.certificate("cfssl-root").read_bytes()
        intermediate = self.certificate("cfssl-intermediate").read_bytes()
        chain = self.ca / "ca_chain.pem"
        chain.write_bytes(root + intermediate + root)
        mkcert = self.ca / "miniwerk_ca.pem"
        mkcert.write_bytes(self.certificate("mkcert").read_bytes())
        environment = {
            "JAVA_HOME": str(self.java_home),
            "JAVA_TOOL_OPTIONS": "-Dexample=preserved",
        }
        runtime = self.root / "runtime/pm"
        destination = runtime / "java-cacerts.p12"
        with patch.dict(os.environ, environment):
            java_truststore.configure(self.root, self.ca, runtime=runtime)
            options = os.environ["JAVA_TOOL_OPTIONS"]
            self.assertIn("-Dexample=preserved", options)
            self.assertIn(str(destination), options)
        self.assertFalse((self.root / "java-cacerts.p12").exists())
        listed = self.listing(destination)
        self.assertIn("Your keystore contains 4 entries", listed)
        for name in ("public-root", "cfssl-root", "cfssl-intermediate", "mkcert"):
            self.assertIn(f"Owner: CN={name}", listed)
        self.assertNotIn("PrivateKeyEntry", listed)
        self.assertEqual(destination.stat().st_mode & 0o777, 0o600)

        chain.write_bytes(root)
        mkcert.unlink()
        with patch.dict(os.environ, environment):
            java_truststore.configure(self.root, self.ca, runtime=runtime)
        listed = self.listing(destination)
        self.assertIn("Your keystore contains 2 entries", listed)
        self.assertNotIn("cfssl-intermediate", listed)
        self.assertNotIn("mkcert", listed)
        self.assertEqual(self.base.read_bytes(), base)
        self.assertEqual(self.cot.read_bytes(), b"CoT trust must not change")
        self.assertEqual(
            self.federation.read_bytes(),
            b"Administrator federation trust must not change",
        )

    def test_standalone_ca_and_invalid_refresh(self) -> None:
        ca = self.root / "data/certs/files/ca.pem"
        ca.write_bytes(self.certificate("standalone").read_bytes())
        with patch.dict(os.environ, JAVA_HOME=str(self.java_home)):
            java_truststore.configure(self.root, self.ca)
        destination = self.root / "java-cacerts.p12"
        self.assertIn("Owner: CN=standalone", self.listing(destination))
        original = destination.read_bytes()
        ca.write_text("invalid CA bundle")
        with patch.dict(os.environ, JAVA_HOME=str(self.java_home)):
            with self.assertRaisesRegex(ValueError, "No certificates"):
                java_truststore.configure(self.root, self.ca)
        self.assertEqual(destination.read_bytes(), original)

    def test_explicit_jvm_truststore_is_preserved(self) -> None:
        (self.ca / "root_ca.pem").write_bytes(self.certificate("local").read_bytes())
        for variable in ("JAVA_TOOL_OPTIONS", "JDK_JAVA_OPTIONS", "_JAVA_OPTIONS"):
            with self.subTest(variable=variable):
                settings = {
                    "JAVA_TOOL_OPTIONS": "-Dexample=preserved",
                    variable: '-Djavax.net.ssl.trustStore="/custom/cacerts"',
                }
                with patch.dict(os.environ, settings):
                    java_truststore.configure(self.root, self.ca)
                    self.assertEqual(os.environ[variable], settings[variable])
                    self.assertEqual(
                        os.environ["JAVA_TOOL_OPTIONS"], settings["JAVA_TOOL_OPTIONS"]
                    )
                self.assertFalse((self.root / "java-cacerts.p12").exists())


if __name__ == "__main__":
    unittest.main()
