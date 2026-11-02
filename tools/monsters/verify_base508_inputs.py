"""Verify a targeted original SP2 package without publishing or creating art."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import zipfile
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lineagem_original'))
import original_sp2


def verify(requests, package, destination):
    requested = json.loads(requests.read_text())
    selected = [row for row in requested['files']
                if row.get('available_library_package', {}).get('file_name') == package.name]
    if not selected: raise ValueError('No requested inputs for this package')
    expected = selected[0]['available_library_package']
    raw = package.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if len(raw) != expected['bytes'] or digest != expected['sha256']:
        raise ValueError('Library package size or SHA-256 mismatch')
    files = []
    with zipfile.ZipFile(package) as archive:
        failure = archive.testzip()
        if failure is not None: raise ValueError(('ZIP CRC mismatch', failure))
        for row in selected:
            name = row['name']
            relative = Path(name)
            if relative.is_absolute() or '..' in relative.parts: raise ValueError('Unsafe original member path')
            data = archive.read(name)
            if len(data) != row['size'] or f'{zlib.crc32(data):08x}' != row['crc32']:
                raise ValueError(('Original member mismatch', name))
            palette, mask, directions, consumed = original_sp2.parse(data)
            frame_count = 0
            for frames, blocks in directions:
                for index in range(len(frames)):
                    # Decode every stored original frame at its own original offset;
                    # no merged body/clothing, image generation, resampling or FPS.
                    image, offset = original_sp2.render(palette, frames, blocks, index)
                    image.close()
                    frame_count += 1
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            files.append({**{field: row[field] for field in ('archive', 'name', 'size', 'crc32')},
                          'sha256': hashlib.sha256(data).hexdigest(), 'stored_direction_mask': mask,
                          'decoded_stored_frames': frame_count})
    return {'schema': 1, 'source_snapshot': 'base508',
            'source_library_package': expected, 'verified_package_sha256': digest,
            'original_files_verified': len(files), 'original_bytes_verified': sum(row['size'] for row in files),
            'stored_frames_decoded': sum(row['decoded_stored_frames'] for row in files),
            'files': files,
            'original_pixels_published': False, 'game_runtime_replacements': 0,
            'status': 'original_inputs_verified_only; not an installed monster pack or world replacement'}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['requests', 'package', 'destination', 'report']:
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    result = verify(args.requests, args.package, args.destination)
    args.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({key: value for key, value in result.items() if key != 'files'}))
