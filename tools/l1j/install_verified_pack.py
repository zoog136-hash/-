"""Install additive private resource ZIPs after a complete CRC/path/conflict preflight."""
from __future__ import annotations
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import tempfile
import zipfile

PREFIXES = ('assets/l1j/', 'data/l1j/')
SUFFIXES = {'.png', '.json', '.tres', '.bin', '.l1jpng'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def install(root: Path, archives: list[Path]):
    root = root.resolve(strict=True)
    entries, total = {}, 0
    created = []
    with contextlib.ExitStack() as stack:
        for archive in archives:
            z = stack.enter_context(zipfile.ZipFile(archive))
            if len(z.infolist()) > 50000:
                raise ValueError('Pack exceeds entry limit')
            for info in z.infolist():
                if info.is_dir():
                    continue
                path = PurePosixPath(info.filename)
                if (not info.filename.startswith(PREFIXES) or '\\' in info.filename
                        or path.is_absolute() or '..' in path.parts
                        or path.suffix not in SUFFIXES or stat.S_ISLNK(info.external_attr >> 16)):
                    raise ValueError(f'Unsafe resource entry: {info.filename}')
                if info.file_size > 256 * 1024 * 1024:
                    raise ValueError('Entry exceeds size limit')
                total += info.file_size
                if total > 2 * 1024**3:
                    raise ValueError('Combined packs exceed size limit')
                target = root.joinpath(*path.parts)
                if not target.resolve().is_relative_to(root):
                    raise ValueError('Resource path escapes project through a symlink')
                for parent in (target, *target.parents):
                    if parent == root:
                        break
                    if parent.is_symlink():
                        raise ValueError('Resource path contains a symlink')
                data = z.read(info)  # validates every entry's CRC before any project mutation
                sha = digest(data)
                if info.filename in entries and entries[info.filename][2] != sha:
                    raise ValueError(f'Conflicting packs: {info.filename}')
                if target.exists() and (not target.is_file() or digest(target.read_bytes()) != sha):
                    raise ValueError(f'Existing file differs; never overwritten: {info.filename}')
                entries[info.filename] = (z, info, sha)
        # Materialize verified bytes in a temporary sibling, then publish only new files.
        with tempfile.TemporaryDirectory(prefix='.l1j-install-', dir=root) as temporary:
            staging = Path(temporary)
            for name, (z, info, sha) in entries.items():
                target = root / name
                if target.exists():
                    continue
                staged = staging / name
                staged.parent.mkdir(parents=True, exist_ok=True)
                staged.write_bytes(z.read(info))
                if digest(staged.read_bytes()) != sha:
                    raise ValueError(f'Staged bytes changed: {name}')
            try:
                for name, (_, _, sha) in entries.items():
                    target = root / name
                    staged = staging / name
                    if not staged.exists():
                        continue
                    target.parent.mkdir(parents=True, exist_ok=True)
                    # Hard-link publication fails rather than racing to overwrite a file.
                    os.link(staged, target)
                    created.append((target, sha))
            except Exception:
                for target, sha in reversed(created):
                    if target.is_file() and digest(target.read_bytes()) == sha:
                        target.unlink()
                raise
    print(json.dumps({'verified_entries': len(entries), 'installed': len(created),
                      'unchanged': len(entries) - len(created), 'overwritten': 0}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('archives', type=Path, nargs='+')
    args = parser.parse_args()
    install(args.root, args.archives)
