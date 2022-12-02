"""Test CLI scripts"""
import asyncio

import pytest
from libadvian.binpackers import ensure_str

from takcertsapi import __version__


@pytest.mark.asyncio
async def test_version_cli():  # type: ignore
    """Test the CLI parsing for default version dumping works"""
    cmd = "takcertsapi --version"
    process = await asyncio.create_subprocess_shell(
        cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    out = await asyncio.wait_for(process.communicate(), 10)
    # Demand clean exit
    assert process.returncode == 0
    # Check output
    assert ensure_str(out[0]).strip().endswith(__version__)


@pytest.mark.asyncio
async def test_cli_output():  # type: ignore
    """Run the entrypoint and check output"""
    cmd = "takcertsapi"
    process = await asyncio.create_subprocess_shell(
        cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    out = await asyncio.wait_for(process.communicate(), 10)
    # Demand clean exit
    assert process.returncode == 0
    # Check output
    assert ensure_str(out[0]).strip().endswith("Do your thing")
