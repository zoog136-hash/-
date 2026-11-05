#!/usr/bin/env python3
"""Restore retired authoring inputs from owner-held backups to a new private cache.

This does not download, change Git, install a runtime pack, or modify saves.
Use a local monster snapshot ZIP and/or a bare repo restored from the private
scoped bundle. The manifest preserves the original paths and exact blob hashes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile
import zipfile


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        while block := stream.read(1024 * 1024):
            h.update(block)
    return h.hexdigest()


def rows_for(manifest: dict, paths: list[str] | None = None) -> list[dict]:
    if manifest.get("schema") != 1 or manifest.get("kind") != "twilight-retired-authored-assets":
        raise ValueError("Unsupported retired-resource manifest")
    rows, seen = [], set()
    for row in manifest.get("files", []):
        name = row.get("path", "")
        path = PurePosixPath(name)
        if (not name.startswith(("assets/actors/eight_direction/", "docs/")) or
                path.is_absolute() or ".." in path.parts or "\\" in name or "\0" in name or
                path.as_posix() != name or name in seen):
            raise ValueError("Unsafe or duplicate retired path")
        if (row.get("mode") not in ("100644", "100755") or
                not re.fullmatch(r"[0-9a-f]{40}", row.get("oid", "")) or
                not re.fullmatch(r"[0-9a-f]{64}", row.get("sha256", "")) or
                type(row.get("bytes")) is not int or not 0 <= row["bytes"] <= 128 * 1024 * 1024 or
                row.get("backup") not in ("monster_snapshot", "scoped_bundle")):
            raise ValueError("Invalid retired blob identity")
        seen.add(name)
        rows.append(row)
    if paths:
        if set(paths) - seen:
            raise ValueError("Requested path is not in the retirement manifest")
        rows = [row for row in rows if row["path"] in set(paths)]
    if not rows:
        raise ValueError("No retired inputs selected")
    return rows


def _copy_verified(source, target: Path, row: dict) -> None:
    sha1 = hashlib.sha1(("blob " + str(row["bytes"]) + "\0").encode())
    sha256 = hashlib.sha256()
    size = 0
    with target.open("xb") as output:
        while block := source.read(min(1024 * 1024, row["bytes"] - size + 1)):
            size += len(block)
            if size > row["bytes"]:
                raise ValueError("Restored blob exceeds its declared size")
            sha1.update(block)
            sha256.update(block)
            output.write(block)
        output.flush()
        os.fsync(output.fileno())
    if (size != row["bytes"] or sha1.hexdigest() != row["oid"] or
            sha256.hexdigest() != row["sha256"] or digest(target) != row["sha256"]):
        raise ValueError("Restored blob size/Git identity/SHA256 mismatch")
    target.chmod(int(row["mode"][-3:], 8))


def restore(manifest: dict, destination: Path, *, monster_zip: Path | None = None,
            reference_git: Path | None = None, paths: list[str] | None = None) -> dict:
    rows = rows_for(manifest, paths)
    destination = destination.absolute()
    if destination.exists() or destination.is_symlink():
        raise ValueError("Destination must be a new private cache directory")
    needed = {row["backup"] for row in rows}
    if "monster_snapshot" in needed:
        if monster_zip is None:
            raise ValueError("The verified private monster snapshot ZIP is required")
        expected = manifest["backups"]["monster_snapshot"]
        if monster_zip.stat().st_size != expected["bytes"] or digest(monster_zip) != expected["sha256"]:
            raise ValueError("Monster snapshot archive size/SHA256 mismatch")
    if "scoped_bundle" in needed and reference_git is None:
        raise ValueError("A local repo restored from the private scoped bundle is required")
    destination.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".twilight-retired-", dir=destination.parent))
    archive = zipfile.ZipFile(monster_zip) if "monster_snapshot" in needed else None
    try:
        for row in rows:
            target = stage.joinpath(*PurePosixPath(row["path"]).parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            if row["backup"] == "monster_snapshot":
                name = "objects/" + row["oid"]
                if archive.getinfo(name).file_size != row["bytes"]:
                    raise ValueError("Snapshot member size mismatch")
                with archive.open(name) as source:
                    _copy_verified(source, target, row)
            else:
                env = dict(os.environ, GIT_NO_LAZY_FETCH="1", GIT_NO_REPLACE_OBJECTS="1")
                with subprocess.Popen(["git", "-C", str(reference_git), "cat-file", "blob", row["oid"]],
                                      stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env) as process:
                    try:
                        _copy_verified(process.stdout, target, row)
                    except BaseException:
                        process.terminate()
                        raise
                    if process.wait() != 0:
                        raise ValueError("Blob missing from the local restored backup repo")
        if destination.exists() or destination.is_symlink():
            raise ValueError("Destination appeared while restoring; existing data preserved")
        stage.rename(destination)
    finally:
        if archive:
            archive.close()
        if stage.exists():
            shutil.rmtree(stage)
    return {"restored_paths": len(rows), "bytes": sum(row["bytes"] for row in rows),
            "destination": str(destination), "runtime_pack_installed": False,
            "git_or_saves_changed": False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=Path(__file__).resolve().parents[1] /
                        "data/retired_authored_assets.json")
    parser.add_argument("--dest", type=Path, required=True)
    parser.add_argument("--monster-zip", type=Path)
    parser.add_argument("--reference-git", type=Path)
    parser.add_argument("--path", action="append")
    args = parser.parse_args()
    result = restore(json.loads(args.manifest.read_text()), args.dest,
                     monster_zip=args.monster_zip, reference_git=args.reference_git, paths=args.path)
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
