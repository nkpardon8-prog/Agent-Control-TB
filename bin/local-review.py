#!/usr/bin/env python3
"""
local-review.py — On-demand local code review via LM Studio.
Writes a structured markdown report to <cwd>/.claude/reviews/
Usage: python3 local-review.py [optional: file1 file2 ...]
"""

import urllib.request
import urllib.error
import json
import subprocess
import datetime
import os
import sys
from pathlib import Path

BASE_DIR = Path(os.environ.get("AGENT_CONTROL_TB_HOME", str(Path.home() / ".agent-control-tb"))).expanduser()
CONFIG_PATH = BASE_DIR / "config" / "config.json"
STATE_DIR = BASE_DIR / "state"


def check_review_enabled():
    state_file = STATE_DIR / "review_enabled"
    try:
        enabled = state_file.read_text().strip()
    except FileNotFoundError:
        enabled = "false"
    if enabled != "true":
        print("Local review is disabled. Run /toggle-local-review to enable.")
        sys.exit(2)


def check_lmstudio(base_url):
    try:
        urllib.request.urlopen(f"{base_url}/v1/models", timeout=2)
    except (urllib.error.URLError, OSError):
        print(f"ERROR: LM Studio server not reachable at {base_url}")
        print("Start it: open LM Studio -> Developer tab -> toggle 'Start server' ON")
        print("Or run: ~/.lmstudio/bin/lms server start")
        sys.exit(1)


def get_diff():
    if len(sys.argv) > 1:
        # Files passed as arguments
        try:
            return subprocess.check_output(
                ["git", "diff", "--"] + sys.argv[1:], text=True
            )
        except subprocess.CalledProcessError as e:
            print(f"ERROR: git diff failed: {e}")
            sys.exit(1)

    # Try staged changes first
    diff = subprocess.check_output(["git", "diff", "--cached"], text=True)
    if diff.strip():
        return diff

    # Fall back to HEAD~1
    try:
        diff = subprocess.check_output(
            ["git", "diff", "HEAD~1"], text=True, stderr=subprocess.DEVNULL
        )
        if diff.strip():
            return diff
    except subprocess.CalledProcessError:
        pass  # single-commit repo or no history

    print("No diff found. Stage changes or pass file paths as arguments.")
    print("Examples:")
    print("  git add -p && python3 local-review.py")
    print("  python3 local-review.py src/myfile.py")
    sys.exit(1)


def read_config():
    try:
        return json.loads(CONFIG_PATH.read_text())
    except FileNotFoundError:
        print(f"ERROR: Config not found at {CONFIG_PATH}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: Config is not valid JSON: {e}")
        sys.exit(1)


def call_lmstudio(base_url, model, diff):
    prompt = f"""You are a senior code reviewer. Review the following git diff carefully.

Produce a structured markdown review with these exact sections:

## Executive Summary

## Findings by Severity
### Critical
### High
### Medium
### Low / Nitpick

## File-by-File Notes

## Suggested Fixes

## Confidence & Caveats

## Recommended Next Action

Diff to review:
```diff
{diff[:12000]}
```"""

    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 8192,
        "temperature": 0.2,
    }

    req = urllib.request.Request(
        f"{base_url}/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer lmstudio",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read())
    except urllib.error.URLError as e:
        print(f"ERROR: Request to LM Studio failed: {e}")
        sys.exit(1)

    message = result["choices"][0]["message"]
    content = message.get("content") or ""
    if content.strip():
        return content

    reasoning = message.get("reasoning_content") or ""
    if reasoning.strip():
        return (
            "Model returned reasoning content but no final answer. "
            "Reviewing the reasoning output instead.\n\n"
            + reasoning
        )

    return "Model returned an empty review."


def write_report(diff, review_text, base_url, model):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S")
    review_dir = Path.cwd() / ".claude" / "reviews"
    review_dir.mkdir(parents=True, exist_ok=True)
    report_path = review_dir / f"{timestamp}-review.md"

    header = f"""# Local Review Report

- **Date**: {datetime.datetime.now().isoformat()}
- **Backend**: LM Studio ({base_url})
- **Model**: {model}
- **Diff lines**: {len(diff.splitlines())}

---

"""
    report_path.write_text(header + review_text, encoding="utf-8")
    return report_path


def main():
    check_review_enabled()
    config = read_config()
    base_url = config["lmstudio_base_url"]
    check_lmstudio(base_url)

    diff = get_diff()
    model = config["review_model"]

    print(f"Running review with model: {model}")
    print(f"Diff size: {len(diff.splitlines())} lines")
    print("Sending to LM Studio... (may take 30-120s)")

    review_text = call_lmstudio(base_url, model, diff)
    report_path = write_report(diff, review_text, base_url, model)

    print(f"\nReview complete!")
    print(f"Report: {report_path}")
    print(f"Open:   open '{report_path}'")


if __name__ == "__main__":
    main()
