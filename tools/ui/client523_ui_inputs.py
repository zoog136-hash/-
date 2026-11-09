#!/usr/bin/env python3
"""Verified original-UI source index from the complete 523 client.

Input: the 523 files_info.json and a directory holding the client's
Client/Data/UI*.dat (from client523_source.py or an extracted client).

* every UI*.dat listed in files_info 523 is checked against its SHA-1 and size
  there before any member is used; a listed DAT that is absent or differs stops
  the run (no substitute, no older version);
* each DAT must be a plain ZIP (no encrypted member); member CRCs are verified
  by zipfile while reading, and a member path present in two DATs stops the run;
* members are written unchanged (mode 0400) under <output>/members/<member> so
  that UI packs can hardlink them (build_original_ui_pack.py --link-originals);
* <output>/source-index.json is the builder's --source-index; every entry keeps
  its container, container SHA-1 and files_info version;
* <output>/csb-scenes.txt lists every CSB member (the builder's --scene-list).

All outputs are private and must stay outside Git.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import zipfile

HERE = Path(__file__).resolve().parent
SCHEMA = 'twilight-client523-ui-source-index-v1'
SOURCE_MODE = 'client523_files_info'
CONTAINER = re.compile(r'^Client/Data/UI\d+\.dat$')


class InputError(SystemExit):
    pass


def safe_member(name: str) -> bool:
    parts = name.split('/')
    return (bool(name) and not name.startswith('/') and '\\' not in name and ':' not in name
            and all(p not in ('', '.', '..') for p in parts))


def build(files_info: Path, dat_dir: Path, output: Path) -> dict:
    if output.exists():
        raise InputError(f'output must be a new directory: {output}')
    info_raw = files_info.read_bytes()
    info = json.loads(info_raw.decode('utf-8-sig'))
    if int(info.get('version', 0)) != 523:
        raise InputError('files_info is not version 523')
    want = {row['path'].replace('\\/', '/'): row for row in info['files']}
    containers = sorted((p for p in want if CONTAINER.match(p)),
                        key=lambda p: int(re.search(r'(\d+)\.dat$', p).group(1)))
    if not containers:
        raise InputError('files_info lists no UI*.dat')
    output.mkdir(parents=True, mode=0o700)
    members_root = output / 'members'
    source_files, container_rows = {}, {}
    extensions = collections.Counter()
    for container in containers:
        local = dat_dir / PurePosixPath(container).name
        if not local.is_file():
            local = dat_dir / container
        if not local.is_file():
            raise InputError(f'{container}: listed in files_info 523 but not supplied')
        raw = local.read_bytes()
        expected = want[container]
        if hashlib.sha1(raw).hexdigest() != expected['hash'] or len(raw) != int(expected['size']):
            raise InputError(f'{container}: SHA-1/size differs from files_info 523')
        count = 0
        with zipfile.ZipFile(local) as archive:
            for item in archive.infolist():
                if item.is_dir():
                    continue
                name = item.filename
                if not safe_member(name) or not name.startswith('UI/'):
                    raise InputError(f'{container}: unsafe or non-UI member {name!r}')
                if item.flag_bits & 1:
                    raise InputError(f'{container}: encrypted member {name}')
                if name in source_files:
                    raise InputError(f'duplicate UI member across DATs: {name}')
                body = archive.read(item)  # CRC verified by zipfile
                target = members_root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o400)
                with os.fdopen(descriptor, 'wb') as stream:
                    stream.write(body)
                source_files[name] = {'origin': str(target), 'sha256': hashlib.sha256(body).hexdigest(),
                                      'bytes': len(body), 'crc32': f'{item.CRC:08x}', 'container': container}
                extensions[PurePosixPath(name).suffix.lower()] += 1
                count += 1
        container_rows[container] = {'sha1': expected['hash'], 'bytes': len(raw),
                                     'files_info_version': int(expected['version']), 'members': count}
    index = {'schema': SCHEMA, 'source_mode': SOURCE_MODE, 'files_info_version': 523,
             'files_info_sha256': hashlib.sha256(info_raw).hexdigest(),
             'containers': container_rows, 'source_files': dict(sorted(source_files.items()))}
    raw = (json.dumps(index, ensure_ascii=False, indent=1, sort_keys=True) + '\n').encode()
    (output / 'source-index.json').write_bytes(raw)
    scenes = sorted(m for m in source_files if m.lower().endswith('.csb'))
    (output / 'csb-scenes.txt').write_text(''.join(m + '\n' for m in scenes), encoding='utf-8')
    return {'containers': len(containers), 'members': len(source_files), 'csb_scenes': len(scenes),
            'extensions': dict(extensions.most_common()),
            'member_bytes': sum(v['bytes'] for v in source_files.values()),
            'source_index': str(output / 'source-index.json'),
            'source_index_sha256': hashlib.sha256(raw).hexdigest()}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--files-info', type=Path, required=True)
    parser.add_argument('--dat-dir', type=Path, required=True, help='directory holding UI*.dat')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(argv)
    repo = HERE.parents[1]
    out = args.output.resolve()
    if out == repo or repo in out.parents:
        parser.error('--output must be outside the repository')
    print(json.dumps(build(args.files_info, args.dat_dir, out), ensure_ascii=False, indent=1))
    return 0


if __name__ == '__main__':
    sys.exit(main())
