#!/usr/bin/env python3
"""Fast-forward upstream source and mirror verified, unmodified Windows releases."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.request
import zipfile

UPSTREAM = "zaibuyidao/ReaWebAPI"
FORK = "Psysia/ReaWebAPI"
DLL = "reaper_reawebapi-x64.dll"


def run(*args: str, cwd: Path | None = None) -> str:
    result = subprocess.run(args, cwd=cwd, text=True, encoding="utf-8", capture_output=True)
    if result.returncode:
        raise RuntimeError(f"{args[0]} {args[1]} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def api(endpoint: str, optional: bool = False):
    result = subprocess.run(["gh", "api", endpoint], text=True, encoding="utf-8", capture_output=True)
    if result.returncode:
        if optional and "HTTP 404" in result.stderr:
            return None
        raise RuntimeError(f"GitHub request failed for {endpoint}: {result.stderr.strip()}")
    return json.loads(result.stdout)


def valid_tag(tag: str) -> str:
    if not re.fullmatch(r"v\d+(?:\.\d+){2,3}", tag):
        raise ValueError(f"Unsupported release tag: {tag!r}")
    return tag


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def checked_asset(release: dict, name: str, repository: str) -> dict:
    matches = [asset for asset in release.get("assets", []) if asset["name"] == name]
    if len(matches) != 1:
        raise ValueError(f"Release must contain exactly one {name}")
    asset = matches[0]
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", asset.get("digest") or ""):
        raise ValueError(f"Missing SHA-256 for {name}")
    prefix = f"https://github.com/{repository}/releases/download/{valid_tag(release['tag_name'])}/"
    if asset.get("browser_download_url") != prefix + name:
        raise ValueError(f"Unexpected release asset URL: {name}")
    return asset


def download(url: str, destination: Path, expected: str | None = None) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "PsyReaSFX-ReaWebAPI-Mirror"})
    with urllib.request.urlopen(request, timeout=120) as response:
        data = response.read()
    actual = digest(data)
    if expected and actual != expected:
        raise ValueError(f"SHA-256 mismatch for {destination.name}")
    destination.write_bytes(data)
    return actual


def inspect_bundle(path: Path, expected_dll: str) -> bytes:
    with zipfile.ZipFile(path) as archive:
        for required in ("COPYING", "COPYING.LESSER", "LICENSE.md", "THIRD_PARTY.md"):
            if f"ReaWebAPI/{required}" not in archive.namelist():
                raise ValueError(f"Missing license material: {required}")
        binary = archive.read("UserPlugins/" + DLL)
    if binary[:2] != b"MZ" or digest(binary) != expected_dll:
        raise ValueError("The bundled DLL differs from the upstream release DLL")
    return binary


def source_contracts(path: Path, commit: str) -> dict:
    with zipfile.ZipFile(path) as archive:
        prefix = f"ReaWebAPI-{commit}/"
        core = archive.read(prefix + "src/core/core.cpp").decode("utf-8")
        header = archive.read(prefix + "src/core/core.hpp").decode("utf-8")
        runtime = archive.read(prefix + "src/runtime/runtime.cpp").decode("utf-8")
    def number(pattern: str, text: str) -> int:
        found = re.search(pattern, text, re.S)
        if not found:
            raise ValueError("Upstream capability declarations changed; review before adopting this runtime")
        return int(found.group(1))
    limit = re.search(r"host_message_limit\s*=\s*([\d\s*]+);", header)
    if not limit or not re.fullmatch(r"\d+(?:\s*\*\s*\d+)*", limit.group(1).strip()):
        raise ValueError("Unknown host message capacity expression")
    capacity = 1
    for factor in limit.group(1).split("*"):
        capacity *= int(factor)
    return {
        "protocol": number(r'\{"protocol",\s*(\d+)\}', core),
        "runtime": number(r'\{"runtime",\s*\{\{"contract",\s*(\d+)\}', core),
        "web": number(r'Json Runtime::web_runtime\([^)]*\)[^{]*\{\s*return\s*\{\{"contract",\s*(\d+)\}', runtime),
        "max_message_bytes": capacity,
    }


def sync_source(worktree: Path) -> None:
    origin = run("git", "remote", "get-url", "origin", cwd=worktree)
    if origin.removesuffix(".git").removesuffix("/") not in (f"https://github.com/{FORK}", f"git@github.com:{FORK}"):
        raise ValueError("Refusing to write an unexpected Git origin")
    if run("git", "branch", "--show-current", cwd=worktree) != "psyreasfx":
        raise ValueError("Run the mirror from the psyreasfx automation branch")
    if run("git", "status", "--porcelain", "--untracked-files=no", cwd=worktree):
        raise ValueError("Commit tracked work before syncing the fork")
    run("git", "fetch", "--no-tags", "origin", "main:refs/remotes/origin/main", cwd=worktree)
    run("git", "fetch", "--no-tags", f"https://github.com/{UPSTREAM}.git", "main:refs/remotes/upstream/main", cwd=worktree)
    run("git", "merge-base", "--is-ancestor", "refs/remotes/origin/main", "refs/remotes/upstream/main", cwd=worktree)
    run("git", "push", "origin", "refs/remotes/upstream/main:refs/heads/main", cwd=worktree)
    run("git", "merge", "--no-edit", "refs/remotes/upstream/main", cwd=worktree)
    run("git", "push", "origin", "HEAD:refs/heads/psyreasfx", cwd=worktree)


def mirror_release(worktree: Path, tag: str) -> dict:
    latest = api(f"repos/{UPSTREAM}/releases/latest")
    release = latest if tag == "latest" else api(f"repos/{UPSTREAM}/releases/tags/{valid_tag(tag)}")
    tag = valid_tag(release["tag_name"])
    if release["draft"]:
        raise ValueError("Upstream release is still a draft")
    commit = api(f"repos/{UPSTREAM}/commits/{tag}")["sha"]
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Expected an immutable upstream commit")
    bundle_name = f"ReaWebAPI-windows-x64-{tag}.zip"
    bundle_asset = checked_asset(release, bundle_name, UPSTREAM)
    dll_asset = checked_asset(release, DLL, UPSTREAM)
    run("git", "fetch", "--no-tags", f"https://github.com/{UPSTREAM}.git", f"refs/tags/{tag}:refs/tags/{tag}", cwd=worktree)
    if run("git", "rev-parse", f"{tag}^{{commit}}", cwd=worktree) != commit:
        raise ValueError("Upstream tag and release commit disagree")
    run("git", "push", "origin", f"refs/tags/{tag}", cwd=worktree)
    existing = api(f"repos/{FORK}/releases/tags/{tag}", optional=True)
    indexed = {asset["name"]: asset for asset in (existing or {}).get("assets", [])}
    if existing and not existing["draft"]:
        for expected in (bundle_asset, dll_asset):
            if indexed.get(expected["name"], {}).get("digest") != expected["digest"]:
                raise ValueError("A published mirror differs from upstream; refusing to replace it")
        if not {"ReaWebAPI-source.zip", "mirror-manifest.json"}.issubset(indexed):
            raise ValueError("Published mirror is incomplete")
        print(f"{tag} already mirrored with matching upstream hashes")
        return {"tag": tag, "commit": commit, "changed": False}
    with tempfile.TemporaryDirectory(prefix="reawebapi-mirror-") as temporary:
        folder = Path(temporary)
        bundle = folder / bundle_name
        download(bundle_asset["browser_download_url"], bundle, bundle_asset["digest"][7:])
        (folder / DLL).write_bytes(inspect_bundle(bundle, dll_asset["digest"][7:]))
        source = folder / "ReaWebAPI-source.zip"
        source_hash = download(f"https://codeload.github.com/{FORK}/zip/{commit}", source)
        manifest = {
            "schema": "PsyReaSFX-ReaWebAPI-Mirror-v1", "upstream": UPSTREAM,
            "repository": FORK, "tag": tag, "commit": commit,
            "upstream_release_id": release["id"], "modified": False,
            "contracts": source_contracts(source, commit),
            "files": {bundle_name: bundle_asset["digest"][7:], DLL: dll_asset["digest"][7:], source.name: source_hash},
        }
        manifest_path = folder / "mirror-manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        notes = folder / "release-notes.md"
        notes.write_text(f"Unmodified Windows x64 mirror of [{UPSTREAM} {tag}]({release['html_url']}).\n\n"
                         f"Source commit: `{commit}`. Windows bundle and DLL SHA-256 values match upstream. "
                         "Licenses are included in the bundle; the matching source archive is attached. "
                         "`mirror-manifest.json` records provenance, hashes and source-declared contracts.\n\n"
                         "Mirroring does not certify native PsyReaSFX compatibility. App-level tests and REAPER acceptance are separate.\n", encoding="utf-8")
        if not existing:
            run("gh", "release", "create", tag, "--repo", FORK, "--verify-tag", "--draft", "--latest=false",
                "--title", f"ReaWebAPI {tag} — upstream Windows mirror", "--notes-file", str(notes))
        for file in (bundle, folder / DLL, source, manifest_path):
            uploaded = indexed.get(file.name)
            if uploaded:
                if uploaded.get("digest") != "sha256:" + digest(file.read_bytes()):
                    raise ValueError(f"Existing draft asset changed: {file.name}")
            else:
                run("gh", "release", "upload", tag, str(file), "--repo", FORK)
        run("gh", "release", "edit", tag, "--repo", FORK, "--draft=false",
            f"--prerelease={str(release['prerelease']).lower()}",
            f"--latest={str(release['id'] == latest['id']).lower()}")
        print(f"Mirrored {tag} from {commit}; verified upstream DLL and bundle")
        return {"tag": tag, "commit": commit, "changed": True}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--worktree", type=Path, default=Path.cwd())
    parser.add_argument("--tag", default="latest")
    parser.add_argument("--skip-source-sync", action="store_true")
    args = parser.parse_args()
    if os.environ.get("GITHUB_REPOSITORY", FORK) != FORK:
        raise ValueError("This workflow may only publish to the Psysia fork")
    if not args.skip_source_sync:
        sync_source(args.worktree.resolve())
    result = mirror_release(args.worktree.resolve(), args.tag)
    print(json.dumps(result))
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
            summary.write(f"Mirrored [{result['tag']}](https://github.com/{FORK}/releases/tag/{result['tag']}) at `{result['commit']}`.\n")


if __name__ == "__main__":
    main()
