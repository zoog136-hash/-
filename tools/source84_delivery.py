#!/usr/bin/env python3
"""Offline, hash-pinned source84 delivery. Never downloads or publishes art."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'data/maps/source84_delivery_manifest.json'


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def inventory():
    value = json.loads(MANIFEST.read_text())
    assert value['schema'] == 1 and len(value['files']) == value['total_files']
    for name in value['files']:
        p = PurePosixPath(name)
        if p.is_absolute() or '..' in p.parts or '\\' in name:
            raise ValueError('Unsafe manifest path')
    return value


def verify(root, spec):
    if not root.is_dir() or root.is_symlink():
        raise ValueError('Pack absent or symlink: ' + str(root))
    actual = set()
    for path in root.rglob('*'):
        if path.is_symlink():
            raise ValueError('Symlink in pack: ' + str(path))
        if path.is_file():
            actual.add(path.relative_to(root).as_posix())
    if actual != set(spec['files']):
        raise ValueError('Pack inventory mismatch: missing=%d extra=%d' %
                         (len(set(spec['files']) - actual), len(actual - set(spec['files']))))
    for name, row in spec['files'].items():
        path = root / name
        if path.stat().st_size != row['bytes'] or digest(path) != row['sha256']:
            raise ValueError('Pack SHA/size mismatch: ' + name)
    return {'files': len(actual), 'bytes': sum(v['bytes'] for v in spec['files'].values())}


def check_archive(path, spec):
    if 'manual_archive' in spec:
        row = spec['manual_archive']
        if path.stat().st_size != row['bytes'] or digest(path) != row['sha256']:
            raise ValueError('Private archive size/SHA differs from delivery receipt')
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or set(names) != set(spec['files']):
            raise ValueError('Archive must contain exactly the pinned runtime files')
        for name, row in spec['files'].items():
            info = archive.getinfo(name)
            if info.file_size != row['bytes']:
                raise ValueError('Archive size mismatch: ' + name)
            with archive.open(name) as stream:
                # Reading to EOF also validates ZIP CRC.
                if hashlib.file_digest(stream, 'sha256').hexdigest() != row['sha256']:
                    raise ValueError('Archive SHA mismatch: ' + name)


def package(root, output, spec):
    verify(root, spec)
    if output.exists() or root.resolve() in output.resolve().parents:
        raise ValueError('Output must be new and outside the source pack')
    if shutil.disk_usage(output.parent).free < spec['total_bytes'] + 64 * 1024**2:
        raise ValueError('Insufficient space for private archive')
    try:
        with zipfile.ZipFile(output, 'x', compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
            for name in sorted(spec['files']):
                info = zipfile.ZipInfo(name, date_time=(2026, 10, 30, 0, 0, 0))
                info.external_attr = 0o100644 << 16
                with archive.open(info, 'w', force_zip64=True) as dest, (root / name).open('rb') as source:
                    shutil.copyfileobj(source, dest)
        check_archive(output, spec)
    except BaseException:
        output.unlink(missing_ok=True)
        raise
    return {'archive': str(output), 'bytes': output.stat().st_size, 'sha256': digest(output),
            'delivery': 'local only; no remote upload performed'}


def install(target, spec, archive=None, source=None, hardlink=False):
    # Never overwrite a prior install, including a corrupt one or a user save.
    if target.exists() or target.is_symlink():
        return verify(target, spec)
    if archive:
        check_archive(archive, spec)
    else:
        verify(source, spec)
    target.parent.mkdir(parents=True, exist_ok=True)
    if not hardlink and shutil.disk_usage(target.parent).free < spec['total_bytes'] + 64 * 1024**2:
        raise ValueError('Insufficient free space for an atomic install')
    with tempfile.TemporaryDirectory(prefix='.source84-stage-', dir=target.parent) as temp:
        stage = Path(temp) / 'pack'
        stage.mkdir()
        if archive:
            with zipfile.ZipFile(archive) as z:
                for name in spec['files']:
                    dest = stage / name
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    with z.open(name) as src, dest.open('xb') as out:
                        shutil.copyfileobj(src, out)
        else:
            for name in spec['files']:
                dest = stage / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                if hardlink:
                    os.link(source / name, dest)
                else:
                    shutil.copyfile(source / name, dest)
        result = verify(stage, spec)
        stage.rename(target)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    p = sub.add_parser('verify'); p.add_argument('--pack-root', type=Path, required=True)
    p = sub.add_parser('check-archive'); p.add_argument('--archive', type=Path, required=True)
    p = sub.add_parser('package'); p.add_argument('--pack-root', type=Path, required=True); p.add_argument('--output', type=Path, required=True)
    p = sub.add_parser('install')
    inputs = p.add_mutually_exclusive_group(required=True)
    inputs.add_argument('--archive', type=Path); inputs.add_argument('--source-dir', type=Path)
    dest = p.add_mutually_exclusive_group(required=True)
    dest.add_argument('--project', type=Path, help='Install a bundled pack for editor/APK export')
    dest.add_argument('--user-root', type=Path, help='Exact Godot user data directory, not its source_maps_v3 child')
    p.add_argument('--hardlink', action='store_true', help='Immutable same-filesystem build input only; never edit linked files')
    p = sub.add_parser('export')
    p.add_argument('--project', type=Path, default=ROOT)
    p.add_argument('--godot', required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--preset', default='Android')
    args = parser.parse_args(); spec = inventory()
    if args.action == 'verify': result = verify(args.pack_root, spec)
    elif args.action == 'check-archive':
        check_archive(args.archive, spec); result = {'archive_verified': True}
    elif args.action == 'package': result = package(args.pack_root, args.output, spec)
    elif args.action == 'export':
        verify(args.project / 'external_map_packs/source84_v3', spec)
        if 'res://addons/source84_export/plugin.cfg' not in (args.project / 'project.godot').read_text():
            raise ValueError('Source84 raw-file export plugin must be enabled')
        args.output.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([args.godot, '--headless', '--path', str(args.project.resolve()),
                        '--export-debug', args.preset, str(args.output.resolve())], check=True)
        result = {'export': str(args.output), 'sha256': digest(args.output)}
    else:
        if args.hardlink and not args.source_dir: parser.error('--hardlink requires --source-dir')
        target = args.project / 'external_map_packs/source84_v3' if args.project else args.user_root / 'source_maps_v3'
        result = install(target, spec, args.archive, args.source_dir, args.hardlink)
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    main()
