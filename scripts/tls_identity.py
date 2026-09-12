"""Generate local TLS identities and atomically import PEM identities into JKS."""

import ipaddress
import os
import re
import secrets
import subprocess
import tempfile
from collections.abc import Mapping
from pathlib import Path


def run(
    command: list[str], *, env: Mapping[str, str] | None = None, cwd: Path | None = None
) -> bytes:
    """Do not emit private material or command arguments containing credentials."""
    result = subprocess.run(command, check=True, capture_output=True, env=env, cwd=cwd)
    return result.stdout


def import_identity(
    key: Path,
    certificate: Path,
    destination: Path,
    password: str,
    key_password: str = "",
    alias: str = "takserver",
) -> None:
    """Validate the key/certificate pair before replacing the destination store."""
    environment = dict(
        os.environ, IDENTITY_KEY_PASSWORD=key_password, IDENTITY_STORE_PASSWORD=password
    )
    with tempfile.TemporaryDirectory(
        prefix=".identity-", dir=destination.parent
    ) as folder:
        work = Path(folder)
        bundle = work / "identity.p12"
        store = work / "identity.jks"
        run(
            [
                "openssl",
                "pkcs12",
                "-export",
                "-inkey",
                str(key),
                "-in",
                str(certificate),
                "-out",
                str(bundle),
                "-name",
                alias,
                "-passin",
                "env:IDENTITY_KEY_PASSWORD",
                "-passout",
                "env:IDENTITY_STORE_PASSWORD",
            ],
            env=environment,
        )
        run(
            [
                "keytool",
                "-noprompt",
                "-importkeystore",
                "-srcstoretype",
                "PKCS12",
                "-deststoretype",
                "JKS",
                "-srckeystore",
                str(bundle),
                "-destkeystore",
                str(store),
                "-alias",
                alias,
                "-srcstorepass:env",
                "IDENTITY_STORE_PASSWORD",
                "-deststorepass:env",
                "IDENTITY_STORE_PASSWORD",
                "-destkeypass:env",
                "IDENTITY_STORE_PASSWORD",
            ],
            env=environment,
        )
        store.chmod(0o600)
        os.replace(store, destination)


def create_local_identity(
    folder: Path,
    name: str,
    hostname: str,
    password: str,
    ca_password: str,
    keytype: str,
) -> None:
    """Create a distinct local-CA identity once; never replace existing key material."""
    key = folder / f"{name}.key"
    certificate = folder / f"{name}.pem"
    if key.exists() and certificate.exists():
        return
    if key.exists() or certificate.exists():
        raise ValueError(
            f"Incomplete identity {name}; restore the matching key/certificate before initialization"
        )
    try:
        address = ipaddress.ip_address(hostname)
        san = f"IP:{address}"
    except ValueError:
        if not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?", hostname):
            raise ValueError(
                "TAK_SERVER_ADDRESS must be a hostname or IP address"
            ) from None
        san = f"DNS:{hostname}"
    if keytype not in ("RSA", "EC"):
        raise ValueError(f"Unsupported identity key type: {keytype}")
    environment = dict(
        os.environ, IDENTITY_KEY_PASSWORD=password, IDENTITY_CA_PASSWORD=ca_password
    )
    with tempfile.TemporaryDirectory(prefix=f".{name}-", dir=folder) as temporary:
        work = Path(temporary)
        options = (
            ["-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048"]
            if keytype == "RSA"
            else ["-algorithm", "EC", "-pkeyopt", "ec_paramgen_curve:P-256"]
        )
        run(
            [
                "openssl",
                "genpkey",
                *options,
                "-aes-256-cbc",
                "-pass",
                "env:IDENTITY_KEY_PASSWORD",
                "-out",
                str(work / "identity.key"),
            ],
            env=environment,
        )
        run(
            [
                "openssl",
                "req",
                "-new",
                "-key",
                str(work / "identity.key"),
                "-passin",
                "env:IDENTITY_KEY_PASSWORD",
                "-out",
                str(work / "identity.csr"),
                "-subj",
                f"/CN={hostname}",
            ],
            env=environment,
        )
        extensions = work / "extensions.cnf"
        extensions.write_text(
            "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature"
            + (",keyEncipherment" if keytype == "RSA" else "")
            + "\nextendedKeyUsage=serverAuth,clientAuth\nsubjectAltName="
            + san
            + "\n"
        )
        run(
            [
                "openssl",
                "x509",
                "-req",
                "-sha256",
                "-days",
                "730",
                "-in",
                str(work / "identity.csr"),
                "-CA",
                str(folder / "ca.pem"),
                "-CAkey",
                str(folder / "ca-do-not-share.key"),
                "-passin",
                "env:IDENTITY_CA_PASSWORD",
                "-set_serial",
                str(secrets.randbits(159) or 1),
                "-extfile",
                str(extensions),
                "-out",
                str(work / "identity.pem"),
            ],
            env=environment,
        )
        (work / "identity.pem").write_bytes(
            (work / "identity.pem").read_bytes() + (folder / "ca.pem").read_bytes()
        )
        (work / "identity.key").chmod(0o600)
        os.replace(work / "identity.key", key)
        os.replace(work / "identity.pem", certificate)
