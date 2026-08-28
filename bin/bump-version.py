#!/usr/bin/env python3
"""Bump a github_tools entry: download the release asset, update version + sha256.

Usage:
  uv run python bin/bump-version.py <tool> <new-version>

Reads vars/versions.yml, finds the tool in github_tools, renders its url
template with the new version, downloads the asset, computes sha256, and
rewrites the version/sha256 lines in-place (comments and ordering preserved).

Example:
  uv run python bin/bump-version.py zoxide 0.11.0
"""
from __future__ import annotations

import hashlib
import re
import sys
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
VERSIONS_FILE = REPO_ROOT / "vars" / "versions.yml"


def load_tools() -> list[dict]:
    import yaml  # PyYAML ships with the ansible dependency in the uv env

    data = yaml.safe_load(VERSIONS_FILE.read_text())
    return data.get("github_tools", [])


def render_url(url_template: str, version: str) -> str:
    return url_template.replace("{version}", version)


def download_and_hash(url: str) -> str:
    with urllib.request.urlopen(url) as response:  # noqa: S310 (trusted release URLs)
        data = response.read()
    return hashlib.sha256(data).hexdigest()


def update_file(tool_name: str, new_version: str, new_sha256: str) -> None:
    text = VERSIONS_FILE.read_text()
    # Match this tool's block: from "- name: <tool>" up to the next "- name:" or EOF.
    pattern = re.compile(
        r"(- name:\s*" + re.escape(tool_name) + r"\b.*?)(?=\n- name:|\Z)",
        re.DOTALL,
    )
    match = pattern.search(text)
    if not match:
        sys.exit(f"tool '{tool_name}' not found in {VERSIONS_FILE}")
    block = match.group(1)
    new_block = re.sub(r'version:\s*"[^"]*"', f'version: "{new_version}"', block, count=1)
    new_block = re.sub(r'sha256:\s*"[^"]*"', f'sha256: "{new_sha256}"', new_block, count=1)
    if new_block == block:
        sys.exit(f"no changes made (check that '{tool_name}' has version/sha256 lines)")
    VERSIONS_FILE.write_text(text.replace(block, new_block, 1))


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <tool> <new-version>")
    tool_name, new_version = sys.argv[1], sys.argv[2]

    tools = load_tools()
    tool = next((t for t in tools if t["name"] == tool_name), None)
    if not tool:
        available = ", ".join(t["name"] for t in tools)
        sys.exit(f"tool '{tool_name}' not in github_tools (available: {available})")

    url = render_url(tool["url"], new_version)
    print(f"downloading {url}")
    sha = download_and_hash(url)
    print(f"sha256: {sha}")
    update_file(tool_name, new_version, sha)
    print(f"updated {VERSIONS_FILE.relative_to(REPO_ROOT)}: {tool_name} -> {new_version}")


if __name__ == "__main__":
    main()
