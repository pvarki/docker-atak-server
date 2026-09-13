"""Add deployment CAs to Java's outbound trust without changing client trust."""

import hashlib
import os
import re
import shutil
import ssl
import tempfile
from pathlib import Path

from tls_identity import run

# This store contains public certificates only, like the JRE's cacerts.
STORE_PASSWORD = "changeit"  # pragma: allowlist secret


def initialize(base_store: Path, destination: Path, bundles: list[Path]) -> None:
    """Rebuild from current JRE roots and CA bundles, then publish atomically."""
    with tempfile.TemporaryDirectory(
        prefix=".java-trust-", dir=destination.parent
    ) as folder:
        work = Path(folder)
        store = work / "cacerts.p12"
        run(
            [
                "keytool",
                "-importkeystore",
                "-noprompt",
                "-srckeystore",
                str(base_store),
                "-srcstorepass",
                STORE_PASSWORD,
                "-destkeystore",
                str(store),
                "-deststoretype",
                "PKCS12",
                "-deststorepass",
                STORE_PASSWORD,
            ]
        )
        seen: set[str] = set()
        for bundle in bundles:
            certificates = re.findall(
                r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----",
                bundle.read_text(encoding="ascii"),
                re.DOTALL,
            )
            if not certificates:
                raise ValueError(f"No certificates in {bundle}")
            for pem in certificates:
                fingerprint = hashlib.sha256(ssl.PEM_cert_to_DER_cert(pem)).hexdigest()
                if fingerprint in seen:
                    continue
                seen.add(fingerprint)
                certificate = work / "certificate.pem"
                certificate.write_text(pem + "\n", encoding="ascii")
                run(
                    [
                        "keytool",
                        "-importcert",
                        "-noprompt",
                        "-keystore",
                        str(store),
                        "-storepass",
                        STORE_PASSWORD,
                        "-alias",
                        f"deployment-{fingerprint}",
                        "-file",
                        str(certificate),
                    ]
                )
        store.chmod(0o600)
        os.replace(store, destination)


def configure(
    root: Path,
    ca_directory: Path = Path("/ca_public"),
    *,
    runtime: Path | None = None,
) -> None:
    """Configure each TAK JVM's private outbound store on every service start."""
    for variable in ("JAVA_TOOL_OPTIONS", "JDK_JAVA_OPTIONS", "_JAVA_OPTIONS"):
        if "-Djavax.net.ssl.trustStore=" in os.environ.get(variable, ""):
            return
    bundles = [
        path
        for path in (
            ca_directory / "ca_chain.pem",
            ca_directory / "root_ca.pem",
            ca_directory / "intermediate_ca.pem",
            ca_directory / "miniwerk_ca.pem",
            root / "data/certs/files/ca.pem",
        )
        if path.exists()
    ]
    if not bundles:
        return
    java_home = os.environ.get("JAVA_HOME")
    if java_home:
        java_root = Path(java_home)
    else:
        java = shutil.which("java")
        if java is None:
            raise RuntimeError("Java is required to prepare outbound CA trust")
        java_root = Path(java).resolve().parents[1]
    base_store = java_root / "lib/security/cacerts"
    directory = runtime if runtime is not None else root
    directory.mkdir(parents=True, exist_ok=True)
    destination = directory / "java-cacerts.p12"
    initialize(base_store, destination, bundles)
    options = os.environ.get("JAVA_TOOL_OPTIONS", "")
    os.environ["JAVA_TOOL_OPTIONS"] = (
        f'{options} -Djavax.net.ssl.trustStore="{destination}"'
        f" -Djavax.net.ssl.trustStorePassword={STORE_PASSWORD}"
        " -Djavax.net.ssl.trustStoreType=PKCS12"
    ).strip()
