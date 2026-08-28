#!/usr/bin/env python3
"""Bump a pinned tool: download the release asset, update version + sha256.

Usage:
  uv run python bin/bump-version.py <tool> <new-version>

Supports two kinds of pinned tool in vars/versions.yml:
  - github_tools entries (delta, zoxide, eza, ..., gh) — has a `url` field with
    a {version} placeholder; the block is rewritten in place.
  - standalone tools (neovim, lazygit) — flat <name>_version / <name>_sha256
    keys with a hardcoded URL template below.

opencode is intentionally @latest (unpinned) and is NOT bump-able here.
Comments and ordering are preserved (targeted regex edits, not a full dump).

Examples:
  uv run python bin/bump-version.py zoxide 0.11.0
  uv run python bin/bump-version.py neovim 0.11.1
"""
from __future__ import annotations

import hashlib
import re
import sys
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
VERSIONS_FILE = REPO_ROOT / "vars" / "versions.yml"

# Standalone tools: flat keys in versions.yml + a known URL template (linux
# x86_64 asset). Kept here (not in versions.yml) because their install roles
# don't use the github_tools list schema.
STANDALONE_TOOLS: dict[str, dict[str, str]] = {
    "neovim": {
        "version_key": "neovim_version",
        "sha256_key": "neovim_sha256",
        "url": "https://github.com/neovim/neovim/releases/download/v{version}/nvim-linux-x86_64.tar.gz",
    },
    "lazygit": {
        "version_key": "lazygit_version",
        "sha256_key": "lazygit_sha256",
        "url": "https://github.com/jesseduffield/lazygit/releases/download/v{version}/lazygit_{version}_Linux_x86_64.tar.gz",
    },
}


def load_github_tools() -> list[dict]:
    import yaml  # PyYAML ships with the ansible dependency in the uv env

    data = yaml.safe_load(VERSIONS_FILE.read_text())
    return data.get("github_tools", [])


def render_url(url_template: str, version: str) -> str:
    return url_template.replace("{version}", version)


def download_and_hash(url: str) -> str:
    with urllib.request.urlopen(url) as response:  # noqa: S310 (trusted release URLs)
        data = response.read()
    return hashlib.sha256(data).hexdigest()


def update_github_block(tool_name: str, new_version: str, new_sha256: str) -> None:
    text = VERSIONS_FILE.read_text()
    pattern = re.compile(
        r"(- name:\s*" + re.escape(tool_name) + r"\b.*?)(?=\n- name:|\Z)",
        re.DOTALL,
    )
    match = pattern.search(text)
    if not match:
        raise ValueError(f"github_tools entry '{tool_name}' not found")
    block = match.group(1)
    new_block = re.sub(r'version:\s*"[^"]*"', f'version: "{new_version}"', block, count=1)
    new_block = re.sub(r'sha256:\s*"[^"]*"', f'sha256: "{new_sha256}"', new_block, count=1)
    if new_block == block:
        sys.exit(f"no changes made (check that '{tool_name}' has version/sha256 lines)")
    VERSIONS_FILE.write_text(text.replace(block, new_block, 1))


def update_standalone(tool_name: str, new_version: str, new_sha256: str) -> None:
    spec = STANDALONE_TOOLS[tool_name]
    text = VERSIONS_FILE.read_text()
    vkey, skey = spec["version_key"], spec["sha256_key"]
    new = re.sub(rf'{re.escape(vkey)}:\s*"[^"]*"', f'{vkey}: "{new_version}"', text)
    new = re.sub(rf'{re.escape(skey)}:\s*"[^"]*"', f'{skey}: "{new_sha256}"', new)
    if new == text:
        sys.exit(f"no changes made (check that {vkey}/{skey} exist in {VERSIONS_FILE})")
    VERSIONS_FILE.write_text(new)


def available_tools(github_tools: list[dict]) -> str:
    names = [t["name"] for t in github_tools]
    names.extend(STANDALONE_TOOLS)
    return ", ".join(names)


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <tool> <new-version>")
    tool_name, new_version = sys.argv[1], sys.argv[2]

    github_tools = load_github_tools()

    gh = next((t for t in github_tools if t["name"] == tool_name), None)
    if gh is not None:
        url = render_url(gh["url"], new_version)
        print(f"downloading {url}")
        sha = download_and_hash(url)
        print(f"sha256: {sha}")
        update_github_block(tool_name, new_version, sha)
        print(f"updated {VERSIONS_FILE.relative_to(REPO_ROOT)}: {tool_name} -> {new_version}")
        return

    if tool_name in STANDALONE_TOOLS:
        url = render_url(STANDALONE_TOOLS[tool_name]["url"], new_version)
        print(f"downloading {url}")
        sha = download_and_hash(url)
        print(f"sha256: {sha}")
        update_standalone(tool_name, new_version, sha)
        print(f"updated {VERSIONS_FILE.relative_to(REPO_ROOT)}: {tool_name} -> {new_version}")
        return

    sys.exit(f"tool '{tool_name}' not known (available: {available_tools(github_tools)})")


if __name__ == "__main__":
    main()
