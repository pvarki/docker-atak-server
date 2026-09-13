"""Prepare Ignite settings local to one container, independently of CoreConfig."""

import ipaddress
import os
import socket
import subprocess
from pathlib import Path

import coreconfig
from lxml import etree


def resolve_bind_address(address: str = "") -> str:
    """Resolve a container hostname or explicit IPv4 address and verify ownership."""
    resolved = socket.gethostbyname(address or socket.gethostname())
    parsed = ipaddress.IPv4Address(resolved)
    if parsed.is_unspecified or parsed.is_multicast or parsed.is_loopback:
        raise ValueError("Ignite must bind to a routable local container IPv4 address")
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind((resolved, 0))
    return resolved


def prepare(root: Path, templates: Path, profile: str) -> Path:
    """Render and validate per-process XML without writing to the shared volume."""
    address = resolve_bind_address(os.environ.get("TAK_IGNITE_BIND_ADDRESS", ""))
    seeds = os.environ.get("TAK_IGNITE_SEEDS", "takmsg-ignite:47500").strip()
    if not seeds:
        raise ValueError("TAK_IGNITE_SEEDS must contain an Ignite discovery address")
    runtime = root / "runtime" / profile
    runtime.mkdir(parents=True, exist_ok=True)
    (runtime / "ready").unlink(missing_ok=True)
    os.environ["TAK_RUNTIME_DIR"] = str(runtime)
    work = Path(os.environ.get("IGNITE_WORK_DIR", str(runtime / "ignite")))
    work.mkdir(parents=True, exist_ok=True)
    os.environ["IGNITE_WORK_DIR"] = str(work)
    os.environ["IGNITE_TCP_DISCOVERY_ADDRESSES"] = seeds
    rendered = subprocess.run(
        ["gomplate", "-f", str(templates / "TAKIgniteConfig.tpl")],
        env=dict(os.environ, TAK_IGNITE_BIND_ADDRESS=address),
        capture_output=True,
        check=True,
    ).stdout
    configuration = etree.fromstring(rendered)
    etree.XMLSchema(etree.parse(str(root / "TAKIgniteConfig.xsd"))).assertValid(
        configuration
    )
    destination = runtime / "TAKIgniteConfig.xml"
    coreconfig.atomic_write(destination, rendered)
    return destination
