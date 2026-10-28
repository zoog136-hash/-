#!/usr/bin/env python3
"""Bounded, read-only consumption of trusted-main Godot PNG import caches.

Godot still performs its normal --import and rechecks source hashes. This is
not a test-result cache, and it cannot turn a failed import into a PASS.
Only the trusted main workflow publishes its own derived PNG import artifacts.
"""
from __future__ import annotations
import argparse
import hashlib
import os
from pathlib import Path
import shutil

SHARDS = 4
MAX_SHARD_BYTES = 1_500_000_000


def eligible(path: Path) -> bool:
    return path.is_file() and not path.is_symlink() and ".png-" in path.name


def shard_of(filename: str) -> int:
    return hashlib.sha256(filename.encode("utf-8")).digest()[0] % SHARDS


def stage(root: Path) -> list[tuple[int, int]]:
    source = root / ".godot" / "imported"
    target = root / ".ci-godot-cache"
    if not source.is_dir():
        raise ValueError("Godot import cache does not exist; cannot publish")
    if target.is_symlink():
        raise ValueError("Refuse symlinked cache staging directory")
    if target.exists():
        shutil.rmtree(target)
    results = [[0, 0] for _ in range(SHARDS)]
    for item in source.iterdir():
        if not eligible(item):
            continue
        n = shard_of(item.name)
        size = item.stat().st_size
        results[n][0] += 1
        results[n][1] += size
        if results[n][1] > MAX_SHARD_BYTES:
            raise ValueError("PNG cache shard exceeds bounded size: " + str(n))
        destination = target / ("shard-" + str(n))
        destination.mkdir(parents=True, exist_ok=True)
        linked = destination / item.name
        try:
            os.link(item, linked)
        except OSError:
            shutil.copy2(item, linked)
    if any(n == 0 for n, _ in results):
        raise ValueError("Missing expected PNG imports; refuse incomplete cache")
    return [tuple(row) for row in results]


def restore(root: Path) -> list[tuple[int, int]]:
    imported = root / ".godot" / "imported"
    if imported.is_symlink():
        raise ValueError("Refuse symlinked Godot imported-resource directory")
    imported.mkdir(parents=True, exist_ok=True)
    results = [[0, 0] for _ in range(SHARDS)]
    for n in range(SHARDS):
        shard = root / ".ci-godot-cache" / ("shard-" + str(n))
        if not shard.is_dir() or shard.is_symlink():
            continue
        for item in shard.iterdir():
            if not eligible(item) or shard_of(item.name) != n:
                raise ValueError("Invalid PNG import cache entry: " + item.name)
            dest = imported / item.name
            if dest.exists():
                # Never overwrite resources installed by another trusted cache.
                continue
            try:
                os.link(item, dest)
            except OSError:
                shutil.copy2(item, dest)
            results[n][0] += 1
            results[n][1] += item.stat().st_size
    return [tuple(row) for row in results]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("stage", "restore"))
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    result = stage(root) if args.mode == "stage" else restore(root)
    print("TWILIGHT_PNG_IMPORT_CACHE", args.mode,
          "shards=", result, "total_bytes=", sum(item[1] for item in result), flush=True)
    if args.github_output is not None and args.mode == "stage":
        with args.github_output.open("a", encoding="utf-8") as stream:
            stream.write("ready=true\n")


if __name__ == "__main__":
    main()
