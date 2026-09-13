"""Initialize standalone TAK without RASENMAEHER, preserving administrator state."""

import fcntl
import os
import re
import shutil
import subprocess
import tempfile
from datetime import UTC, datetime
from pathlib import Path

import tls_identity


def prepare_directories(root: Path, scripts: Path) -> Path:
    """Keep distribution certificate tools and logs available through legacy paths."""
    certs = root / "data/certs"
    certs.mkdir(parents=True, exist_ok=True)
    if not any(certs.iterdir()):
        # copytree also copies private image-layer SELinux labels, preventing
        # other sidecars from reading the shared volume. cp -R inherits its labels.
        subprocess.run(["cp", "-R", str(root / "certs") + "/.", str(certs)], check=True)
    metadata = certs / "cert-metadata.sh"
    metadata.write_text(
        metadata.read_text().replace("COUNTRY=US", "COUNTRY=${COUNTRY:-US}")
    )
    shutil.copyfile(scripts / "makeCert.sh", certs / "makeCert.sh")
    for name in ("certs", "logs"):
        destination = root / "data" / name
        destination.mkdir(exist_ok=True)
        link = root / name
        if not link.is_symlink():
            if link.exists():
                # Image-layer directories cannot always be renamed on OverlayFS.
                shutil.move(link, root / f"{name}.orig")
            link.symlink_to(destination)
    return certs


def ensure_ca(certs: Path, password: str) -> None:
    """Stage legacy CA generation so its automatic truststore copy cannot overwrite federation trust."""
    files = certs / "files"
    files.mkdir(exist_ok=True)
    certificate = files / "ca.pem"
    key = files / "ca-do-not-share.key"
    if certificate.exists() and key.exists():
        return
    if certificate.exists() or key.exists():
        raise ValueError(
            "Incomplete local CA; restore its certificate and key before initialization"
        )
    with tempfile.TemporaryDirectory(
        prefix=".local-ca-", dir=certs.parent
    ) as temporary:
        stage = Path(temporary)
        for source in certs.iterdir():
            if source.is_file():
                shutil.copy2(source, stage / source.name)
        tls_identity.run(
            [
                "bash",
                "makeRootCa.sh",
                "--ca-name",
                os.environ.get("CA_NAME") or "TAKRootCA",
            ],
            cwd=stage,
            env=dict(os.environ, CAPASS=password),
        )
        for required in ("ca.pem", "ca-do-not-share.key", "truststore-root.jks"):
            if not (stage / "files" / required).is_file():
                raise RuntimeError(f"CA generation did not create {required}")
        for source in (stage / "files").iterdir():
            if source.name != "fed-truststore.jks":
                # Never replace pre-existing administrator files during CA creation.
                os.link(source, files / source.name)


def prepare_certificates(root: Path, scripts: Path) -> None:
    """Refresh separate TLS stores while preserving identities and federation trust."""
    password = os.environ["TAKSERVER_CERT_PASS"]
    ca_password = os.environ["CA_PASS"]
    if len(password) < 6 or len(ca_password) < 6:
        raise ValueError(
            "TAKSERVER_CERT_PASS and CA_PASS must contain at least six characters"
        )
    hostname = os.environ["TAK_SERVER_ADDRESS"]
    https_key = os.environ.get("TAK_HTTPS_KEY_FILENAME")
    https_certificate = os.environ.get("TAK_HTTPS_CERT_FILENAME")
    if bool(https_key) != bool(https_certificate):
        raise ValueError("Set both TAK_HTTPS_KEY_FILENAME and TAK_HTTPS_CERT_FILENAME")
    files = root / "data/certs/files"
    https_store = Path(
        os.environ.get("TAK_HTTPS_KEYSTORE_FILENAME")
        or str(files / "takserver-https.jks")
    )
    if https_store.resolve() == (files / "takserver.jks").resolve():
        raise ValueError("HTTPS must use a separate keystore from CoT")
    certs = prepare_directories(root, scripts)
    ensure_ca(certs, ca_password)

    tls_identity.create_local_identity(
        files, "takserver", hostname, password, ca_password, "RSA"
    )
    environment = dict(os.environ, IDENTITY_KEY_PASSWORD=password)
    tls_identity.run(
        [
            "openssl",
            "rsa",
            "-in",
            str(files / "takserver.key"),
            "-passin",
            "env:IDENTITY_KEY_PASSWORD",
            "-check",
            "-noout",
        ],
        env=environment,
    )
    tls_identity.import_identity(
        files / "takserver.key",
        files / "takserver.pem",
        files / "takserver.jks",
        password,
        password,
    )

    if https_key and https_certificate:
        key = Path(https_key)
        certificate = Path(https_certificate)
        key_password = os.environ.get("TAK_HTTPS_KEY_PASSWORD", "")
    else:
        tls_identity.create_local_identity(
            files, "takserver-https", hostname, password, ca_password, "EC"
        )
        key, certificate = files / "takserver-https.key", files / "takserver-https.pem"
        key_password = password
    tls_identity.import_identity(
        key, certificate, https_store, password, key_password, "takserver-https"
    )

    subprocess.run(
        [
            "/usr/bin/python3",
            str(scripts / "init-fed-truststore.py"),
            str(files / "fed-truststore.jks"),
            str(files / "takserver.pem"),
            str(files / "ca.pem"),
        ],
        check=True,
        env=dict(os.environ, KEYSTORE_PASS=ca_password),
    )
    admin = os.environ.get("ADMIN_CERT_NAME") or "admin"
    if not re.fullmatch(r"[A-Za-z0-9_-]+", admin):
        raise ValueError(
            "ADMIN_CERT_NAME must contain only letters, digits, underscores or hyphens"
        )
    if not (files / f"{admin}.pem").exists():
        if (files / f"{admin}.key").exists():
            raise ValueError(
                "Incomplete administrator identity; restore its certificate"
            )
        tls_identity.run(
            ["bash", "makeCert.sh", "client", admin],
            cwd=certs,
            env=dict(
                os.environ, CAPASS=ca_password, PASS=os.environ["ADMIN_CERT_PASS"]
            ),
        )
        for suffix in ("pem", "key", "jks"):
            if not (files / f"{admin}.{suffix}").is_file():
                raise RuntimeError(
                    f"Administrator certificate generation did not create {admin}.{suffix}"
                )


def upgrade_database(root: Path) -> None:
    """Keep standalone database initialization independent of RASENMAEHER."""
    host = os.environ["POSTGRES_ADDRESS"]
    subprocess.run(
        ["/usr/bin/wait-for-it.sh", f"{host}:5432", "--", "true"],
        check=True,
        env=dict(os.environ, WAITFORIT_TIMEOUT="60"),
    )
    user = os.environ.get("POSTGRES_SUPERUSER") or os.environ["POSTGRES_USER"]
    password = (
        os.environ.get("POSTGRES_SUPER_PASSWORD") or os.environ["POSTGRES_PASSWORD"]
    )
    try:
        tls_identity.run(
            [
                "java",
                "-jar",
                str(root / "db-utils/SchemaManager.jar"),
                "-url",
                f"jdbc:postgresql://{host}:5432/{os.environ['POSTGRES_DB']}",
                "-user",
                user,
                "-password",
                password,
                "upgrade",
            ]
        )
    except subprocess.CalledProcessError:
        raise RuntimeError(
            "Standalone TAK database schema initialization failed"
        ) from None


def initialize(root: Path, scripts: Path) -> None:
    """Reconcile certificates on each initialization; run database setup only once."""
    data = root / "data"
    data.mkdir(parents=True, exist_ok=True)
    with (data / ".standalone-init.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        prepare_certificates(root, scripts)
        marker = data / "firstrun.done"
        if not marker.exists():
            upgrade_database(root)
            marker.write_text(datetime.now(UTC).strftime("%Y%m%dT%H%M") + "\n")


if __name__ == "__main__":
    initialize(Path("/opt/tak"), Path("/opt/scripts"))
