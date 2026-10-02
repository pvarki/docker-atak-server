import json
import unittest
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
PR_FILE = REPO_ROOT / ".github/workflows/pull_request.yml"
PUSH_FILE = REPO_ROOT / ".github/workflows/push_to_main.yml"

# Keys in publish-image `with:` that differ intentionally between workflows
ALLOWED_DIFFS = {"extra-tag"}


def load_workflow(path: Path) -> dict:
    return yaml.safe_load(path.read_text())


def normalize_publish(job: dict) -> dict:
    """Strip dynamic values (env/secrets/vars) for comparison."""
    steps = []
    for step in job.get("steps", []):
        normalized = dict(step)
        if "with" in normalized:
            normalized["with"] = {
                k: v for k, v in normalized["with"].items() if k not in ALLOWED_DIFFS
            }
        steps.append(normalized)
    return {
        "runs-on": job.get("runs-on"),
        "permissions": job.get("permissions"),
        "steps": steps,
    }


class TestCIParity(unittest.TestCase):
    """Ensure build_and_publish jobs match between PR and main workflows.

    Catches drift like b290817 (wrong runner) and beaab16 (missing git-lfs).
    """

    def test_build_and_publish_parity(self) -> None:
        pr = load_workflow(PR_FILE)
        push = load_workflow(PUSH_FILE)

        pr_job = pr["jobs"]["build_and_publish"]
        push_job = push["jobs"]["build_and_publish"]

        pr_norm = normalize_publish(pr_job)
        push_norm = normalize_publish(push_job)

        self.assertEqual(
            json.dumps(push_norm, sort_keys=True),
            json.dumps(pr_norm, sort_keys=True),
            "build_and_publish jobs differ. "
            "Update push_to_main.yml to match pull_request.yml.",
        )

    def test_tak_release_sync(self) -> None:
        pr = load_workflow(PR_FILE)
        push = load_workflow(PUSH_FILE)

        self.assertEqual(
            pr.get("env", {}).get("TAK_RELEASE"),
            push.get("env", {}).get("TAK_RELEASE"),
            "TAK_RELEASE env var must match in both workflows.",
        )


if __name__ == "__main__":
    unittest.main()
