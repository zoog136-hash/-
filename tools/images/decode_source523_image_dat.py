#!/usr/bin/env python3
"""Strict original Image/icon DAT decoding with an external private parameter file.

Public format reference (source only; no upstream code/executable is imported):
https://github.com/tony1223/PakViewer/blob/fbad69239e3e3c12ec18dfc7722bed284be093cc/src/Lin.Helper.Core/Dat/DatFile.cs
Exact Git blob: 3fa549cc17de9853dbc35d0263edce670f3e2f7a.
Source bytes SHA256: ccc63d4ffccb5bdb04301a8c6a5235d9d58f48b7a07e6d620abad39bd9fe8352.

Requires Pillow and cryptography. --params must point to private JSON containing
`aes128_key_hex` and `source_provenance`; this module contains no real parameters.
--plan is a private JSON list of container/path/identity/retained records.
--catalog and --lineage are private gzip JSONL files with retained expectations.
Original paths and detected PNG/JPEG/BMP bytes are preserved without reencoding.

This verifies byte recovery and full image decoding, not actual game consumption.
Invalid input fails closed. An interrupted final promotion can require explicit
quarantine of incomplete output before retry; existing destinations are rejected.
"""
import argparse
import collections
import datetime
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import struct
import tempfile
import unicodedata
import warnings
import zlib

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from PIL import Image, ImageFile

ImageFile.LOAD_TRUNCATED_IMAGES = False


class ValidationError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ValidationError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def strict_unpad(data, block_size=16):
    require(bool(data) and len(data) % block_size == 0, 'PKCS7 input must contain complete nonempty blocks')
    n = data[-1]
    require(1 <= n <= block_size, 'invalid PKCS7 padding length')
    require(data[-n:] == bytes([n]) * n, 'invalid PKCS7 padding bytes')
    return data[:-n], n


def decrypt(data, key, iv):
    require(len(key) == 16 and len(iv) == 16, 'AES128 key/IV size mismatch')
    require(bool(data) and len(data) % 16 == 0, 'CBC ciphertext has partial/empty block')
    operation = Cipher(algorithms.AES(key), modes.CBC(iv)).decryptor()
    return operation.update(data) + operation.finalize()


def safe_path(path_bytes):
    try:
        path = path_bytes.decode('utf-8', errors='strict')
    except UnicodeDecodeError as exc:
        raise ValidationError('invalid UTF8 member path') from exc
    require(bool(path), 'empty member path')
    require(not path.startswith('/') and '\\' not in path and ':' not in path, 'absolute/drive/backslash member path')
    require(all(p not in ('', '.', '..') for p in path.split('/')), 'unsafe member path component')
    require(all(not unicodedata.category(c).startswith('C') for c in path), 'control/NUL member path')
    require(path.split('/')[0] in ('Image', 'icon'), 'outside Image/icon scope')
    return path


def read_footer(raw):
    require(len(raw) >= 10, 'truncated footer or empty container')
    offset, size, flag = struct.unpack_from('<iiB', raw, len(raw) - 9)
    require(offset >= 0 and size > 0, 'negative/empty footer index extent')
    require(offset <= len(raw) - 9 and size <= len(raw) - 9 - offset, 'index extent outside container')
    require(offset + size == len(raw) - 9, 'unaccounted bytes between index and footer')
    if flag != 0:
        require(offset % 16 == 0 and size % 16 == 0, 'encrypted index/body extent not block aligned')
    return {'index_offset': offset, 'index_bytes': size, 'encryption_flag': flag, 'encrypted': flag != 0}


def parse_index(data, body_end, encrypted):
    pos = 0
    entries = []
    exact = set()
    folded = set()
    while pos < len(data):
        require(len(data) - pos >= 4, 'truncated index path length')
        n = struct.unpack_from('<i', data, pos)[0]
        require(1 <= n <= 500, 'invalid index path length')
        require(n <= len(data) - pos - 13, 'truncated index record')
        path = safe_path(data[pos + 4:pos + 4 + n])
        offset, size, kind = struct.unpack_from('<iiB', data, pos + 4 + n)
        require(path not in exact and path.casefold() not in folded, 'duplicate/casefold member path')
        require(offset >= 0 and size > 0, 'negative/empty member extent')
        require(offset <= body_end and size <= body_end - offset, 'member extent outside body')
        if encrypted:
            require(offset % 16 == 0 and size % 16 == 0, 'encrypted member extent not block aligned')
        exact.add(path)
        folded.add(path.casefold())
        entries.append({'path': path, 'offset': offset, 'encrypted_bytes': size, 'type': kind})
        pos += n + 13
    require(bool(entries), 'empty image/icon directory')
    ranges = sorted((r['offset'], r['offset'] + r['encrypted_bytes']) for r in entries)
    for (_, previous_end), (next_start, _) in zip(ranges, ranges[1:]):
        require(previous_end <= next_start, 'overlapping member extents')
    return entries


def png_verify(data):
    require(data.startswith(b'\x89PNG\r\n\x1a\n'), 'PNG signature mismatch')
    pos = 8
    count = 0
    ihdr = False
    idat = False
    ended = False
    while pos < len(data):
        require(len(data) - pos >= 12, 'truncated PNG chunk header/CRC')
        n = struct.unpack_from('>I', data, pos)[0]
        require(n <= 0x7fffffff and n <= len(data) - pos - 12, 'PNG chunk out of bounds')
        kind = data[pos + 4:pos + 8]
        require(all(65 <= v <= 90 or 97 <= v <= 122 for v in kind) and 65 <= kind[2] <= 90, 'invalid PNG chunk type')
        payload = data[pos + 8:pos + 8 + n]
        crc = struct.unpack_from('>I', data, pos + 8 + n)[0]
        require(zlib.crc32(kind + payload) & 0xffffffff == crc, 'PNG chunk CRC mismatch')
        if count == 0:
            require(kind == b'IHDR' and n == 13, 'PNG missing first IHDR')
        if kind == b'IHDR':
            require(not ihdr and n == 13, 'duplicate/malformed PNG IHDR')
            ihdr = True
        if kind == b'IDAT':
            idat = True
        count += 1
        pos += n + 12
        if kind == b'IEND':
            require(n == 0 and idat and pos == len(data), 'invalid PNG IEND or trailing bytes')
            ended = True
            break
    require(ended, 'PNG lacks complete IEND')
    return count


def image_verify(data):
    result = {}
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        result['png_chunk_count'] = png_verify(data)
        result['png_all_chunk_crc_verified'] = True
    with warnings.catch_warnings():
        warnings.simplefilter('error')
        with Image.open(io.BytesIO(data)) as image:
            fmt = image.format
            width, height = image.size
            mode = image.mode
            require(fmt in ('PNG', 'JPEG', 'BMP'), 'unsupported original image format')
            require(width > 0 and height > 0, 'invalid original image dimensions')
            image.verify()
        with Image.open(io.BytesIO(data)) as image:
            image.load()
            require((image.format, image.size, image.mode) == (fmt, (width, height), mode), 'image changed on full decode')
    result.update({'format': fmt, 'width': width, 'height': height, 'mode': mode, 'pillow_verify_and_load': True})
    return result


def directory(raw, filename, parameters):
    footer = read_footer(raw)
    name = filename.encode('utf8')
    require(bool(name), 'empty DAT filename')
    iv = bytes(name[i % len(name)] for i in range(16))
    key = bytes.fromhex(parameters['aes128_key_hex'])
    data = raw[footer['index_offset']:footer['index_offset'] + footer['index_bytes']]
    index_padding = 0
    if footer['encrypted']:
        data, index_padding = strict_unpad(decrypt(data, key, iv))
    entries = parse_index(data, footer['index_offset'], footer['encrypted'])
    footer.update({'index_pkcs7_padding_verified': footer['encrypted'], 'index_padding_bytes': index_padding,
                   'index_plain_bytes': len(data), 'index_plain_sha256': sha256(data), 'entry_count': len(entries),
                   'index_exactly_consumed': True, 'member_type_counts': dict(collections.Counter(str(x['type']) for x in entries)),
                   'member_stored_bytes_sum': sum(x['encrypted_bytes'] for x in entries),
                   'body_unreferenced_bytes': footer['index_offset'] - sum(x['encrypted_bytes'] for x in entries)})
    return footer, entries, key, iv


def check_expected(entries, expected):
    require(len(entries) == len({r['path'] for r in entries}) == len({r['path'].casefold() for r in entries}), 'duplicate/casefold expected member records')
    require({r['path'] for r in entries} == set(expected), 'retained catalog member set mismatch')
    for row in entries:
        require(row['encrypted_bytes'] == expected[row['path']]['encrypted_bytes'], 'retained catalog stored-byte mismatch')


def validation_context(parameters, expected):
    """Bind resume to the exact private parameters and retained expectations."""
    canonical = lambda value: json.dumps(value, sort_keys=True, separators=(',', ':')).encode()
    return {'validation_contract': 'strict-dat-original-image-v1',
            'parameter_digest': sha256(canonical(parameters)),
            'expected_retained_catalog_digest': sha256(canonical(expected)) if expected is not None else None}


def validate_resume(summary, records, records_bytes, input_bytes, identity, parameters, expected, output_root):
    require(summary.get('validation_context') == validation_context(parameters, expected), 'resume validation context mismatch')
    require(bool(re.fullmatch('[0-9a-f]{64}', summary.get('extraction_decoder_sha256', ''))), 'missing extraction decoder identity')
    require(summary.get('identity_basis') == identity, 'resume expected container identity mismatch')
    require(summary.get('records_sha256') == sha256(records_bytes), 'resume record-file hash mismatch')
    require(sha256(input_bytes) == summary['sha256'] == identity['sha256'], 'resume original identity mismatch')
    require(len(records) == summary['verified_images'], 'resume record count mismatch')
    require(len(records) == len({r['path'] for r in records}) == len({r['path'].casefold() for r in records}), 'resume duplicate/casefold member records')
    if expected is not None:
        check_expected(records, expected)
    for row in records:
        safe_path(row['path'].encode('utf8'))
        require(row['relative_output_path'] == 'decoded/' + row['path'], 'resume output path mismatch')
        require(row['container'] == summary['container'] and row['original_container_sha256'] == summary['sha256'], 'resume member container identity mismatch')
        require(isinstance(summary.get('encrypted'), bool), 'resume encryption mode proof missing')
        require(row['pkcs7_padding_verified'] == summary['encrypted'] and row['pillow_verify_and_load'] and row['original_bytes_preserved'], 'resume strict validation proof missing')
        if row['format'] == 'PNG':
            require(row.get('png_all_chunk_crc_verified'), 'resume PNG CRC proof missing')
        if expected is not None:
            for field in ('plain_bytes', 'sha256', 'format', 'width', 'height', 'mode', 'png_chunk_count'):
                if field in expected[row['path']]:
                    require(row.get(field) == expected[row['path']][field], 'resume retained ' + field + ' mismatch')
        output = output_destination(output_root / 'decoded', row['path'])
        require(output.is_file() and sha256(output.read_bytes()) == row['sha256'], 'resume output hash mismatch')


def output_destination(decoded_root, logical_path):
    safe_path(logical_path.encode('utf8'))
    require(not decoded_root.is_symlink(), 'decoded output root is a symlink')
    destination = decoded_root / logical_path
    current = decoded_root
    for component in logical_path.split('/'):
        current = current / component
        require(not current.is_symlink(), 'symlink in decoded output path')
    require(destination.resolve().is_relative_to(decoded_root.resolve()), 'decoded output escapes root')
    return destination


def json_write(path, value):
    tmp = path.with_suffix(path.suffix + '.part')
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    tmp.replace(path)


def process_container(input_path, output_root, parameters, identity, expected=None, lineage=None):
    container = 'Client/Data/' + input_path.name
    raw = input_path.read_bytes()
    original_sha = sha256(raw)
    require(original_sha == identity['sha256'], 'original container SHA256 mismatch')
    if 'bytes' in identity:
        require(len(raw) == identity['bytes'], 'original container size mismatch')
    if 'sha1' in identity:
        require(hashlib.sha1(raw).hexdigest() == identity['sha1'], 'original container SHA1 mismatch')
    footer, entries, key, iv = directory(raw, input_path.name, parameters)
    if expected is not None:
        check_expected(entries, expected)
    stage = Path(tempfile.mkdtemp(prefix=input_path.name + '-', dir=output_root / 'staging'))
    rows = []
    failures = []
    for row in entries:
        try:
            cipher = raw[row['offset']:row['offset'] + row['encrypted_bytes']]
            plain = cipher
            padding = 0
            if footer['encrypted']:
                plain, padding = strict_unpad(decrypt(cipher, key, iv))
            verified = image_verify(plain)
            rec = {**row, 'container': container, 'original_container_sha256': original_sha,
                   'original_container_bytes': len(raw), 'stored_member_sha256': sha256(cipher),
                   'plain_bytes': len(plain), 'sha256': sha256(plain), 'pkcs7_padding_verified': footer['encrypted'],
                   'padding_bytes': padding, **verified, 'original_bytes_preserved': True,
                   'relative_output_path': 'decoded/' + row['path'],
                   'current523_alignment': identity['current523_alignment'],
                   'retained_prior_catalog_all_fields_verified': expected is not None,
                   'actual_game_consumption_observed': False}
            if lineage is not None and row['path'] in lineage:
                rec['historical_card_pack_lineage'] = lineage[row['path']]['historical_card_pack_lineage']
                rec['item_declaration_join_only'] = lineage[row['path']]['item_declaration_join_only']
            if expected is not None:
                for field in ('plain_bytes', 'sha256', 'format', 'width', 'height', 'mode', 'png_chunk_count'):
                    if field in expected[row['path']]:
                        require(rec.get(field) == expected[row['path']][field], 'retained catalog ' + field + ' mismatch')
            dest = stage / row['path']
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(plain)
            rows.append(rec)
        except Exception as exc:
            failures.append({'container': container, 'path': row['path'], 'stage': 'member_validation',
                             'error_type': type(exc).__name__, 'error': str(exc)})
    if failures:
        shutil.rmtree(stage)
        return None, [], failures
    # Recheck preserved encrypted input identity after extraction.
    require(sha256(input_path.read_bytes()) == original_sha, 'original input changed during validation')
    decoded = output_root / 'decoded'
    existing_folded = {str(p.relative_to(decoded)).casefold() for p in decoded.rglob('*') if p.is_file()}
    for rec in rows:
        dest = output_destination(decoded, rec['path'])
        require(not dest.exists() and rec['path'].casefold() not in existing_folded, 'duplicate/casefold output path across current originals')
    for rec in rows:
        dest = output_destination(decoded, rec['path'])
        dest.parent.mkdir(parents=True, exist_ok=True)
        (stage / rec['path']).replace(dest)
    shutil.rmtree(stage)
    summary = {'container': container, 'input_path': str(input_path), 'bytes': len(raw), 'sha256': original_sha,
               'sha1': hashlib.sha1(raw).hexdigest(), 'crc32': f'{zlib.crc32(raw) & 0xffffffff:08x}',
               'original_container_identity_verified': True, 'identity_basis': identity,
               **footer, 'verified_images': len(rows), 'errors': 0,
               'plain_file_bytes_sum': sum(r['plain_bytes'] for r in rows),
               'format_counts': dict(collections.Counter(r['format'] for r in rows)),
               'retained_catalog_all_expected_members_verified': expected is not None,
               'validation_context': validation_context(parameters, expected),
               'extraction_decoder_sha256': sha256(Path(__file__).read_bytes()),
               'actual_game_consumption_observed': False}
    return summary, rows, []


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--params', type=Path, required=True)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--catalog', type=Path, required=True)
    parser.add_argument('--lineage', type=Path, required=True)
    args = parser.parse_args()
    params = json.loads(args.params.read_text())
    plan = json.loads(args.plan.read_text())
    all_expected = collections.defaultdict(dict)
    with gzip.open(args.catalog, 'rt') as stream:
        for line in stream:
            row = json.loads(line)
            all_expected[row['container']][row['path']] = row
    lineage = {}
    with gzip.open(args.lineage, 'rt') as stream:
        for line in stream:
            row = json.loads(line)
            lineage[row['path']] = row
    for name in ('staging', 'records', 'containers', 'failures', 'decoded'):
        (args.output / name).mkdir(parents=True, exist_ok=True)
    summaries = []
    failures = []
    reused = 0
    for item in plan:
        path = Path(item['path'])
        summary_path = args.output / 'containers' / (path.name + '.json')
        records_path = args.output / 'records' / (path.name + '.jsonl')
        try:
            expected = all_expected[item['container']] if item['retained'] else None
            if summary_path.exists():
                prior = json.loads(summary_path.read_text())
                records_bytes = records_path.read_bytes()
                prior_rows = [json.loads(x) for x in records_bytes.splitlines()]
                validate_resume(prior, prior_rows, records_bytes, path.read_bytes(), item['identity'], params, expected, args.output)
                summaries.append(prior)
                reused += 1
                print(json.dumps({'container': item['container'], 'status': 'reused_verified_output', 'members': prior['verified_images']}), flush=True)
                continue
            summary, rows, errors = process_container(path, args.output, params, item['identity'], expected, lineage)
            if errors:
                json_write(args.output / 'failures' / (path.name + '.json'), errors)
                failures.extend(errors)
                print(json.dumps({'container': item['container'], 'status': 'failed', 'errors': len(errors)}), flush=True)
                continue
            records_path.write_text(''.join(json.dumps(x, ensure_ascii=False, separators=(',', ':')) + '\n' for x in rows))
            summary['records_sha256'] = sha256(records_path.read_bytes())
            json_write(summary_path, summary)
            summaries.append(summary)
            print(json.dumps({'container': item['container'], 'status': 'verified', 'members': len(rows)}), flush=True)
        except Exception as exc:
            error = {'container': item['container'], 'stage': 'container_validation', 'error_type': type(exc).__name__, 'error': str(exc)}
            json_write(args.output / 'failures' / (path.name + '.json'), [error])
            failures.append(error)
            print(json.dumps({'container': item['container'], 'status': 'failed', 'error': str(exc)}), flush=True)
    summary = {'as_of_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'plan_containers': len(plan),
               'verified_containers': len(summaries), 'verified_images': sum(x['verified_images'] for x in summaries),
               'strict_failure_count': len(failures), 'failures': failures, 'reused_previously_verified_containers': reused,
               'member_stored_bytes': sum(x['member_stored_bytes_sum'] for x in summaries),
               'plain_file_bytes': sum(x['plain_file_bytes_sum'] for x in summaries),
               'source_provenance': params['source_provenance'], 'decoder_sha256': sha256(Path(__file__).read_bytes()),
               'actual_game_consumption_newly_observed': 0, 'overall_actual_game_use': None,
               'qualifications': ['Independent original bytes and full image decoding verification; no actual game-consumption proof.',
                                  'No image fixture generation, no transcoding, no fallback assets, no upstream executable execution.']}
    json_write(args.output / 'run-summary.json', summary)
    print(json.dumps({'verified_containers': summary['verified_containers'], 'verified_images': summary['verified_images'],
                      'strict_failure_count': len(failures)}), flush=True)
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
