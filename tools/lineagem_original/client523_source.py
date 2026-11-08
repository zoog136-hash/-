#!/usr/bin/env python3
"""Materialize a verified current523 client source set for the existing builders.

Inputs are the user's own client files; outputs contain third-party originals and
belong in a private directory OUTSIDE this repository. Nothing is downloaded.

Every client file that is used is selected by exact SHA-1 against the supplied
``files_info.json`` of the target version (523). Candidates may come from:

* ``--client-zip``: the base client ZIP, either one file or raw byte-split parts
  given in order (``--client-zip a.part --client-zip b.part ...``). Parts are read
  as one virtual file; nothing is concatenated on disk.
* ``--patch-zip``: per-version patch ZIPs whose members use client paths
  (``Client/Data/...``). Members not listed in files_info are ignored.
* ``--client-dir``: an already extracted folder containing ``Client/...``.

A file whose 523 SHA-1 matches no candidate is reported missing; nothing nearby is
substituted. Outputs (see ``write_outputs``):

* ``sp2/Sprite/<id>-<n>.sp2``  -> ``build_reference_sp2_bank.py --original-root``
* ``spr/list_<n>.spr``         -> ``--spr-root`` / ``--spr-dir``
* ``tables/current523_content_tables.zip`` -> ``--tables-zip`` (deterministic)
* ``client523_receipt.json`` and ``client523_connection_report.json``

The content tables inside ``content*.dat`` are ZIP-encrypted. Pass the user's
password with ``--content-password-b64-file`` (base64 of the raw bytes). The value
is never written to any output or log.
"""
from __future__ import annotations

import argparse
import base64
from collections import Counter, defaultdict
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import zipfile

TARGET_VERSION = 523
SPRITE_DAT = re.compile(r'^Client/Data/Sprite\d+\.dat$')
CONTENT_DAT = re.compile(r'^Client/Data/content\d+\.dat$')
LIST_SPR = re.compile(r'^Client/Text/list_(\d+)\.spr$')
SP2_MEMBER = re.compile(r'^Sprite/(\d+)-(\d+)\.sp2$')
SPRITE_COLUMN = re.compile(r'^(Sprite|SpriteID|SpriteId|Sprite_Small|\w*SpriteID|\w*SpriteId)$')
HEADER = re.compile(rb'(?:^|\n)[ \t]*#(\d+)[ \t]+(\d+)(=(\d+))?')
FIXED_TIME = (1980, 1, 1, 0, 0, 0)


class SourceError(RuntimeError):
    pass


def sha1(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            value.update(block)
    return value.hexdigest()


class SplitFile(io.RawIOBase):
    """Read-only, seekable view over raw byte-split parts of one file."""

    def __init__(self, parts):
        super().__init__()
        self.parts = [Path(p) for p in parts]
        if not self.parts:
            raise SourceError('no client ZIP parts supplied')
        self.sizes = [p.stat().st_size for p in self.parts]
        self.starts, total = [], 0
        for size in self.sizes:
            self.starts.append(total)
            total += size
        self.total, self.pos, self.handles = total, 0, {}

    def readable(self):
        return True

    def seekable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=io.SEEK_SET):
        base = {io.SEEK_SET: 0, io.SEEK_CUR: self.pos, io.SEEK_END: self.total}[whence]
        self.pos = max(0, base + offset)
        return self.pos

    def readinto(self, buffer):
        view, done = memoryview(buffer), 0
        while done < len(view) and self.pos < self.total:
            index = max(i for i, start in enumerate(self.starts) if start <= self.pos)
            local = self.pos - self.starts[index]
            take = min(len(view) - done, self.sizes[index] - local)
            handle = self.handles.get(index)
            if handle is None:
                handle = self.handles[index] = self.parts[index].open('rb')
            handle.seek(local)
            chunk = handle.read(take)
            if not chunk:
                break
            view[done:done + len(chunk)] = chunk
            done += len(chunk)
            self.pos += len(chunk)
        return done

    def close(self):
        for handle in self.handles.values():
            handle.close()
        self.handles = {}
        super().close()


class ClientSource:
    """Exact-SHA-1 selection of client files from base, patches and folders."""

    def __init__(self, files_info: dict, client_zip=(), patch_zips=(), client_dir=None):
        self.version = int(files_info.get('version', 0))
        self.want = {}
        for row in files_info['files']:
            self.want[row['path'].replace('\\/', '/')] = row
        self.candidates = defaultdict(list)  # path -> [(label, reader)]
        self._open = []
        if client_dir:
            root = Path(client_dir)
            for path in self.want:
                local = root / path
                if local.is_file():
                    self.candidates[path].append((f'dir:{root}', lambda p=local: p.read_bytes()))
        for patch in patch_zips:
            archive = zipfile.ZipFile(patch)
            self._open.append(archive)
            for info in archive.infolist():
                if info.filename in self.want:
                    self.candidates[info.filename].append(
                        (f'patch:{Path(patch).name}', lambda a=archive, n=info.filename: a.read(n)))
        if client_zip:
            split = SplitFile(client_zip)
            archive = zipfile.ZipFile(split)
            self._open.extend([archive, split])
            for info in archive.infolist():
                if info.filename in self.want:
                    self.candidates[info.filename].append(
                        ('client-zip', lambda a=archive, n=info.filename: a.read(n)))

    def close(self):
        for item in self._open:
            item.close()

    def paths(self, pattern):
        return sorted(p for p in self.want if pattern.match(p))

    def read(self, path):
        """Return (bytes, label) whose SHA-1 equals the target, else raise."""
        expected = self.want[path]['hash']
        for label, reader in self.candidates.get(path, ()):
            data = reader()
            if sha1(data) == expected and len(data) == int(self.want[path]['size']):
                return data, label
        raise SourceError(f'no candidate matches {self.version} SHA-1 for {path}')


def content_tables(source, password, receipt):
    """Decode content/*.json from the target content DATs. Returns {name: bytes}."""
    tables = {}
    for path in source.paths(CONTENT_DAT):
        data, label = source.read(path)
        receipt['used'][path] = {'sha1': sha1(data), 'from': label}
        archive = zipfile.ZipFile(io.BytesIO(data))
        if password:
            archive.setpassword(password)
        for info in archive.infolist():
            if info.is_dir() or not info.filename.endswith('.json'):
                continue
            if info.flag_bits & 1 and not password:
                raise SourceError('content tables are encrypted; supply --content-password-b64-file')
            body = archive.read(info)  # CRC verified by zipfile
            json.loads(body.decode('utf-8-sig'))
            if info.filename in tables and tables[info.filename] != body:
                raise SourceError(f'conflicting duplicate table {info.filename}')
            tables[info.filename] = body
    return tables


def deterministic_zip(entries: dict) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name in sorted(entries):
            info = zipfile.ZipInfo(name, FIXED_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, entries[name])
    return buffer.getvalue()


def sprite_declarations(list_files: dict):
    """Header scan used by the client loader: '#id total[=alias]'. Returns (declared, alias)."""
    declared, alias = set(), {}
    for name in sorted(list_files, key=lambda n: int(LIST_SPR.match(n).group(1))):
        for match in HEADER.finditer(list_files[name]):
            sprite = int(match.group(1))
            declared.add(sprite)
            if match.group(4):
                alias[sprite] = int(match.group(4))
    return declared, alias


def resolve(sprite, inventory, alias):
    seen = set()
    while sprite not in inventory and sprite in alias and sprite not in seen:
        seen.add(sprite)
        sprite = alias[sprite]
    return sprite if sprite in inventory else None


def connection_report(inventory_files, tables, list_files):
    inventory = defaultdict(set)
    for member in inventory_files:
        match = SP2_MEMBER.match(member)
        if match:
            inventory[int(match.group(1))].add(int(match.group(2)))
    declared, alias = sprite_declarations(list_files)
    columns = defaultdict(set)
    for name, body in tables.items():
        table = PurePosixPath(name).stem
        data = json.loads(body.decode('utf-8-sig'))
        rows = data.get('rows', []) if isinstance(data, dict) else data
        for row in rows if isinstance(rows, list) else []:
            if not isinstance(row, dict) or (table == 'NpcClass' and row.get('TestNPC')):
                continue
            for key, value in row.items():
                if SPRITE_COLUMN.match(key) and type(value) is int and value > 0:
                    columns[f'{table}.{key}'].add(value)
    referenced = set().union(*columns.values()) if columns else set()
    ids = set(inventory)
    direct = referenced & ids
    via_alias = {s for s in referenced - ids if resolve(s, ids, alias) is not None}
    unresolved = sorted(referenced - direct - via_alias)
    per_column = {}
    for column, values in sorted(columns.items()):
        d = len(values & ids)
        a = sum(1 for v in values - ids if resolve(v, ids, alias) is not None)
        per_column[column] = {'ids': len(values), 'direct': d, 'via_alias': a,
                              'unresolved': len(values) - d - a}
    return {
        'inventory': {'sp2_files': sum(map(len, inventory.values())), 'sprite_ids': len(ids)},
        'declarations': {'declared_ids': len(declared), 'sprite_aliases': len(alias),
                         'inventory_ids_declared': len(ids & declared),
                         'inventory_ids_undeclared': len(ids - declared)},
        'table_references': {'referenced_ids': len(referenced), 'direct': len(direct),
                             'via_alias': len(via_alias), 'unresolved': len(unresolved),
                             'unresolved_ids': unresolved, 'per_column': per_column},
        'semantics': 'Reference resolution only. Declared/alias-connected does not prove '
                     'correct playback, blending or gameplay use.',
    }


def compare_tables_zip(path: Path, tables: dict) -> dict:
    """Compare an existing runtime tables ZIP's content/*.json with the decoded client tables."""
    with zipfile.ZipFile(path) as archive:
        theirs = {n: archive.read(n) for n in archive.namelist() if re.match(r'^content/[A-Za-z0-9_]+\.json$', n)}
    same = sorted(n for n in theirs if tables.get(n) == theirs[n])
    differ = sorted(n for n in theirs if n in tables and tables[n] != theirs[n])
    return {'path': str(path), 'sha256': sha256_file(path), 'tables_in_zip': len(theirs),
            'byte_identical': len(same), 'different': differ,
            'only_in_zip': sorted(set(theirs) - set(tables)), 'only_in_client': sorted(set(tables) - set(theirs)),
            'equivalent': not differ and set(theirs) == set(tables)}


def write_outputs(source, out: Path, password, extract_sp2=True, sprite_filter=None, verify_tables_zip=None):
    if out.exists() and any(out.iterdir()):
        raise SourceError(f'output directory must be new or empty: {out}')
    out.mkdir(parents=True, exist_ok=True)
    receipt = {'schema': 1, 'target_version': source.version, 'used': {}, 'missing': [],
               'outputs': {}, 'password_recorded': False}
    # list_*.spr
    list_files = {}
    (out / 'spr').mkdir()
    for path in source.paths(LIST_SPR):
        try:
            data, label = source.read(path)
        except SourceError:
            receipt['missing'].append(path)
            continue
        receipt['used'][path] = {'sha1': sha1(data), 'from': label}
        list_files[path] = data
        (out / 'spr' / PurePosixPath(path).name).write_bytes(data)
    # content tables
    tables = content_tables(source, password, receipt)
    if verify_tables_zip is not None:
        receipt['runtime_tables_zip_comparison'] = compare_tables_zip(verify_tables_zip, tables)
    (out / 'tables').mkdir()
    zip_bytes = deterministic_zip(tables)
    tables_zip = out / 'tables' / 'current523_content_tables.zip'
    tables_zip.write_bytes(zip_bytes)
    receipt['outputs']['tables_zip'] = {'path': 'tables/current523_content_tables.zip',
                                        'sha256': sha256_bytes(zip_bytes), 'tables': len(tables)}
    # SP2 inventory and optional extraction
    inventory, conflicts = {}, 0
    sp2_root = out / 'sp2'
    for path in source.paths(SPRITE_DAT):
        try:
            data, label = source.read(path)
        except SourceError:
            receipt['missing'].append(path)
            continue
        receipt['used'][path] = {'sha1': sha1(data), 'from': label}
        archive = zipfile.ZipFile(io.BytesIO(data))
        for info in archive.infolist():
            match = SP2_MEMBER.match(info.filename)
            if not match:
                continue
            if sprite_filter is not None and int(match.group(1)) not in sprite_filter:
                continue
            if info.filename in inventory:
                conflicts += 1
                raise SourceError(f'duplicate SP2 member across DATs: {info.filename}')
            inventory[info.filename] = {'bytes': info.file_size, 'crc32': f'{info.CRC:08x}',
                                        'container': path}
            if extract_sp2:
                target = sp2_root / info.filename
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.read(info))  # CRC verified by zipfile
    receipt['outputs']['sp2'] = {'root': 'sp2', 'members': len(inventory), 'extracted': extract_sp2,
                                 'bytes': sum(v['bytes'] for v in inventory.values())}
    inventory_path = out / 'client523_sp2_inventory.json'
    inventory_path.write_text(json.dumps(inventory, sort_keys=True, separators=(',', ':')))
    receipt['outputs']['sp2_inventory'] = {'path': inventory_path.name,
                                           'sha256': sha256_file(inventory_path)}
    report = connection_report(inventory, tables, list_files)
    (out / 'client523_connection_report.json').write_text(
        json.dumps(report, ensure_ascii=False, indent=1, sort_keys=True))
    receipt['complete'] = not receipt['missing']
    (out / 'client523_receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=1, sort_keys=True))
    return receipt, report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--files-info', type=Path, required=True,
                        help='files_info.json of the target client version (523)')
    parser.add_argument('--client-zip', type=Path, action='append', default=[],
                        help='base client ZIP, or its raw split parts in order (repeat)')
    parser.add_argument('--patch-zip', type=Path, action='append', default=[])
    parser.add_argument('--client-dir', type=Path)
    parser.add_argument('--content-password-b64-file', type=Path)
    parser.add_argument('--output', type=Path, required=True,
                        help='new private directory outside the repository')
    parser.add_argument('--verify-tables-zip', type=Path,
                        help='existing runtime tables ZIP (e.g. the pinned d5192c3c ZIP) to compare table-by-table')
    parser.add_argument('--no-extract-sp2', action='store_true',
                        help='inventory and report only; do not write SP2 files')
    parser.add_argument('--sprite-id', type=int, action='append',
                        help='limit SP2 output to these sprite IDs (repeat)')
    args = parser.parse_args(argv)
    repo = Path(__file__).resolve().parents[2]
    out = args.output.resolve()
    if out == repo or repo in out.parents:
        parser.error('--output must be outside the repository (outputs contain original files)')
    info = json.loads(args.files_info.read_text(encoding='utf-8-sig'))
    if int(info.get('version', 0)) != TARGET_VERSION:
        parser.error(f'files_info version {info.get("version")} is not {TARGET_VERSION}')
    password = None
    if args.content_password_b64_file:
        password = base64.b64decode(args.content_password_b64_file.read_text().strip())
    source = ClientSource(info, args.client_zip, args.patch_zip, args.client_dir)
    try:
        receipt, report = write_outputs(source, out, password, not args.no_extract_sp2,
                                        set(args.sprite_id) if args.sprite_id else None,
                                        args.verify_tables_zip)
    finally:
        source.close()
    refs = report['table_references']
    print(json.dumps({'complete': receipt['complete'], 'missing': len(receipt['missing']),
                      'sp2_members': receipt['outputs']['sp2']['members'],
                      'tables': receipt['outputs']['tables_zip']['tables'],
                      'tables_zip_sha256': receipt['outputs']['tables_zip']['sha256'],
                      'runtime_tables_equivalent': receipt.get('runtime_tables_zip_comparison', {}).get('equivalent'),
                      'referenced_ids': refs['referenced_ids'], 'direct': refs['direct'],
                      'via_alias': refs['via_alias'], 'unresolved': refs['unresolved']},
                     ensure_ascii=False))
    return 0 if receipt['complete'] else 2


if __name__ == '__main__':
    sys.exit(main())
