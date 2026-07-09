#!/usr/bin/env python3
"""Mirror a ReachyMiniOS GitHub release to the Hugging Face dataset.

Downloads the release assets (image + .bmap + .info) and uploads them to
`HF_DATASET` under `<tag>/<filename>`, then writes a top-level `latest.json`
manifest the desktop flasher reads to know what to download.

Idempotent: assets already present on HF for that tag are skipped.

Env:
  HF_TOKEN      Hugging Face write token (required)
  HF_DATASET    e.g. "pollen-robotics/reachy-mini-os" (required)
  GH_REPO       "owner/repo" of the OS releases (required)
  RELEASE_TAG   tag to mirror; empty -> latest release
  GITHUB_TOKEN  optional, raises GitHub API rate limits
"""

from __future__ import annotations

import json
import os
import pathlib
import sys
import tempfile

import requests
from huggingface_hub import HfApi

GH_REPO = os.environ["GH_REPO"]
HF_DATASET = os.environ["HF_DATASET"]
HF_TOKEN = os.environ["HF_TOKEN"]
RELEASE_TAG = os.environ.get("RELEASE_TAG", "").strip()
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "").strip()

# Image asset preference order (first match wins).
IMAGE_SUFFIXES = (".img.gz", ".zip", ".img")

api = HfApi(token=HF_TOKEN)


def gh_get(url: str) -> dict:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "reachy-mini-os-mirror",
    }
    if GITHUB_TOKEN:
        headers["Authorization"] = f"Bearer {GITHUB_TOKEN}"
    resp = requests.get(url, headers=headers, timeout=60)
    resp.raise_for_status()
    return resp.json()


def pick(assets: list[dict], suffixes: tuple[str, ...]) -> dict | None:
    for suffix in suffixes:
        for asset in assets:
            if asset["name"].lower().endswith(suffix):
                return asset
    return None


def download(url: str, dest: pathlib.Path) -> None:
    print(f"  downloading {url}")
    with requests.get(url, stream=True, timeout=180) as resp:
        resp.raise_for_status()
        with open(dest, "wb") as fh:
            for chunk in resp.iter_content(chunk_size=8 * 1024 * 1024):
                fh.write(chunk)


def mirror_asset(asset: dict, tag: str, existing: set[str]) -> str:
    name = asset["name"]
    repo_path = f"{tag}/{name}"
    if repo_path in existing:
        print(f"  skip (already on HF): {repo_path}")
        return repo_path
    with tempfile.TemporaryDirectory() as tmp:
        local = pathlib.Path(tmp) / name
        download(asset["browser_download_url"], local)
        print(f"  uploading -> {repo_path}")
        api.upload_file(
            path_or_fileobj=str(local),
            path_in_repo=repo_path,
            repo_id=HF_DATASET,
            repo_type="dataset",
            commit_message=f"Mirror {name} ({tag})",
        )
    return repo_path


def main() -> int:
    if RELEASE_TAG:
        rel = gh_get(f"https://api.github.com/repos/{GH_REPO}/releases/tags/{RELEASE_TAG}")
    else:
        rel = gh_get(f"https://api.github.com/repos/{GH_REPO}/releases/latest")

    tag = rel["tag_name"]
    assets = rel.get("assets", [])
    print(f"Mirroring {GH_REPO}@{tag} -> {HF_DATASET} ({len(assets)} assets)")

    image_asset = pick(assets, IMAGE_SUFFIXES)
    if not image_asset:
        print("ERROR: no image asset (.img.gz/.zip/.img) in release", file=sys.stderr)
        return 1
    bmap_asset = pick(assets, (".bmap",))
    info_asset = pick(assets, (".info",))

    api.create_repo(HF_DATASET, repo_type="dataset", exist_ok=True)
    existing = set(api.list_repo_files(HF_DATASET, repo_type="dataset"))

    image_path = mirror_asset(image_asset, tag, existing)
    bmap_path = mirror_asset(bmap_asset, tag, existing) if bmap_asset else None
    if info_asset:
        mirror_asset(info_asset, tag, existing)

    manifest = {
        "tag": tag,
        "image": image_path,
        "bmap": bmap_path,
        "image_size": image_asset.get("size"),
    }
    with tempfile.TemporaryDirectory() as tmp:
        manifest_file = pathlib.Path(tmp) / "latest.json"
        manifest_file.write_text(json.dumps(manifest, indent=2) + "\n")
        api.upload_file(
            path_or_fileobj=str(manifest_file),
            path_in_repo="latest.json",
            repo_id=HF_DATASET,
            repo_type="dataset",
            commit_message=f"Update latest.json -> {tag}",
        )

    print("Done:", json.dumps(manifest))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
