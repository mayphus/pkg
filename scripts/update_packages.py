#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PACKAGES_FILE = ROOT / "packages.janet"
CONFIG_FILE = ROOT / "scripts" / "update-packages.json"


def github_json(url: str) -> dict:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "pkg-updater",
    }
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def load_config(selected: set[str] | None) -> list[dict]:
    items = json.loads(CONFIG_FILE.read_text())
    if not selected:
        return items
    return [item for item in items if item["name"] in selected]


def github_releases(repo: str) -> list[dict]:
    releases = []
    page = 1
    while True:
        batch = github_json(
            f"https://api.github.com/repos/{repo}/releases?per_page=100&page={page}"
        )
        if not batch:
            break
        releases.extend(batch)
        if len(batch) < 100:
            break
        page += 1
    return releases


def latest_release(rule: dict) -> tuple[str, str, str]:
    releases = github_releases(rule["repo"])
    prefix = rule.get("tag_prefix", "")
    allow_prerelease = rule.get("allow_prerelease", False)
    data = next(
        (
            release
            for release in releases
            if release["tag_name"].startswith(prefix)
            and not release.get("draft", False)
            and (allow_prerelease or not release.get("prerelease", False))
        ),
        None,
    )
    if not data:
        raise RuntimeError(f"{rule['name']}: no release found matching prefix {prefix!r}")
    tag = data["tag_name"]
    version = tag[len(prefix):] if prefix else tag
    asset_name = rule["asset_template"].format(version=version)
    asset = next((item for item in data["assets"] if item["name"] == asset_name), None)
    if not asset:
      raise RuntimeError(f"{rule['name']}: asset not found: {asset_name}")
    digest = asset.get("digest", "")
    if not digest.startswith("sha256:"):
        raise RuntimeError(f"{rule['name']}: missing sha256 digest for asset {asset_name}")
    return version, asset["browser_download_url"], digest.removeprefix("sha256:")


def package_block(pattern_name: str, content: str) -> tuple[tuple[int, int], str]:
    pattern = re.compile(
        rf'(?ms)(^\s*"{re.escape(pattern_name)}"\s*\n\s*@\{{.*?)(?=^\s*"[^\n]+"\s*\n\s*@\{{|^\)\s*$)'
    )
    match = pattern.search(content)
    if not match:
        raise RuntimeError(f"package block not found: {pattern_name}")
    return match.span(1), match.group(1)


def replace_field(block: str, key: str, value: str) -> str:
    pattern = re.compile(rf'({re.escape(key)}\s+)"[^"]+"')
    replaced, count = pattern.subn(rf'\1"{value}"', block, count=1)
    if count != 1:
        raise RuntimeError(f"field not found or repeated unexpectedly: {key}")
    return replaced


def update_package_block(name: str, version: str, url: str, sha256: str, content: str) -> tuple[str, bool]:
    span, block = package_block(name, content)
    updated = replace_field(block, ":version", version)
    updated = replace_field(updated, ":url", url)
    updated = replace_field(updated, ":sha256", sha256)
    changed = updated != block
    return content[: span[0]] + updated + content[span[1] :], changed


def main() -> int:
    parser = argparse.ArgumentParser(description="Update selected package versions from GitHub releases.")
    parser.add_argument("--package", action="append", dest="packages", help="Package name to update")
    parser.add_argument("--dry-run", action="store_true", help="Only print planned changes")
    args = parser.parse_args()

    selected = set(args.packages or [])
    rules = load_config(selected)
    if selected and len(rules) != len(selected):
        configured = {rule["name"] for rule in rules}
        missing = ", ".join(sorted(selected - configured))
        raise SystemExit(f"Unknown updater package selection: {missing}")

    content = PACKAGES_FILE.read_text()
    changed_any = False

    for rule in rules:
        version, url, sha256 = latest_release(rule)
        new_content, changed = update_package_block(rule["name"], version, url, sha256, content)
        if changed:
            print(f"{rule['name']}: update to {version}")
            content = new_content
            changed_any = True
        else:
            print(f"{rule['name']}: up to date ({version})")

    if changed_any and not args.dry_run:
        PACKAGES_FILE.write_text(content)

    return 0


if __name__ == "__main__":
    sys.exit(main())
