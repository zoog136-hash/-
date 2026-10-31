#!/usr/bin/env python3
"""Add only the docs/ files the project references to a sparse CI checkout.

docs/ holds ~22 GB of review evidence. Checking it out (working tree plus its
pack) no longer fits a hosted runner's disk. Animation CI checks out
everything except docs/ (blob:none partial clone), then this script scans the
checked-out text files for ``res://docs/...`` and ``docs/...`` references and
adds exactly those tracked files (or every file under a referenced directory)
to the sparse checkout, so Godot resources and tests that read them still work.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

TEXT_SUFFIXES = {".tres", ".tscn", ".gd", ".gdshader", ".json", ".import", ".cfg", ".godot",
                 ".py", ".sh", ".yml", ".yaml", ".md", ".txt", ".csv"}
REFERENCE = re.compile(r"(?:res://)?(docs/[A-Za-z0-9_@+\-가-힣][A-Za-z0-9_./@+\-가-힣]*)")
# Directory references (mostly tool output folders) are expanded only when
# small; evidence trees such as docs/remake/evidence hold tens of thousands of
# images and would defeat the purpose. Exact file references always count.
MAX_DIRECTORY_FILES = 250


def git(*args: str, data: str | None = None) -> str:
    return subprocess.run(["git", *args], check=True, text=True, input=data,
                          stdout=subprocess.PIPE).stdout


def references(root: Path) -> set[str]:
    found: set[str] = set()
    for line in git("ls-files", "--cached", "--sparse", "-z").split("\0"):
        if not line or line.startswith("docs/"):
            continue
        path = root / line
        if path.suffix.lower() not in TEXT_SUFFIXES or not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for match in REFERENCE.finditer(text):
            found.add(match.group(1).rstrip("./,;:"))
    return found


def needed(refs: set[str], tracked: list[str]) -> tuple[list[str], list[str]]:
    tracked_set = set(tracked)
    result: set[str] = {ref for ref in refs if ref in tracked_set}
    skipped: list[str] = []
    for ref in sorted(refs - tracked_set):
        prefix = ref.rstrip("/") + "/"
        under = [path for path in tracked if path.startswith(prefix)]
        if len(under) > MAX_DIRECTORY_FILES:
            skipped.append(f"{ref} ({len(under)} files)")
        else:
            result.update(under)
    # Godot also needs a referenced image's tracked import settings.
    result.update(path + ".import" for path in list(result) if path + ".import" in tracked_set)
    return sorted(result), skipped


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    tracked = [p for p in git("ls-tree", "-r", "--name-only", "-z", "HEAD", "--", "docs").split("\0") if p]
    refs = references(root)
    files, skipped = needed(refs, tracked)
    print(f"CI_SPARSE_DOCS references={len(refs)} files={len(files)} tracked_docs={len(tracked)}")
    for entry in skipped:
        print(f"CI_SPARSE_DOCS skipped large directory reference: {entry}")
    if files and not args.dry_run:
        git("sparse-checkout", "add", "--stdin", data="".join("/" + f + "\n" for f in files))
    return 0


if __name__ == "__main__":
    sys.exit(main())
