#!/usr/bin/env python3
"""Private image pack inputs from the complete 523 client (no earlier handoff).

Replaces the earlier handoff for build_source523_image_pack.py with inputs
derived directly from the client:

* every Client/Data/Image*.dat and icon*.dat listed in the 523 files_info.json is
  checked against its SHA-1/size there before use;
* each container is strictly decoded with decode_source523_image_dat.py (exact
  original member bytes, PKCS7, full image decode, PNG chunk CRCs);
* the combined verified-member catalog, decoder summary, source index and
  source tables are written in the shape the pack builder reads, with
  ``source_mode = client523_files_info`` and one component,
  ``client523_files_info_verified``.

All outputs are private and must stay outside Git. The AES key is read from a
private base64 file and written only to the private params file (mode 0600).
"""
from __future__ import annotations

import argparse
import base64
import collections
import gzip
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import zipfile

HERE = Path(__file__).resolve().parent
_SPEC = importlib.util.spec_from_file_location('decode_source523_image_dat', HERE / 'decode_source523_image_dat.py')
DECODER = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(DECODER)

SOURCE_MODE = 'client523_files_info'
COMPONENT = 'client523_files_info_verified'
ALIGNMENT = 'client523_files_info_sha1_size_verified'
CONTAINER = re.compile(r'^Client/Data/(Image|icon)\d+\.dat$')
CATALOG = 'current523-verified-member-catalog.jsonl'
SUMMARY = 'decoder-summary.json'
SOURCE_INDEX = 'source-index.json'


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_private(path: Path, data: bytes) -> None:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'wb') as stream:
        stream.write(data)


def compact(value) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'), sort_keys=True)


def source_tables(tables_zip: Path, output: Path) -> tuple[list, dict]:
    """Write content tables and a strict source index (path/version/bytes/sha256/rows)."""
    index, written = [], {}
    tables_dir = output / 'tables'
    tables_dir.mkdir()
    with zipfile.ZipFile(tables_zip) as archive:
        for name in sorted(archive.namelist()):
            match = re.fullmatch(r'content/([A-Za-z0-9_]+)\.json', name)
            if not match:
                continue
            raw = archive.read(name)  # CRC verified by zipfile
            table = json.loads(raw.decode('utf-8-sig'))
            rows = table.get('rows') if isinstance(table, dict) else None
            if not isinstance(rows, list):
                continue
            index.append({'path': name, 'version': 523, 'status': 'strict_json_pass', 'member_crc_verified': True,
                          'bytes': len(raw), 'sha256': sha256(raw), 'row_count': len(rows)})
            (tables_dir / (match.group(1) + '.json')).write_bytes(raw)
            written[match.group(1)] = len(rows)
    return index, written


def build(files_info: Path, dat_dir: Path, tables_zip: Path, key_file: Path, output: Path) -> dict:
    if output.exists():
        raise SystemExit(f'output must be a new directory: {output}')
    info = json.loads(files_info.read_text(encoding='utf-8-sig'))
    if int(info.get('version', 0)) != 523:
        raise SystemExit('files_info is not version 523')
    want = {row['path'].replace('\\/', '/'): row for row in info['files']}
    containers = sorted(p for p in want if CONTAINER.match(p))
    key = base64.b64decode(key_file.read_text().strip())
    if len(key) != 16:
        raise SystemExit('image/icon key must decode to 16 bytes')
    output.mkdir(parents=True, mode=0o700)
    params = {'aes128_key_hex': key.hex(),
              'source_provenance': {'kind': 'user_supplied_public_pakviewer_dat_key',
                                    'files_info_sha256': sha256(files_info.read_bytes())}}
    write_private(output / 'params.json', json.dumps(params).encode())
    decoder_root = output / 'decoder'
    for name in ('staging', 'records', 'containers', 'failures', 'decoded'):
        (decoder_root / name).mkdir(parents=True)

    catalog_rows, failures, summaries = [], [], []
    for container in containers:
        local = dat_dir / PurePosixPath(container).name
        raw = local.read_bytes()
        expected = want[container]
        if hashlib.sha1(raw).hexdigest() != expected['hash'] or len(raw) != int(expected['size']):
            raise SystemExit(f'{container}: SHA-1/size differs from files_info 523')
        identity = {'sha256': sha256(raw), 'bytes': len(raw), 'sha1': expected['hash'],
                    'files_info_version': int(expected['version']), 'current523_alignment': ALIGNMENT}
        summary, rows, errors = DECODER.process_container(local, decoder_root, params, identity)
        if errors:
            failures.extend(errors)
            DECODER.json_write(decoder_root / 'failures' / (local.name + '.json'), errors)
            print(compact({'container': container, 'status': 'failed', 'errors': len(errors)}), flush=True)
            continue
        for row in rows:
            row['current523_component'] = COMPONENT
        records = ''.join(compact(row) + '\n' for row in rows).encode()
        (decoder_root / 'records' / (local.name + '.jsonl')).write_bytes(records)
        summary['records_sha256'] = sha256(records)
        DECODER.json_write(decoder_root / 'containers' / (local.name + '.json'), summary)
        summaries.append(summary)
        catalog_rows.extend(rows)
        print(compact({'container': container, 'status': 'verified', 'members': len(rows)}), flush=True)
    shutil.rmtree(decoder_root / 'staging')

    catalog_rows.sort(key=lambda row: (row['container'], row['path']))
    catalog = ''.join(compact(row) + '\n' for row in catalog_rows).encode()
    (decoder_root / CATALOG).write_bytes(catalog)
    components = {COMPONENT: {'files': len(catalog_rows),
                              'stored_member_bytes': sum(r['encrypted_bytes'] for r in catalog_rows),
                              'plain_file_bytes': sum(r['plain_bytes'] for r in catalog_rows)}}
    complete = not failures and len(summaries) == len(containers)
    decoder_summary = {
        'schema': 1, 'source_mode': SOURCE_MODE, 'strict_failure_count': len(failures), 'failures': failures,
        'files_info_sha256': sha256(files_info.read_bytes()), 'files_info_version': 523,
        'planned_containers': len(containers), 'verified_containers': len(summaries),
        'catalog_bytes': len(catalog), 'catalog_sha256': sha256(catalog),
        'verified_original_members': len(catalog_rows), 'components': components,
        'source_current_catalog_complete': complete,
        'source_current_catalog_completion_checks': {
            'every_files_info_image_icon_container_sha1_verified': len(summaries) == len(containers),
            'every_index_entry_strictly_decoded': not failures,
            'index_exactly_consumed_in_every_container': all(s.get('index_exactly_consumed') for s in summaries)},
        'whole_current_source_member_denominator': len(catalog_rows),
        'decoder_sha256': sha256((HERE / 'decode_source523_image_dat.py').read_bytes()),
        'actual_game_consumption_observed': 0}
    summary_raw = (json.dumps(decoder_summary, ensure_ascii=False, indent=1, sort_keys=True) + '\n').encode()
    (decoder_root / SUMMARY).write_bytes(summary_raw)

    index, tables = source_tables(tables_zip, output)
    index_raw = (json.dumps(index, ensure_ascii=False, indent=1) + '\n').encode()
    (output / SOURCE_INDEX).write_bytes(index_raw)
    return {'containers': len(containers), 'verified_containers': len(summaries), 'members': len(catalog_rows),
            'strict_failures': len(failures),
            'formats': dict(collections.Counter(r['format'] for r in catalog_rows)),
            'tables': len(tables), 'decoder_summary': str(decoder_root / SUMMARY),
            'decoder_summary_sha256': sha256(summary_raw), 'source_index': str(output / SOURCE_INDEX),
            'source_index_sha256': sha256(index_raw)}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--files-info', type=Path, required=True)
    parser.add_argument('--dat-dir', type=Path, required=True, help='directory holding Image*.dat and icon*.dat')
    parser.add_argument('--tables-zip', type=Path, required=True, help='523 content tables ZIP')
    parser.add_argument('--key-b64-file', type=Path, required=True, help='private base64 AES-128 image/icon key')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(argv)
    repo = HERE.parents[1]
    out = args.output.resolve()
    if out == repo or repo in out.parents:
        parser.error('--output must be outside the repository')
    result = build(args.files_info, args.dat_dir, args.tables_zip, args.key_b64_file, out)
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return 0 if result['strict_failures'] == 0 else 2


if __name__ == '__main__':
    sys.exit(main())
