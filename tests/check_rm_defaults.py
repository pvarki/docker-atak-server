"""Exercise firstrun_rm.sh defaults in a disposable TAK image, without external services."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import tls_identity  # noqa: E402


def main():
    environment = dict(os.environ)
    for name in list(environment):
        if name.startswith("TAK_HTTPS_") or name in (
            "TAKSERVER_KEYSTORE_PASS",
            "KEYSTORE_PASS",
            "TAK_SERVER_KEY_FILENAME",
            "TAK_SERVER_CERT_FILENAME",
            "RM_CERT_CHAIN_FILENAME",
        ):
            environment.pop(name)
    environment.update(
        TAKSERVER_CERT_PASS="test-identity", CA_PASS="test-ca"
    )  # pragma: allowlist secret
    with tempfile.TemporaryDirectory() as temporary:
        work = Path(temporary)
        local = work / "local"
        public = work / "public"
        local.mkdir()
        public.mkdir()
        for directory, name in ((local, "internal-root"), (public, "https-root")):
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
                    str(directory / "ca-do-not-share.key"),
                    "-out",
                    str(directory / "ca.pem"),
                    "-passout",
                    "env:CA_PASS",
                    "-days",
                    "1",
                    "-subj",
                    f"/CN={name}",
                ],
                env=environment,
            )
        root = (local / "ca.pem").read_bytes()
        tls_identity.run(
            [
                "openssl",
                "req",
                "-new",
                "-newkey",
                "ec",
                "-pkeyopt",
                "ec_paramgen_curve:P-256",
                "-keyout",
                str(local / "intermediate.key"),
                "-out",
                str(local / "intermediate.csr"),
                "-passout",
                "env:CA_PASS",
                "-subj",
                "/CN=internal-intermediate",
            ],
            env=environment,
        )
        extensions = work / "ca.cnf"
        extensions.write_text(
            "basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\n"
        )
        tls_identity.run(
            [
                "openssl",
                "x509",
                "-req",
                "-in",
                str(local / "intermediate.csr"),
                "-CA",
                str(local / "ca.pem"),
                "-CAkey",
                str(local / "ca-do-not-share.key"),
                "-passin",
                "env:CA_PASS",
                "-set_serial",
                "2",
                "-extfile",
                str(extensions),
                "-days",
                "1",
                "-out",
                str(local / "intermediate.pem"),
            ],
            env=environment,
        )
        intermediate = (local / "intermediate.pem").read_bytes()
        (local / "ca.pem").write_bytes(intermediate + root)
        (local / "ca-do-not-share.key").write_bytes(
            (local / "intermediate.key").read_bytes()
        )
        for directory, name, keytype in (
            (local, "product", "RSA"),
            (public, "https", "EC"),
        ):
            tls_identity.create_local_identity(
                directory,
                name,
                "tak.test",
                environment["CA_PASS"],
                environment["CA_PASS"],
                keytype,
            )

        for folder in (
            "/data/persistent/private",
            "/data/persistent/public",
            "/le_certs/rasenmaeher",
            "/ca_public",
            "/pvarki",
            "/opt/tak/data",
        ):
            Path(folder).mkdir(parents=True, exist_ok=True)
        for directory, name, keypath, certpath in (
            (
                local,
                "product",
                "/data/persistent/private/mtlsclient.key",
                "/data/persistent/public/mtlsclient.pem",
            ),
            (
                public,
                "https",
                "/le_certs/rasenmaeher/privkey.pem",
                "/le_certs/rasenmaeher/fullchain.pem",
            ),
        ):
            tls_identity.run(
                [
                    "openssl",
                    "pkey",
                    "-in",
                    str(directory / f"{name}.key"),
                    "-passin",
                    "env:CA_PASS",
                    "-out",
                    keypath,
                ],
                env=environment,
            )
            Path(certpath).write_bytes((directory / f"{name}.pem").read_bytes())
        Path("/ca_public/root_ca.pem").write_bytes(root)
        Path("/ca_public/intermediate_ca.pem").write_bytes(intermediate)
        Path("/ca_public/ca_chain.pem").write_bytes(intermediate + root)
        Path("/pvarki/kraftwerk-init.json").write_text(
            json.dumps(
                {
                    "product": {"dns": "tak.test"},
                    "rasenmaeher": {"init": {"base_uri": "https://rm.test"}},
                }
            )
        )
        # Reuse a product identity and an initialized database; no RMAPI or DB mocks run.
        Path("/opt/tak/data/firstrun.done").touch()
        subprocess.run(
            ["bash", "/opt/scripts/firstrun_rm.sh"], env=environment, check=True
        )
        exported = []
        for name, source in (
            ("takserver", local / "product.pem"),
            ("takserver-https", public / "https.pem"),
        ):
            actual = tls_identity.run(
                [
                    "keytool",
                    "-exportcert",
                    "-alias",
                    "tak.test",
                    "-keystore",
                    f"/opt/tak/data/certs/files/{name}.jks",
                    "-storepass:env",
                    "TAKSERVER_CERT_PASS",
                ],
                env=environment,
            )
            expected = tls_identity.run(
                ["openssl", "x509", "-in", str(source), "-outform", "DER"]
            )
            if actual != expected:
                raise AssertionError(f"Wrong certificate in {name}.jks")
            exported.append(actual)
        if exported[0] == exported[1]:
            raise AssertionError("CoT and HTTPS unexpectedly use the same certificate")
        tls_identity.run(
            [
                "keytool",
                "-list",
                "-keystore",
                "/opt/tak/data/certs/files/truststore-root.jks",
                "-storepass:env",
                "CA_PASS",
            ],
            env=environment,
        )
        print(
            "PASS: RASENMAEHER defaults use distinct CFSSL CoT and external HTTPS certificates with runtime-compatible passwords"
        )


if __name__ == "__main__":
    main()
