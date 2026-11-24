#!/usr/bin/env python3
"""Create the private, deterministic native smelt sidecar from the pinned 523 ZIP."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

from build_five_systems import BASE_TABLES, SOURCE_SHA, compile_pack

SCHEMA = 'twilight-native-smelt-rules-v1'
TABLES = ('ItemSmelt', 'ItemSmeltEntity', 'ItemSpiritSmeltEntity', 'ItemSmeltSlotActive', 'ItemSmeltBonus')
MATERIALS = (289162, 359652, 359662, 359672, 359682, 372058, 372068, 372078, 372088, 374544, 374554, 374564, 374574)
MAX_BYTES = 128 * 1024


class ZipContent:
    """The existing compiler validates any table bytes through this read-only view."""

    def __init__(self, archive, path='content'):
        self.archive, self.path = archive, path

    def __truediv__(self, name):
        return ZipContent(self.archive, self.path + '/' + name)

    def read_bytes(self):
        return self.archive.read(self.path)

    def read_text(self, encoding):
        return self.read_bytes().decode(encoding)


def project(full):
    if full.get('source_sha256') != SOURCE_SHA:
        raise ValueError('unexpected original archive')
    source_tables = full['tables']
    tables = {key: source_tables[key] for key in TABLES}
    targets = {row['ItemClassID'] for key in ('ItemSmeltEntity', 'ItemSpiritSmeltEntity') for row in tables[key]}
    selectors = {'SpiritSmelt', 'SmeltExpireDate', 'DeleteTime'}
    tables['ItemBonus'] = [row for row in source_tables['ItemBonus'] if row['ItemClassID'] in MATERIALS
                           and full['bonuses'][str(row['BonusID'])]['name'] in selectors]
    ids = {row['BonusID'] for key in ('ItemSmeltBonus', 'ItemBonus') for row in tables[key]}
    # SmithSmelt reads these exact columns/compiled effects, not unrelated domains.
    bonuses = {str(i): {k: full['bonuses'][str(i)][k] for k in ('raw', 'name', 'record', 'supported')} for i in sorted(ids)}
    items = {str(i): {'raw': full['items'][str(i)]['raw']} for i in sorted(targets | set(MATERIALS))}
    sidecar = {'schema': SCHEMA, 'source_sha256': SOURCE_SHA, 'tables': tables, 'items': items, 'bonuses': bonuses}
    data = (json.dumps(sidecar, ensure_ascii=False, sort_keys=True, separators=(',', ':')) + '\n').encode()
    if len(data) > MAX_BYTES:
        raise ValueError('native smelt sidecar exceeds the runtime bound')
    return data


def build(source):
    with source.open('rb') as file:
        if hashlib.file_digest(file, 'sha256').hexdigest() != SOURCE_SHA:
            raise ValueError('validated 523 archive SHA mismatch')
        file.seek(0)
        with zipfile.ZipFile(file) as archive:
            names = archive.namelist()
            if len(names) != len(set(names)) or any('content/' + name + '.json' not in names for name in (*BASE_TABLES, *TABLES)):
                raise ValueError('duplicate or missing original ZIP members')
            if archive.testzip() is not None:
                raise ValueError('original archive CRC mismatch')
            return project(compile_pack(ZipContent(archive), {'아이템': []}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-zip', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    if output.is_relative_to(root):
        parser.error('private output must stay outside the source repository')
    data = build(args.source_zip)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('xb') as file:
        file.write(data)
    print(json.dumps({'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}))


if __name__ == '__main__':
    main()
