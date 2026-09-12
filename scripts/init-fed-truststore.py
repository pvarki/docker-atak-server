"""Initialize public federation trust once, preserving administrator changes."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import ssl
import subprocess
import tempfile


def initialize(destination: Path, identity: Path, chain: Path) -> None:
    """Import the product certificate and local CA chain without any private keys."""
    if destination.exists():
        if not destination.is_file():
            raise ValueError(f"Truststore is not a regular file: {destination}")
        print(f"Preserving existing federation truststore: {destination}")
        return
    if destination.is_symlink():
        raise ValueError(f"Truststore is a dangling symlink: {destination}")
    if not os.environ.get("KEYSTORE_PASS"):
        raise ValueError("KEYSTORE_PASS must be set for initial federation trust")

    with tempfile.TemporaryDirectory(
        prefix=".fed-truststore-", dir=destination.parent
    ) as folder:
        workdir = Path(folder)
        store = workdir / "truststore.jks"
        seen = set()
        for source in (chain, identity):
            # OpenSSL validates and normalizes the public PEM certificates.
            bundle = subprocess.run(
                ["openssl", "crl2pkcs7", "-nocrl", "-certfile", str(source)],
                check=True,
                capture_output=True,
            ).stdout
            public = subprocess.run(
                ["openssl", "pkcs7", "-print_certs"],
                input=bundle,
                check=True,
                capture_output=True,
            ).stdout.decode("ascii")
            certificates = re.findall(
                r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----",
                public,
                re.DOTALL,
            )
            if not certificates:
                raise ValueError(f"No certificates in {source}")
            for pem in certificates:
                alias = hashlib.sha256(ssl.PEM_cert_to_DER_cert(pem)).hexdigest()
                if alias in seen:
                    continue
                seen.add(alias)
                certificate = workdir / f"{alias}.pem"
                certificate.write_text(pem + "\n", encoding="ascii")
                subprocess.run(
                    [
                        "keytool",
                        "-noprompt",
                        "-importcert",
                        "-trustcacerts",
                        "-storetype",
                        "JKS",
                        "-file",
                        str(certificate),
                        "-alias",
                        alias,
                        "-keystore",
                        str(store),
                        "-storepass:env",
                        "KEYSTORE_PASS",
                    ],
                    check=True,
                )
        store.chmod(0o600)
        # Atomic publication without replacing a concurrently initialized store.
        try:
            os.link(store, destination)
        except FileExistsError:
            if not destination.is_file():
                raise


def main() -> None:
    """Run from the initialization entrypoint."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("identity", type=Path)
    parser.add_argument("chain", type=Path)
    args = parser.parse_args()
    initialize(args.destination, args.identity, args.chain)


if __name__ == "__main__":
    main()
