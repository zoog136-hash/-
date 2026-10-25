#!/usr/bin/env python3
"""Preserve every private full-matrix Main PNG byte in SHA-verified chunks.

Archives validated source-only previews, never grants a target approval. Requires
the actual full eight-direction/nine-role/three-speed run, not a partial pilot.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

import zstandard


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for data in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(data)
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    preview, output = args.preview.resolve(), args.output_dir.resolve()
    assert not preview.is_relative_to(root) and not output.is_relative_to(root)
    report = json.loads((preview / 'report.json').read_text())
    fixture = json.loads((preview / 'private-preview.json').read_text())
    process = json.loads((preview / 'process-result.json').read_text())
    assert not report['failures'] and process['returncode'] == 0
    assert fixture['directions'] == list(range(8)) and not fixture['public_artifacts_allowed']
    assert not fixture['production_applied'] and fixture['completed_added'] == 0
    paths = {}
    for actor_id, result in report['actors'].items():
        assert len(fixture['actors'][actor_id]['tracks']) == 72 and len(result['tracks']) == 216
        assert len(result['actual_input']['directions']) == 8
        captures = [capture for trial in result['tracks'] for capture in trial['captures']]
        captures += [entry['capture'] for entry in result['actual_input']['directions']]
        for capture in captures:
            path = Path(capture['path']).resolve()
            assert path.is_relative_to(preview) and path.is_file()
            assert digest(path) == capture['sha256']
            name = path.relative_to(preview).as_posix()
            assert name not in paths
            paths[name] = {'bytes': path.stat().st_size, 'sha256': capture['sha256']}
    assert set(paths) == {path.relative_to(preview).as_posix() for path in (preview / 'captures').glob('*.png')}
    pngs = len(paths)
    for name in ('report.json', 'private-preview.json', 'process-result.json', 'process.log'):
        path = preview / name
        paths[name] = {'bytes': path.stat().st_size, 'sha256': digest(path)}
    output.mkdir(parents=True, exist_ok=False)
    archive = output / 'full-Main-byte-exact.tar.zst'
    with subprocess.Popen(['zstd', '-T2', '-3', '--long=27', '--check', '-o', str(archive)],
                          stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE) as encoder:
        with tarfile.open(fileobj=encoder.stdin, mode='w|') as tar:
            for name in sorted(paths):
                tar.add(preview / name, arcname=name, recursive=False)
        encoder.stdin.close()
        assert encoder.wait() == 0
    checked = set()
    with archive.open('rb') as stream:
        with zstandard.ZstdDecompressor(max_window_size=128 * 1024 * 1024).stream_reader(stream) as reader:
            with tarfile.open(fileobj=reader, mode='r|') as tar:
                for member in tar:
                    assert member.isfile() and member.name in paths and member.name not in checked
                    data = tar.extractfile(member).read()
                    item = paths[member.name]
                    assert len(data) == item['bytes'] and hashlib.sha256(data).hexdigest() == item['sha256']
                    checked.add(member.name)
            # Consume the frame trailer too, so the zstd checksum is verified.
            for tail in iter(lambda: reader.read(1024 * 1024), b''):
                assert not tail.strip(b'\0'), 'Unexpected non-padding bytes after tar'
    assert checked == set(paths)
    parts = []
    with archive.open('rb') as stream:
        while True:
            data = stream.read(28 * 1024 * 1024)
            if not data:
                break
            path = output / ('full-Main-byte-exact.tar.zst.part' + f'{len(parts) + 1:03}')
            with path.open('xb') as writer:
                writer.write(data)
            parts.append({'file': path.name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
    receipt = {'schema': 1, 'archive': archive.name, 'archive_bytes': archive.stat().st_size,
               'archive_sha256': digest(archive), 'parts': parts, 'files': paths,
               'Main_PNG_bodies': pngs, 'every_member_bytes_and_SHA_verified': True,
               'zstd_frame_checksum_verified': True, 'source_kit_sha256': fixture['source_kit_sha256'],
               'prototype_only': True, 'target_identity': 'UNMAPPED', 'completed_added': 0,
               'public_artifacts_allowed': False, 'Android_real_device': 'NOT_RUN',
               'restore': 'Concatenate parts in numeric order; verify whole archive SHA; zstd -d and tar extract in a private directory. Never extract to public Git.'}
    (output / 'private-delivery-manifest.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({key: value for key, value in receipt.items() if key not in ('files', 'parts')}))
    print('PRIVATE_MAIN_ARCHIVE_PARTS ' + str(len(parts)))


if __name__ == '__main__':
    main()
