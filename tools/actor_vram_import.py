#!/usr/bin/env python3
"""Choose large exported actor sheets for GPU (VRAM/ETC2) texture import.

Lossless sheets are decoded on the CPU when a monster/boss first appears:
a boss's 35 sheets took ~1.3 s (desktop) versus ~70 ms as ETC2, with about a
quarter of the GPU memory. ETC2 stores 1 byte per pixel, so a sheet is chosen
only when that is not larger than its PNG; the APK must not grow (it is near
the 4 GB limit). Rules (all must hold):
  - under assets/actors/, a .png larger than 1 MB, not under a .gdignore folder
  - exported to Android (not matched by export_presets.cfg exclude_filter)
  - width and height are multiples of 4 (block compression, no resampling)
  - width*height <= PNG bytes

  --list   print the selection
  --write  set compress/mode=2 in each selected sheet's existing .import
           (run a Godot import first so every .import exists)
  --check  fail if a selected sheet lacks a tracked VRAM .import, or a
           tracked actor .import with mode=2 is no longer selected
"""
from __future__ import annotations
import argparse
import fnmatch
import re
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIN_BYTES = 1_000_000


def png_size(path: Path) -> tuple[int, int]:
    with path.open('rb') as handle:
        head = handle.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n' or head[12:16] != b'IHDR':
        raise ValueError('Not a PNG: ' + str(path))
    return struct.unpack('>II', head[16:24])


def excluded_patterns(root: Path) -> list[str]:
    text = (root / 'export_presets.cfg').read_text(encoding='utf-8')
    found = re.findall(r'^exclude_filter="([^"]*)"', text, re.M)
    if len(found) != 1:
        raise ValueError('Expected exactly one exclude_filter')
    return [pattern for pattern in found[0].split(',') if pattern]


def select(root: Path) -> list[str]:
    patterns = excluded_patterns(root)
    ignored: list[Path] = [marker.parent for marker in (root / 'assets/actors').rglob('.gdignore')]
    chosen: list[str] = []
    for path in sorted((root / 'assets/actors').rglob('*.png')):
        relative = path.relative_to(root).as_posix()
        size = path.stat().st_size
        if size <= MIN_BYTES or any(folder in path.parents for folder in ignored):
            continue
        if any(fnmatch.fnmatchcase(relative, pattern) for pattern in patterns):
            continue
        width, height = png_size(path)
        if width % 4 or height % 4 or width * height > size:
            continue
        chosen.append(relative)
    return chosen


def import_mode(path: Path) -> str | None:
    if not path.is_file():
        return None
    found = re.search(r'^compress/mode=(\d+)$', path.read_text(encoding='utf-8'), re.M)
    return found.group(1) if found else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--list', action='store_true')
    action.add_argument('--write', action='store_true')
    action.add_argument('--check', action='store_true')
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    root = args.root.resolve()
    chosen = select(root)
    if args.list:
        print('\n'.join(chosen))
        return 0
    if args.write:
        missing = 0
        for relative in chosen:
            target = root / (relative + '.import')
            if not target.is_file():
                missing += 1
                continue
            text = target.read_text(encoding='utf-8')
            target.write_text(re.sub(r'^compress/mode=\d+$', 'compress/mode=2', text, flags=re.M), encoding='utf-8')
        print('ACTOR_VRAM_WRITE selected=%d missing_import=%d' % (len(chosen), missing))
        return 1 if missing else 0
    tracked = set(subprocess.run(['git', '-C', str(root), 'ls-files', '--', 'assets/actors/*.import'],
                                 check=True, capture_output=True, text=True).stdout.split())
    problems = [relative for relative in chosen
                if relative + '.import' not in tracked or import_mode(root / (relative + '.import')) != '2']
    stale = [name for name in tracked if import_mode(root / name) == '2' and name[:-len('.import')] not in chosen]
    for name in problems[:20]:
        print('ACTOR_VRAM_MISSING ' + name)
    for name in stale[:20]:
        print('ACTOR_VRAM_STALE ' + name)
    print('ACTOR_VRAM_CHECK selected=%d missing=%d stale=%d' % (len(chosen), len(problems), len(stale)))
    return 1 if problems or stale else 0


if __name__ == '__main__':
    sys.exit(main())
