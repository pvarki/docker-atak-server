"""Prepare shared configuration once and launch a TAK service."""

import argparse
import fcntl
import os
import subprocess
import tempfile
import time
import uuid
from pathlib import Path
from typing import TextIO

import coreconfig


def link_file(link: Path, target: Path) -> None:
    """Atomically replace a compatibility link."""
    with tempfile.TemporaryDirectory(prefix=".config-link-", dir=link.parent) as folder:
        temporary = Path(folder) / "link"
        temporary.symlink_to(target)
        os.replace(temporary, link)


def prepare_configuration(root: Path, templates: Path) -> None:
    """Only the configuration service updates files in the shared volume."""
    data = root / "data"
    canonical = data / "CoreConfig_config.xml"
    common = data / "CoreConfig.xml"
    with tempfile.TemporaryDirectory(prefix=".config-render-", dir=data) as folder:
        rendered = Path(folder) / "CoreConfig.xml"
        with rendered.open("wb") as stream:
            subprocess.run(
                ["gomplate", "-f", str(templates / "CoreConfig.tpl")],
                stdout=stream,
                check=True,
            )
        coreconfig.prepare(rendered, canonical, root / "CoreConfig.xsd", common)

    backup = data / "CoreConfig.xml.pre-authority-backup"
    if common.exists() and not common.is_symlink() and not backup.exists():
        coreconfig.atomic_write(backup, common.read_bytes())
    link_file(common, canonical)
    ignite = subprocess.run(
        ["gomplate", "-f", str(templates / "TAKIgniteConfig.tpl")],
        check=True,
        capture_output=True,
    ).stdout
    coreconfig.atomic_write(data / "TAKIgniteConfig.xml", ignite)


def acquire_config_lock(data: Path) -> tuple[TextIO, str]:
    """Hold exclusive ownership until the configuration JVM exits."""
    lock = (data / ".coreconfig-service.lock").open("a+")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        lock.close()
        raise RuntimeError(
            "Another TAK configuration service already owns this volume"
        ) from None
    generation = uuid.uuid4().hex
    lock.seek(0)
    lock.truncate()
    lock.write(generation)
    lock.flush()
    os.fsync(lock.fileno())
    os.set_inheritable(lock.fileno(), True)
    return lock, generation


def wait_for_configuration(data: Path, timeout: float = 180) -> None:
    """Wait for the current config service, ignoring readiness left by an older run."""
    deadline = time.monotonic() + timeout
    while True:
        try:
            with (data / ".coreconfig-service.lock").open() as lock:
                try:
                    fcntl.flock(lock, fcntl.LOCK_SH | fcntl.LOCK_NB)
                except BlockingIOError:
                    generation = lock.read()
                    ready = (data / ".coreconfig-ready").read_text()
                    if generation and generation == ready:
                        return
        except FileNotFoundError:
            pass
        if time.monotonic() >= deadline:
            raise TimeoutError(
                "TAK configuration service did not prepare the shared configuration"
            )
        time.sleep(0.2)


def main() -> None:
    """Keep the ownership lock across exec; followers never render shared XML."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "profile", choices=("config", "messaging", "api", "retention", "pm")
    )
    args = parser.parse_args()
    root = Path("/opt/tak")
    data = root / "data"
    data.mkdir(parents=True, exist_ok=True)
    if args.profile == "config":
        lock, generation = acquire_config_lock(data)
        # Keep the descriptor open through exec and throughout the JVM lifetime.
        try:
            prepare_configuration(root, Path("/opt/templates"))
            coreconfig.atomic_write(data / ".coreconfig-ready", generation.encode())
        except BaseException:
            lock.close()
            raise
    else:
        wait_for_configuration(data)
    canonical = data / "CoreConfig_config.xml"
    link_file(root / "CoreConfig.xml", canonical)
    link_file(root / "TAKIgniteConfig.xml", data / "TAKIgniteConfig.xml")
    os.environ["TAKCL_CORECONFIG_PATH"] = str(canonical)
    os.execv("/bin/bash", ["/bin/bash", "/opt/scripts/run-tak.sh", args.profile])


if __name__ == "__main__":
    main()
