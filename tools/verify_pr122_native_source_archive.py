#!/usr/bin/env python3
"""Cross-check private A2002 SPX bytes/RGBA against the existing source kit.

Reads sprites as data only. A verified record is not an identity, source license,
or final visual approval. No source image is written to the public checkout.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import sys
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent / 'l1j'))
from spx_decode import decode_spx

ARCHIVE_SHA = 'd5438f74b486e42481ad34badb527794bbda10a591388c2177e580f2af8c34d7'
PATCH_SHA = '7ffef58d56fcbb162897dcf846633f1dd12b97851d0e0894ad7c510656fbc7d0'
AUDIT_SHA = '660d90d0695bfb0b03e16940ad492fee6b25d588b720566945e3c30ec4cc0431'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--source-kit', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    assert not args.archive.resolve().is_relative_to(root)
    assert not args.source_kit.resolve().is_relative_to(root)
    assert not args.output.resolve().is_relative_to(root)
    source = args.archive.read_bytes()
    assert len(source) == 150480291 and digest(source) == ARCHIVE_SHA
    audit_bytes = (args.source_kit / 'audit/frame_metadata.json').read_bytes()
    assert digest(audit_bytes) == AUDIT_SHA
    audit = {Path(entry['path']).name: entry for entry in json.loads(audit_bytes)
             if entry['path'].startswith('spx/')}
    assert len(audit) == 1700
    with zipfile.ZipFile(io.BytesIO(source)) as outer:
        assert outer.testzip() is None, 'Outer ZIP CRC failed'
        patch = outer.read('connector/patch/patch_1.zip')
    assert digest(patch) == PATCH_SHA
    groups = {}
    total = empty = visible = 0
    with zipfile.ZipFile(io.BytesIO(patch)) as archive:
        assert archive.testzip() is None, 'Patch CRC failed'
        names = [name for name in archive.namelist() if name.endswith('.spx')]
        assert len(names) == 1700 and len({Path(name).name for name in names}) == 1700
        assert {Path(name).name for name in names} == set(audit)
        for index, name in enumerate(sorted(names)):
            raw = archive.read(name)
            expected = audit[Path(name).name]
            assert digest(raw) == expected['source_sha256'], name
            decoded = decode_spx(raw)
            assert len(decoded) == len(expected['frames'])
            group = Path(name).stem.split('-')[0]
            record = groups.setdefault(group, {'files': 0, 'records': 0, 'nonempty': 0, 'empty': 0})
            record['files'] += 1
            for (meta, image), original in zip(decoded, expected['frames']):
                assert meta['index'] == original['index'] and meta['empty'] == original['empty']
                assert meta['xy_offset'] == original['xy_offset'] and meta['size'] == original['size']
                total += 1
                record['records'] += 1
                if image is None:
                    empty += 1
                    record['empty'] += 1
                else:
                    assert digest(image.tobytes()) == original['rgba_sha256'], name + '/' + str(meta['index'])
                    visible += 1
                    record['nonempty'] += 1
            if (index + 1) % 400 == 0:
                print('NATIVE_ARCHIVE_VERIFIED ' + str(index + 1) + '/1700', flush=True)
    result = {'archive': 'a2002.zip', 'bytes': len(source), 'archive_SHA256': ARCHIVE_SHA,
              'patch_member': 'connector/patch/patch_1.zip', 'patch_SHA256': PATCH_SHA,
              'ZIP_CRC': 'PASS', 'source_SPX_files': len(audit), 'native_frame_records': total,
              'RGBA_SHA256_matched_nonempty': visible, 'preserved_empty_records': empty,
              'native_offsets_and_sizes': 'PASS', 'groups': groups,
              'complete_body_IDs': ['21624', '21653'],
              'not_separate_species': {'shadow': ['21625', '21654'], 'clothes': ['21626', '21627', '21655', '21656']},
              'blend_semantics': 'HOLD: retain source type flags; do not assume every clothes layer is additive',
              'target_identity': 'UNMAPPED', 'public_originals_uploaded': False,
              'all498_originals_available': False, 'completed_added': 0}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x') as stream:
        stream.write(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: value for key, value in result.items() if key != 'groups'}), flush=True)


if __name__ == '__main__':
    main()
