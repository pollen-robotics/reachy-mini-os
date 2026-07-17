#!/usr/bin/env python3
"""Mirror a built ReachyMiniOS release to a public Hugging Face dataset.

The desktop flasher (reachy_mini_flasher) downloads the OS image from this
dataset because the HF xet/LFS CDN is much faster than GitHub releases. It
locates the current assets through a small ``latest.json`` manifest published at
the dataset root:

    {
      "tag": "v0.2.7",
      "image": "releases/v0.2.7/image_2026-06-17-reachyminios-v0.2.7.zip",
      "bmap":  "releases/v0.2.7/2026-06-17-reachyminios-v0.2.7.bmap"
    }

This script uploads the image (and its optional ``.bmap``) under
``releases/<tag>/`` and then rewrites ``latest.json`` to point at them.

Environment:
    HF_TOKEN          Write token for the dataset (repository secret).
    HF_DATASET_REPO   Target dataset, e.g. ``pollen-robotics/reachy-mini-os``.
    TAG               Release tag, e.g. ``v0.2.7``.
    DEPLOY_DIR        Optional; directory with the built assets (default ``deploy``).
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from huggingface_hub import HfApi

# Image extensions the flasher understands, in preference order.
IMAGE_EXTS = (".img.gz", ".zip", ".img")


def fail(message: str) -> "None":
    sys.exit(f"mirror_to_hf: {message}")


def pick(files: list[Path], suffixes: tuple[str, ...]) -> Path | None:
    for path in files:
        if path.name.lower().endswith(suffixes):
            return path
    return None


def main() -> None:
    repo_id = os.environ.get("HF_DATASET_REPO")
    tag = os.environ.get("TAG")
    token = os.environ.get("HF_TOKEN")
    deploy_dir = Path(os.environ.get("DEPLOY_DIR", "deploy"))

    if not repo_id:
        fail("HF_DATASET_REPO is not set")
    if not tag:
        fail("TAG is not set")
    if not token:
        fail("HF_TOKEN is not set - add it as a repository secret with write access")
    if not deploy_dir.is_dir():
        fail(f"deploy directory not found: {deploy_dir}")

    files = sorted(p for p in deploy_dir.iterdir() if p.is_file())
    image = pick(files, IMAGE_EXTS)
    if image is None:
        fail(f"no image asset ({'/'.join(IMAGE_EXTS)}) found in {deploy_dir}/")
    bmap = pick(files, (".bmap",))

    api = HfApi(token=token)
    api.create_repo(repo_id, repo_type="dataset", exist_ok=True, private=False)

    prefix = f"releases/{tag}"

    def upload(path: Path) -> str:
        dst = f"{prefix}/{path.name}"
        print(f"Uploading {path} -> {dst}", flush=True)
        api.upload_file(
            path_or_fileobj=str(path),
            path_in_repo=dst,
            repo_id=repo_id,
            repo_type="dataset",
            commit_message=f"Mirror {path.name} ({tag})",
        )
        return dst

    image_rel = upload(image)
    bmap_rel = upload(bmap) if bmap else None

    manifest: dict[str, str] = {"tag": tag, "image": image_rel}
    if bmap_rel:
        manifest["bmap"] = bmap_rel

    manifest_path = Path("latest.json")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    api.upload_file(
        path_or_fileobj=str(manifest_path),
        path_in_repo="latest.json",
        repo_id=repo_id,
        repo_type="dataset",
        commit_message=f"Point latest.json at {tag}",
    )

    print(f"Mirror complete: {manifest}", flush=True)


if __name__ == "__main__":
    main()
