"""Check current configuration ownership and listeners in this network namespace."""

import argparse
import socket
from pathlib import Path

import coreconfig
import start_tak
from lxml import etree


def listening_addresses(table: Path = Path("/proc/net/tcp")) -> set[tuple[str, int]]:
    """Read IPv4 listening sockets without opening incomplete Ignite handshakes."""
    listeners = set()
    for row in table.read_text().splitlines()[1:]:
        fields = row.split()
        if fields[3] == "0A":
            address, port = fields[1].split(":")
            listeners.add(
                (socket.inet_ntoa(bytes.fromhex(address)[::-1]), int(port, 16))
            )
    return listeners


def check(profile: str, root: Path = Path("/opt/tak")) -> None:
    """Require local Ignite transport plus the role's application readiness."""
    start_tak.wait_for_configuration(root / "data", timeout=0)
    ignite = etree.parse(str(root / "runtime" / profile / "TAKIgniteConfig.xml"))
    address = ignite.getroot().get("igniteHost", "")
    listeners = listening_addresses()
    if (address, 47100) not in listeners or (address, 10800) not in listeners:
        raise RuntimeError("Local Ignite communication/client listeners are not ready")
    config = coreconfig.read_xml(root / "CoreConfig.xml")
    paths = {
        "messaging": (
            "network/input[@_name='stdssl']",
            "network/input[@_name='stdssl-noarchive']",
        ),
        "api": ("network/connector[@_name='https']",),
    }
    for path in paths.get(profile, ()):
        port = int(coreconfig.require(config, path).get("port", "0"))
        if not any((host, port) in listeners for host in (address, "0.0.0.0")):
            raise RuntimeError(f"Application listener {port} is not ready")
    if profile == "pm" and not (root / "runtime" / profile / "ready").exists():
        raise RuntimeError("Plugin Spring application is not ready")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "profile", choices=("config", "messaging", "api", "retention", "pm")
    )
    check(parser.parse_args().profile)
