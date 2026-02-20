#!/usr/bin/env python3
"""Create bakefile from 'docker compose config --format json' output"""
from typing import Dict, Any, Sequence, Tuple, List
import asyncio
import json
import sys
import datetime
import os

VITE_THEMES = ("default", "fdf")
PLATFORMS = ("linux/amd64",)  #  add "linux/arm64" when we can actually build them
ISODATE = datetime.datetime.now(datetime.UTC).date().isoformat()
ORIG_REPO = "ghcr.io"
ALT_REPOS = ("docker.io", os.environ.get("ACR_REPO", None))


def service_hcl(
    servicename: str, servicedef: Dict[str, Any]
) -> Tuple[Sequence[str], str]:
    """Make the HCL"""
    hcl_targets = ""
    tgtname = servicename
    imgtags_orig = [f"{servicedef['image']}", f"{servicedef['image']}-{ISODATE}"]
    imgtags_more = []
    for alt_repo in ALT_REPOS:
        if not alt_repo:
            continue
        imgtags_more += [tag.replace(ORIG_REPO, alt_repo) for tag in imgtags_orig]
    imgtags = imgtags_orig + imgtags_more
    hcl_targets += f"""
target "{tgtname}" {{
    tags = [{", ".join(f'"{imgtag}"' for imgtag in imgtags)}]
    dockerfile = "{servicedef['build']['dockerfile']}"
    context = "{servicedef['build']['context']}"
    platforms = [{", ".join(f'"{platform}"' for platform in PLATFORMS)}]
"""
    if "target" in servicedef["build"]:
        hcl_targets += f"""    target = "{servicedef['build']['target']}"\n"""

    if "args" in servicedef["build"]:
        hcl_targets += "    args = {\n"
        for argname, argval in servicedef["build"]["args"].items():
            hcl_targets += f"""        {argname}: "{argval}"\n"""
        hcl_targets += "    }\n"

    hcl_targets += "}"
    return [tgtname], hcl_targets


async def main() -> None:
    """Main entry point."""
    parsed = json.loads(sys.stdin.read())
    targets: List[str] = []
    hcl_targets = ""
    for servicename, servicedef in parsed["services"].items():
        if "build" not in servicedef:
            continue
        if servicename not in ("takserver_initialization",):
            continue
        ret_tgts, ret_hcl = service_hcl(servicename, servicedef)
        hcl_targets += ret_hcl
        targets += ret_tgts
    print(
        f"""
group "default" {{
    targets = [{", ".join(f'"{tgt}"' for tgt in targets)}]
}}
"""
    )
    print(hcl_targets)


if __name__ == "__main__":
    asyncio.run(main())
