"""CRC-test an ARM64 APK and verify every reviewed PNG byte record survives export."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--apk', type=Path, required=True)
parser.add_argument('--bindings', type=Path, required=True)
args = parser.parse_args()
manifest = json.loads(args.bindings.read_text(encoding='utf-8'))
digests = set()
for section in ('items', 'monsters'):
    for row in manifest[section]:
        for key in (('inventory_sha256', 'ground_sha256') if section == 'items' else ('sha256',)):
            digests.add(row[key])
with zipfile.ZipFile(args.apk) as apk:
    names = set(apk.namelist())
    if 'lib/arm64-v8a/libgodot_android.so' not in names:
        raise ValueError('Missing ARM64 Godot native library')
    bad = apk.testzip()
    if bad:
        raise ValueError('APK CRC failure: ' + bad)
    for sha in digests:
        candidates = [n for n in names if n.endswith('/verified_bytes/' + sha + '.l1jpng')]
        if len(candidates) != 1 or hashlib.sha256(apk.read(candidates[0])).hexdigest() != sha:
            raise ValueError('Verified source-byte record missing/changed: ' + sha)
print(json.dumps({'apk_crc': 'PASS', 'architecture': 'arm64-v8a', 'verified_byte_records': len(digests),
                  'synthetic_fixture_only': bool(manifest.get('synthetic_fixture_only', False)),
                  'device_execution': 'NOT_TESTED'}))
