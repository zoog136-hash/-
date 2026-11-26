"""Derive name-balance identity bits from the pinned installed 523 tables.

A set bit means that only this non-test ItemClass uses its original display
name as either Korean descriptor. The result contains no names or game assets.
"""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
OUTPUT = Path(__file__).resolve().parents[1] / "data/current523_unique_stock_ids.bin"
STRIP_EDGES = ''.join(map(chr, range(33)))  # Godot String.strip_edges()


def build(archive: Path) -> bytes:
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise ValueError('unexpected original archive SHA-256')
    with ZipFile(archive) as source:
        descriptions = json.loads(source.read('content/DescData_Korean.json'))['rows']
        items = json.loads(source.read('content/ItemClass.json'))['rows']
    labels = {row['ID']: row['Description'].strip(STRIP_EDGES) for row in descriptions}
    owners = {}
    displayed = {}
    for row in items:
        if row['TestItem'] is not False:
            continue
        item_id = row['ID']
        normal, identified = (labels.get(row[field], '') if row[field] > 0 else ''
                              for field in ('DescID', 'IdentifiedDescID'))
        displayed[item_id] = identified or normal
        for name in {normal, identified} - {''}:
            owners[name] = item_id if owners.get(name, item_id) == item_id else -1
    bits = bytearray(max(displayed) // 8 + 1)
    for item_id, name in displayed.items():
        if owners.get(name) == item_id:
            bits[item_id // 8] |= 1 << (item_id % 8)
    return bytes(bits)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    derived = build(args.archive)
    if args.check:
        if derived != OUTPUT.read_bytes():
            raise SystemExit('committed stock-name identities differ from the original archive')
    else:
        OUTPUT.write_bytes(derived)
    print(f'{sum(value.bit_count() for value in derived)} unique IDs, {len(derived)} bytes, '
          f'SHA-256 {hashlib.sha256(derived).hexdigest()}')
