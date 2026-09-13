"""Readiness must describe this container and this configuration generation."""

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import healthcheck  # noqa: E402


class HealthcheckTest(unittest.TestCase):
    def test_listeners_exclude_connected_sockets(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            table = Path(directory) / "tcp"
            table.write_text(
                "header\n0: 0200000A:B7FC 00000000:0000 0A\n"
                "1: 0100007F:B7FC 00000000:0000 01\n"
            )
            self.assertEqual(
                healthcheck.listening_addresses(table), {("10.0.0.2", 47100)}
            )

    def test_stale_configuration_owner_fails_before_socket_check(self) -> None:
        with (
            patch.object(
                healthcheck.start_tak,
                "wait_for_configuration",
                side_effect=TimeoutError,
            ),
            patch.object(healthcheck, "listening_addresses") as listeners,
            self.assertRaises(TimeoutError),
        ):
            healthcheck.check("config")
        listeners.assert_not_called()

    def test_requires_local_bind_and_plugin_application_start(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runtime = root / "runtime/pm"
            runtime.mkdir(parents=True)
            (runtime / "TAKIgniteConfig.xml").write_text(
                '<config igniteHost="10.0.0.2"/>'
            )
            (root / "CoreConfig.xml").write_text(
                '<Configuration xmlns="http://bbn.com/marti/xml/config"/>'
            )
            with (
                patch.object(healthcheck.start_tak, "wait_for_configuration"),
                patch.object(healthcheck, "listening_addresses") as listeners,
            ):
                listeners.return_value = {("127.0.0.1", 47100), ("127.0.0.1", 10800)}
                with self.assertRaisesRegex(RuntimeError, "Local Ignite"):
                    healthcheck.check("pm", root)
                listeners.return_value = {("10.0.0.2", 47100), ("10.0.0.2", 10800)}
                with self.assertRaisesRegex(RuntimeError, "Plugin Spring"):
                    healthcheck.check("pm", root)
                (runtime / "ready").touch()
                healthcheck.check("pm", root)
