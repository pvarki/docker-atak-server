"""Run TAKCL with a private client configuration and a remote discovery seed."""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

from ignite_config import resolve_bind_address
from lxml import etree


def write_configuration(root: Path, directory: Path, address: str) -> Path:
    """TAKCL requires unicast discovery; the server's multicast XML cannot be reused."""
    common = "http://bbn.com/marti/takcl/config/common"
    config = etree.Element(
        "TAKCLConfiguration", nsmap={None: "http://bbn.com/marti/takcl/config"}
    )
    for name in ("TemporaryDirectory", "FallbackTemporaryDirectory"):
        etree.SubElement(config, f"{{{common}}}{name}").text = str(directory)
    etree.SubElement(
        config,
        f"{{{common}}}RunnableTAKServerConfig",
        modelServerDir=str(directory),
        serverFarmDir=str(directory),
        jarName="takserver-core.jar",
        TAKIgniteConfigFile="TAKIgniteConfig.xml",
        certificateDirectory=str(root / "data/certs/files"),
        certToolDirectory=str(root / "data/certs"),
    )
    path = directory / "TAKCLConfig.xml"
    path.write_bytes(etree.tostring(config, xml_declaration=True, encoding="UTF-8"))
    ignite = etree.Element(
        "TAKIgniteConfiguration",
        nsmap={None: "http://bbn.com/marti/xml/config"},
        igniteHost=address,
        igniteMulticast="false",
        ignitePoolSize="2",
        cacheOffHeapInitialSizeBytes="16777216",
        cacheOffHeapMaxSizeBytes="67108864",
    )
    (directory / "TAKIgniteConfig.xml").write_bytes(
        etree.tostring(ignite, xml_declaration=True, encoding="UTF-8")
    )
    return path


def main() -> int:
    """Keep work files private and clean them up when the CLI JVM exits."""
    root = Path("/opt/tak")
    address = resolve_bind_address(os.environ.get("TAK_IGNITE_BIND_ADDRESS", ""))
    host = os.environ.get("TAK_MESSAGING_HOST", "takmsg-ignite")
    with tempfile.TemporaryDirectory(prefix="tak-usermanager-") as folder:
        directory = Path(folder)
        path = write_configuration(root, directory, address)
        return subprocess.run(
            [
                "java",
                "-Xmx256m",
                f"-Dcom.bbn.marti.takcl.config.filepath={path}",
                f"-Dcom.bbn.marti.takcl.takIgniteConfigPath={directory / 'TAKIgniteConfig.xml'}",
                "-Dcom.bbn.marti.takcl.ignoreCoreConfig=true",
                f"-Dcom.bbn.marti.takcl.igniteIpAddressOverride={host}",
                "-Dcom.bbn.marti.takcl.igniteNetworkTimeout=10000",
                "-Dcom.bbn.marti.takcl.igniteClientFailureDetectionTimeout=30000",
                "-jar",
                str(root / "utils/UserManager.jar"),
                *sys.argv[1:],
            ],
            env=dict(os.environ, IGNITE_WORK_DIR=folder),
            check=False,
        ).returncode


if __name__ == "__main__":
    sys.exit(main())
