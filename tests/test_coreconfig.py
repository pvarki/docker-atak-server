"""Run with /usr/bin/python3 -m unittest discover -s /workspace/tests in the TAK image."""

from copy import deepcopy
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from lxml import etree

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import coreconfig  # noqa: E402


class CoreConfigTest(unittest.TestCase):
    """Exercise real template/schema compatibility and persistence across startup."""

    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.folder = Path(self.work.name)
        self.template = self.folder / "template.xml"
        environment = dict(
            os.environ,
            TAKSERVER_CERT_PASS="test",
            CA_PASS="test",
            POSTGRES_USER="tak",
            POSTGRES_PASSWORD="new-password",  # pragma: allowlist secret
            POSTGRES_ADDRESS="new-db",
            TAK_SERVER_ADDRESS="tak.test",
        )
        environment.pop("LDAP_BIND_PASSWORD", None)
        for name in list(environment):
            if name.startswith("TAK_HTTPS_"):
                environment.pop(name)
        template_path = Path(__file__).resolve().parents[1] / "templates/CoreConfig.tpl"
        self.template.write_bytes(
            subprocess.run(
                ["gomplate", "-f", str(template_path)],
                env=environment,
                check=True,
                capture_output=True,
            ).stdout
        )
        self.schema = Path("/opt/tak/CoreConfig.xsd")
        self.destination = self.folder / "CoreConfig_config.xml"

    def save(self, root, destination=None):
        (destination or self.destination).write_bytes(etree.tostring(root))

    def prepare(self, legacy=None):
        coreconfig.prepare(self.template, self.destination, self.schema, legacy)

    def test_preserves_admin_settings_and_updates_deployment(self):
        saved = coreconfig.read_xml(self.template)
        federation = coreconfig.one(saved, "federation")
        federation.set("allowMissionFederation", "false")
        outgoing = etree.Element(
            f"{{{coreconfig.NS}}}federation-outgoing",
            address="peer.test",
            port="9001",
            displayName="peer",
        )
        federation.insert(1, outgoing)
        peer = etree.Element(
            f"{{{coreconfig.NS}}}federate", id="AB:CD", name="peer", archive="false"
        )
        etree.SubElement(peer, f"{{{coreconfig.NS}}}inboundGroup").text = "team"
        federation.insert(2, peer)
        tls = coreconfig.one(saved, "federation/federation-server/tls")
        tls.set("truststoreFile", "/custom/fed.jks")
        tls.set("truststorePass", "admin-password")
        coreconfig.one(saved, "repository/connection").set(
            "url", "jdbc:postgresql://old-db/cot"
        )
        coreconfig.one(saved, "network").remove(
            coreconfig.one(saved, "network/input[@_name='stdssl-noarchive']")
        )
        extra = etree.Element(
            f"{{{coreconfig.NS}}}input", _name="custom", port="8092", protocol="tls"
        )
        coreconfig.one(saved, "network").insert(1, extra)
        self.save(saved)
        old = self.destination.read_bytes()
        self.prepare()
        result = coreconfig.read_xml(self.destination)
        self.assertEqual(
            coreconfig.one(result, "federation").get("allowMissionFederation"), "false"
        )
        self.assertEqual(
            coreconfig.one(result, "federation/federate/inboundGroup").text, "team"
        )
        self.assertEqual(
            coreconfig.one(result, "federation/federation-outgoing").get("address"),
            "peer.test",
        )
        self.assertEqual(
            coreconfig.one(result, "federation/federation-server/tls").get(
                "truststorePass"
            ),
            "admin-password",
        )
        self.assertEqual(
            coreconfig.one(result, "network/input[@_name='stdssl-noarchive']").get(
                "archive"
            ),
            "false",
        )
        self.assertIsNotNone(coreconfig.one(result, "network/input[@_name='custom']"))
        self.assertIn(
            "new-db", coreconfig.one(result, "repository/connection").get("url")
        )
        self.assertEqual(
            self.destination.with_suffix(".xml.pre-merge-backup").read_bytes(), old
        )
        before = self.destination.read_bytes()
        self.prepare()
        self.assertEqual(self.destination.read_bytes(), before)
        self.assertEqual(
            self.destination.with_suffix(".xml.pre-merge-backup").read_bytes(), old
        )

    def test_initialization_and_legacy_migration(self):
        self.prepare()
        self.assertTrue(self.destination.exists())
        self.assertEqual(self.destination.stat().st_mode & 0o777, 0o600)
        legacy = self.folder / "CoreConfig.xml"
        saved = coreconfig.read_xml(self.template)
        coreconfig.one(saved, "federation").set("allowMissionFederation", "false")
        self.save(saved, legacy)
        # Existing config-service state wins over an older common file.
        self.prepare(legacy)
        self.assertEqual(
            coreconfig.one(coreconfig.read_xml(self.destination), "federation").get(
                "allowMissionFederation"
            ),
            "true",
        )
        self.destination.unlink()
        self.prepare(legacy)
        self.assertEqual(
            coreconfig.one(coreconfig.read_xml(self.destination), "federation").get(
                "allowMissionFederation"
            ),
            "false",
        )

    def test_invalid_saved_xml_is_not_replaced(self):
        for contents in (
            b"broken XML",
            b'<Configuration xmlns="http://bbn.com/marti/xml/config"><invalid/></Configuration>',
        ):
            self.destination.write_bytes(contents)
            with self.assertRaises((ValueError, etree.LxmlError)):
                self.prepare()
            self.assertEqual(self.destination.read_bytes(), contents)
            self.assertFalse(
                self.destination.with_suffix(".xml.pre-merge-backup").exists()
            )

    def test_conflicting_admin_port_is_not_overwritten(self):
        saved = coreconfig.read_xml(self.template)
        listener = coreconfig.one(saved, "network/input[@_name='stdssl-noarchive']")
        listener.set("_name", "admin-listener")
        self.save(saved)
        before = self.destination.read_bytes()
        with self.assertRaisesRegex(ValueError, "Duplicate tcp listener on port 8090"):
            self.prepare()
        self.assertEqual(self.destination.read_bytes(), before)

    def test_ldap_can_be_enabled_and_disabled(self):
        saved = coreconfig.read_xml(self.template)
        template = deepcopy(saved)
        auth = coreconfig.one(template, "auth")
        auth.set("default", "ldap")
        etree.SubElement(
            auth, f"{{{coreconfig.NS}}}ldap", url="ldap://directory.test", style="DS"
        )
        enabled = coreconfig.merge(saved, template)
        self.assertEqual(
            coreconfig.one(enabled, "auth/ldap").get("url"), "ldap://directory.test"
        )
        disabled = coreconfig.merge(enabled, saved)
        self.assertIsNone(coreconfig.one(disabled, "auth/ldap"))
        self.assertIsNone(coreconfig.one(disabled, "auth").get("default"))

    def test_additional_cot_listener_does_not_change_https_identity(self):
        config = coreconfig.read_xml(self.template)
        self.assertEqual(
            coreconfig.one(config, "network/connector[@_name='https']").get(
                "keystoreFile"
            ),
            "/opt/tak/data/certs/files/takserver-https.jks",
        )
        self.assertEqual(
            coreconfig.one(config, "security/tls").get("keystoreFile"),
            "/opt/tak/data/certs/files/takserver.jks",
        )
        for name, port in (("stdssl", "8089"), ("stdssl-noarchive", "8090")):
            listener = coreconfig.one(config, f"network/input[@_name='{name}']")
            self.assertEqual(listener.get("port"), port)
            self.assertEqual(listener.get("protocol"), "tls")


if __name__ == "__main__":
    unittest.main()
