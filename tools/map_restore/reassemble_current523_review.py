#!/usr/bin/env python3
"""Verify five private Drive parts and reconstruct the fixed current523 ZIP."""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import tempfile

NAME = "TWILIGHT_Aden523_MapReview_resources_20261104.zip"
ARCHIVE_SHA256 = "f926e1513c552b60ed5deb6c9b1fddf18a6e59ab4e916575b9dc88206b05f952"
ARCHIVE_BYTES = 399316785
PARTS = (
    (83886080, "541cf235cccd17c53ae7d39a581da8edeae3d89f47ef41e5c1bb27f8e926a818"),
    (83886080, "f54d59becee39053e7f163f49b244db908728bbf192ed1cc65dc694262fdfba1"),
    (83886080, "2b4669325e0a0132651d8c8049a5336551291e6ef7cbdf629bf32658b3ade1a7"),
    (83886080, "1bc3c828e9da6c36889a59eb9157fa417bce9be40066f513f12b90dc1a010447"),
    (63772465, "381f33ca46a7cd7a66bbe8180f49879596455fb50c2f7a69b284101670566ff4"),
)


def reassemble(directory: Path, output: Path) -> Path:
    """Publish only a fully verified ZIP; preserve any existing destination."""
    if output.exists() or output.is_symlink():
        raise FileExistsError(f"Output already exists: {output}")
    selected = []
    for index, (size, digest) in enumerate(PARTS, 1):
        name = f"{NAME}.part{index:02d}"
        candidates = [p for p in (directory / name, directory / (name + ".bin")) if p.exists()]
        if len(candidates) != 1:
            raise ValueError(f"Keep exactly one file for part {index}: {name}")
        part = candidates[0]
        if not part.is_file() or part.stat().st_size != size:
            raise ValueError(f"Wrong part size: {part.name}")
        selected.append((part, size, digest))
    combined = hashlib.sha256()
    total = 0
    staged: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(dir=output.parent, prefix=output.name + ".pending-", delete=False) as stream:
            staged = Path(stream.name)
            for part, expected_size, expected_sha in selected:
                digest = hashlib.sha256()
                size = 0
                with part.open("rb") as source:
                    while block := source.read(1024 * 1024):
                        digest.update(block)
                        combined.update(block)
                        stream.write(block)
                        size += len(block)
                if size != expected_size or digest.hexdigest() != expected_sha:
                    raise ValueError(f"Part SHA256 mismatch: {part.name}")
                total += size
            if total != ARCHIVE_BYTES or combined.hexdigest() != ARCHIVE_SHA256:
                raise ValueError("Combined archive SHA256 mismatch")
            stream.flush()
            os.fsync(stream.fileno())
        # Same-directory hard link publishes without overwriting a concurrent file.
        os.link(staged, output)
        return output
    finally:
        if staged is not None:
            staged.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, nargs="?", default=Path(__file__).resolve().parent)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        output = reassemble(args.directory, args.output or args.directory / NAME)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"Not assembled: {exc}\n")
    print(f"Verified: {output}\nSHA256 {ARCHIVE_SHA256}")
    print("Open TWILIGHT Settings → 아덴 원문 검토 → 원본 ZIP 설치 and select this ZIP.")


if __name__ == "__main__":
    main()
