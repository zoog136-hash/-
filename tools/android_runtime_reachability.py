#!/usr/bin/env python3
"""Find eight-direction actor folders the game can never load, for the Android export.

The export preset uses ``export_filter="all_resources"``, so every revision,
draft and review folder under ``assets/actors/eight_direction`` ships in the
APK whether or not the game references it. This tool walks the resources the
game can actually reach and lists the folders nothing reaches.

Reachability (deliberately over-approximate, so it errs toward shipping):
  * Seeds: every ``res://`` literal in every ``.gd``/``.tscn``/``.gdshader``
    outside docs/tools/tests, plus ``Main.tscn`` and ``project.godot``.
    ``.tres`` files are not seeds: a SpriteFrames resource is only live when
    something live points at it.
  * Every reached ``.tres``/``.tscn``/``.json``/``.gd``/``.cfg`` is read and its
    ``res://`` literals are followed in turn.
  * A literal that names a folder (ends in ``/`` or has no file extension)
    keeps that whole folder.

Validation ledgers such as ``data/pr122_*_staging.json`` mention old revisions
but no game code loads them, so they are not seeds. If code ever starts
loading one, its references become reachable and ``--check`` fails.

Usage:
  python3 tools/android_runtime_reachability.py --report   # list, change nothing
  python3 tools/android_runtime_reachability.py --write    # update export_presets.cfg
  python3 tools/android_runtime_reachability.py --check    # CI: fail on a reachable exclusion
"""
from __future__ import annotations

import argparse
import fnmatch
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

ACTOR_ROOT = "assets/actors/eight_direction"
# Pattern kept from the earlier audited draft001 exclusion; it is not generated.
DRAFT_EXPORT_PATTERN = ACTOR_ROOT + "/native_locomotion_staging/transform_*/draft001/*"
GENERATED_PREFIX = ACTOR_ROOT + "/"
RESOURCE_LITERAL = re.compile(r'res:(?://|\\/\\/)([^"\'\s\\\]\),;<>|]+)')
SEED_SUFFIXES = {".gd", ".tscn", ".gdshader"}
FOLLOW_SUFFIXES = {".tres", ".tscn", ".json", ".gd", ".cfg", ".gdshader"}
NON_RUNTIME_TOPS = {"docs", "tools", "tests", ".github", "build", ".godot"}
PRESET_LINE = re.compile(r'^exclude_filter="([^"]*)"$', re.MULTILINE)


def tracked_files(root: Path) -> list[str]:
    """All repository paths, including sparse-checkout entries absent on disk."""
    try:
        output = subprocess.run(["git", "-C", str(root), "ls-files", "-z"], check=True,
                                capture_output=True).stdout
        names = [name for name in output.decode("utf-8").split("\0") if name]
        if names:
            return names
    except (OSError, subprocess.CalledProcessError):
        pass
    return [path.relative_to(root).as_posix() for path in root.rglob("*")
            if path.is_file() and ".git" not in path.relative_to(root).parts]


# Folders at or above ACTOR_ROOT. A literal naming one of these could be the
# start of a path built at runtime, which this tool cannot follow, so it blocks
# every exclusion -- except inside a begins_with(...) guard, which only
# validates a path and never loads anything.
ANCESTOR_FOLDERS = {"assets/", "assets/actors/", GENERATED_PREFIX}
PREFIX_GUARD = re.compile(r'begins_with\(\s*"$')


def _literals(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    found = []
    for match in RESOURCE_LITERAL.finditer(text):
        literal = match.group(1).rstrip(".")
        folder = literal.rstrip("/") + "/"
        if folder in ANCESTOR_FOLDERS and PREFIX_GUARD.search(text[max(0, match.start() - 40):match.start()]):
            continue
        found.append(literal)
    return found


def _is_folder_literal(literal: str) -> bool:
    return literal.endswith("/") or PurePosixPath(literal).suffix == ""


def reachable(root: Path, files: list[str] | None = None) -> tuple[set[str], set[str]]:
    """Return (reached file paths, reached folder prefixes) relative to ``root``."""
    files = files if files is not None else tracked_files(root)
    stack: list[str] = []
    for name in files:
        top = name.split("/", 1)[0]
        if top in NON_RUNTIME_TOPS or PurePosixPath(name).suffix not in SEED_SUFFIXES:
            continue
        stack.extend(_literals(root / name))
    for name in ("Main.tscn", "project.godot"):
        stack.extend(_literals(root / name))
    seen: set[str] = set()
    folders: set[str] = set()
    while stack:
        literal = stack.pop().lstrip("/")
        if literal in seen:
            continue
        seen.add(literal)
        if _is_folder_literal(literal):
            folders.add(literal.rstrip("/") + "/")
            continue
        path = root / literal
        if PurePosixPath(literal).suffix in FOLLOW_SUFFIXES and path.is_file():
            stack.extend(_literals(path))
    return seen, folders


# assets/actors/eight_direction/<family>/<actor>: the shallowest excludable level.
MIN_EXCLUDED_DEPTH = 5


def blocking_reference(folder: str, reached: set[str], reached_folders: set[str]) -> str | None:
    """The reached path or folder literal that keeps ``folder`` in the APK, if any."""
    prefix = folder.rstrip("/") + "/"
    for item in reached:
        if item.startswith(prefix):
            return item
    for item in reached_folders:
        # A literal inside the folder, or naming the folder or any parent of it.
        if item.startswith(prefix) or prefix.startswith(item):
            return item
    return None


def unreachable_actor_folders(root: Path, files: list[str] | None = None) -> list[str]:
    """Topmost folders under ACTOR_ROOT that contain files but nothing reachable."""
    files = files if files is not None else tracked_files(root)
    reached, reached_folders = reachable(root, files)
    folders: set[str] = set()
    for name in files:
        if not name.startswith(GENERATED_PREFIX):
            continue
        parts = PurePosixPath(name).parts
        for depth in range(MIN_EXCLUDED_DEPTH, len(parts)):
            folders.add("/".join(parts[:depth]))
    # Shallowest first, so a dead actor is excluded as one folder.
    dead = sorted((folder for folder in folders
                   if blocking_reference(folder, reached, reached_folders) is None),
                  key=lambda folder: (folder.count("/"), folder))
    # draft001 review clips already have their own audited pattern.
    dead = [folder for folder in dead if not fnmatch.fnmatchcase(folder + "/x", DRAFT_EXPORT_PATTERN)]
    topmost: list[str] = []
    for folder in dead:
        if not any(folder.startswith(parent + "/") for parent in topmost):
            topmost.append(folder)
    return sorted(topmost)


def patterns_for(folders: list[str]) -> list[str]:
    return [folder + "/*" for folder in folders]


def preset_patterns(preset_text: str) -> list[str]:
    filters = PRESET_LINE.findall(preset_text)
    if len(filters) != 1:
        raise ValueError("Expected exactly one exclude_filter in export_presets.cfg")
    return [pattern for pattern in filters[0].split(",") if pattern]


def generated_patterns(patterns: list[str]) -> list[str]:
    return [pattern for pattern in patterns
            if pattern.startswith(GENERATED_PREFIX) and pattern != DRAFT_EXPORT_PATTERN]


def check_generated(root: Path, patterns: list[str], files: list[str] | None = None) -> dict:
    """Fail if a generated exclusion could hide something the game loads."""
    files = files if files is not None else tracked_files(root)
    reached, reached_folders = reachable(root, files)
    excluded_folders: list[str] = []
    for pattern in generated_patterns(patterns):
        if not pattern.endswith("/*") or "*" in pattern[:-2] or "?" in pattern or "[" in pattern:
            raise ValueError("Generated actor exclusion must be an exact folder: " + pattern)
        folder = pattern[:-2]
        if len(PurePosixPath(folder).parts) < MIN_EXCLUDED_DEPTH:
            raise ValueError("Actor family roots may not be excluded: " + pattern)
        if not any(name.startswith(folder + "/") for name in files):
            raise ValueError("Excluded actor folder does not exist: " + pattern)
        hit = blocking_reference(folder, reached, reached_folders)
        if hit:
            raise ValueError("Runtime-reachable resource excluded from Android export: "
                             + pattern + " (reached: res://" + hit + ")")
        excluded_folders.append(folder)
    return {"excluded_unreachable_folders": excluded_folders,
            "excluded_unreachable_folder_count": len(excluded_folders)}


def write_preset(root: Path, folders: list[str]) -> bool:
    path = root / "export_presets.cfg"
    text = path.read_text(encoding="utf-8")
    current = preset_patterns(text)
    kept = [pattern for pattern in current if pattern not in generated_patterns(current)]
    updated = ",".join(kept + patterns_for(folders))
    new_text = PRESET_LINE.sub(lambda _: 'exclude_filter="' + updated + '"', text, count=1)
    if new_text != text:
        path.write_text(new_text, encoding="utf-8")
    return new_text != text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--report", action="store_true")
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    files = tracked_files(root)
    computed = unreachable_actor_folders(root, files)
    result: dict = {"unreachable_folders": computed}
    if args.write:
        result["changed"] = write_preset(root, computed)
    patterns = preset_patterns((root / "export_presets.cfg").read_text(encoding="utf-8"))
    if args.check or args.write:
        result.update(check_generated(root, patterns, files))
        # New dead folders only cost APK size; report them without failing.
        result["not_yet_excluded"] = sorted(set(computed) - set(result["excluded_unreachable_folders"]))
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.report:
        print("\n".join(computed))
    print("ANDROID_RUNTIME_REACHABILITY_OK unreachable=%d excluded=%d not_yet_excluded=%d" % (
        len(computed), len(result.get("excluded_unreachable_folders", [])),
        len(result.get("not_yet_excluded", []))))
    if result.get("not_yet_excluded"):
        print("NOTE: run tools/android_runtime_reachability.py --write to also exclude: "
              + ", ".join(result["not_yet_excluded"][:10]), file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as error:
        print("ANDROID_RUNTIME_REACHABILITY_FAILED " + str(error), file=sys.stderr)
        raise SystemExit(1)
