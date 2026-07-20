#!/usr/bin/env python3
"""Mirror a built ReachyMiniOS release to a public Hugging Face Storage Bucket.

The desktop flasher (reachy_mini_flasher) downloads the OS image from this
bucket because the HF xet CDN is much faster and more reliable than GitHub
release downloads (the main pain point during flashing).

A Storage Bucket (not a dataset) is used on purpose: we only ever need the
*latest* image, not a versioned git history, so the bucket is written
overwrite-in-place at fixed paths. Public bucket files are readable anonymously
over HTTPS at:

    https://huggingface.co/buckets/<namespace>/<name>/resolve/<path>

The flasher locates the current assets through a small ``latest.json`` manifest
published at the bucket root:

    {
      "tag": "v0.2.7",
      "image": "reachyminios.zip",
      "bmap":  "reachyminios.bmap",
      "sha256": "<hex digest of the image file>"
    }

The ``sha256`` lets the flasher verify the downloaded image before writing it to
the eMMC, so a corrupted upload is caught early instead of at flash time.

Environment:
    HF_TOKEN          Write token for the bucket namespace (repository secret).
    HF_BUCKET_REPO    Target bucket, e.g. ``pollen-robotics/reachy-mini-os``.
    TAG               Release tag, e.g. ``v0.2.7``.
    DEPLOY_DIR        Optional; directory with the built assets (default ``deploy``).
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path

from huggingface_hub import batch_bucket_files, create_bucket, login

# Image extensions the flasher understands, in preference order.
IMAGE_EXTS = (".img.gz", ".zip", ".img")

# Fixed remote names (overwrite-in-place; the bucket keeps no history).
IMAGE_STEM = "reachyminios"
BMAP_NAME = "reachyminios.bmap"


def fail(message: str) -> "None":
    sys.exit(f"mirror_to_hf: {message}")


def pick(files: list[Path], suffixes: tuple[str, ...]) -> Path | None:
    for path in files:
        if path.name.lower().endswith(suffixes):
            return path
    return None


def image_ext(path: Path) -> str:
    name = path.name.lower()
    for ext in IMAGE_EXTS:
        if name.endswith(ext):
            return ext
    return path.suffix


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    repo_id = os.environ.get("HF_BUCKET_REPO")
    tag = os.environ.get("TAG")
    token = os.environ.get("HF_TOKEN")
    deploy_dir = Path(os.environ.get("DEPLOY_DIR", "deploy"))

    if not repo_id:
        fail("HF_BUCKET_REPO is not set")
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

    # Authenticate every subsequent bucket call from HF_TOKEN.
    login(token=token, add_to_git_credential=False)

    # Public bucket; created once, reused (overwritten) on every release.
    create_bucket(repo_id, private=False, exist_ok=True)

    image_remote = f"{IMAGE_STEM}{image_ext(image)}"
    print(f"Hashing {image} ...", flush=True)
    manifest: dict[str, str] = {
        "tag": tag,
        "image": image_remote,
        "sha256": sha256_file(image),
    }

    # Entries are (local path str | raw bytes, remote path).
    add: list[tuple[object, str]] = [(str(image), image_remote)]
    print(f"Uploading {image} -> {image_remote}", flush=True)
    if bmap:
        add.append((str(bmap), BMAP_NAME))
        manifest["bmap"] = BMAP_NAME
        print(f"Uploading {bmap} -> {BMAP_NAME}", flush=True)

    # latest.json is uploaded from raw bytes in the same batch.
    manifest_bytes = (json.dumps(manifest, indent=2) + "\n").encode("utf-8")
    add.append((manifest_bytes, "latest.json"))

    batch_bucket_files(repo_id, add=add)

    print(f"Mirror complete: {manifest}", flush=True)


if __name__ == "__main__":
    main()
