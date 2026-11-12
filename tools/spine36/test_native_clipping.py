#!/usr/bin/env python3
"""Exercise the external sampler's native SDK clipper using unchanged source art.

Only synthetic skeleton JSON and private numeric evidence are written. The exact
manifest-bound Knight Male atlas and PNG pages are read in place; no image is
created, copied, edited or rendered. This is geometry verification, not GPU or
original-client rendering acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile

SDK_GIT = '654c20e5b0e523040b6366bbd1042510d2645134'
KNIGHT_MEMBER = 'UI/Spine/Spine_Knight_Male.json'
REGION = 'Hair_Front'
EPSILON = 0.000001


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def source_file(pack: Path, manifest: dict, member: str) -> Path:
    name = PurePosixPath(member)
    require(not name.is_absolute() and '..' not in name.parts and '\\' not in member,
            'unsafe original member')
    path = pack / 'originals' / member
    require(path.resolve().is_relative_to((pack / 'originals').resolve()), 'original member escape')
    meta = manifest['files'][member]
    require(path.is_file() and path.stat().st_size == meta['bytes'] and sha(path) == meta['sha256'],
            'original byte mismatch: ' + member)
    return path


def fixture(mode: str) -> dict:
    quad = {'path': REGION, 'width': 2, 'height': 2}
    clipped = dict(quad)
    if mode == 'fully_outside':
        clipped['x'] = 10
    end = {'name': 'end', 'bone': 'root'}
    skin = {
        'clip': {'mask': {'type': 'clipping', 'end': 'end', 'vertexCount': 4,
                          'vertices': [-0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 0.5, -0.5]}},
        'clipped': {'quad': clipped},
        'after': {'quad': dict(quad)},
    }
    if mode == 'transparent_end':
        end.update({'attachment': 'quad', 'color': 'ffffff00'})
        skin['end'] = {'quad': dict(quad)}
    return {
        # This pinned 3.6 reader copies the hash without a NULL guard.
        'skeleton': {'hash': 'native_clipping_fixture_' + mode, 'spine': '3.6.52'},
        'bones': [{'name': 'root'}],
        'slots': [{'name': 'clip', 'bone': 'root', 'attachment': 'mask'},
                  {'name': 'clipped', 'bone': 'root', 'attachment': 'quad'},
                  end, {'name': 'after', 'bone': 'root', 'attachment': 'quad'}],
        'skins': {'default': skin},
        'animations': {'idle': {}},
    }


def area(batch: dict) -> float:
    points, indices = batch['positions'], batch['indices']
    result = 0.0
    for i in range(0, len(indices), 3):
        a, b, c = [2 * n for n in indices[i:i + 3]]
        result += abs((points[b] - points[a]) * (points[c + 1] - points[a + 1])
                      - (points[b + 1] - points[a + 1]) * (points[c] - points[a])) / 2
    return result


def check_batch(batch: dict, page_names: set[str]) -> None:
    positions, uvs, indices = batch['positions'], batch['uvs'], batch['indices']
    require(batch['page'] in page_names, 'non-original texture page')
    require(len(positions) >= 6 and len(positions) % 2 == 0 and len(positions) == len(uvs),
            'invalid clipped coordinate lengths')
    require(indices and len(indices) % 3 == 0, 'invalid clipped triangle length')
    require(all(type(i) is int and 0 <= i < len(positions) // 2 for i in indices),
            'clipped index outside vertex array')
    require(all(type(v) in (int, float) and math.isfinite(v) for v in positions + uvs),
            'nonfinite clipped coordinate')
    require(all(-EPSILON <= value <= 1 + EPSILON for value in uvs), 'UV outside original page')


def uv_error(clipped: dict, reference: dict) -> float:
    """Compare every clipped UV with the uncut quad's affine texture mapping.

    This derives the map from SDK output, so atlas rotation/trim conventions do
    not get reimplemented or assumed by the fixture.
    """
    ps, uv, ids = reference['positions'], reference['uvs'], reference['indices']
    a, b, c = [2 * n for n in ids[:3]]
    dx1, dy1 = ps[b] - ps[a], ps[b + 1] - ps[a + 1]
    dx2, dy2 = ps[c] - ps[a], ps[c + 1] - ps[a + 1]
    determinant = dx1 * dy2 - dy1 * dx2
    require(abs(determinant) > EPSILON, 'degenerate reference triangle')
    worst = 0.0
    for i in range(0, len(clipped['positions']), 2):
        dx = clipped['positions'][i] - ps[a]
        dy = clipped['positions'][i + 1] - ps[a + 1]
        t = (dx * dy2 - dy * dx2) / determinant
        u = (dx1 * dy - dy1 * dx) / determinant
        for component in (0, 1):
            expected = uv[a + component] + t * (uv[b + component] - uv[a + component])
            expected += u * (uv[c + component] - uv[a + component])
            worst = max(worst, abs(clipped['uvs'][i + component] - expected))
    return worst


def verify_pose(pose: dict, mode: str, page_names: set[str]) -> dict:
    batches = pose['batches']
    expected = ['after'] if mode == 'fully_outside' else ['clipped', 'after']
    require([b['slot'] for b in batches] == expected, 'unexpected clipping/end-slot draw order')
    for batch in batches:
        check_batch(batch, page_names)
    after = batches[-1]
    after_area = area(after)
    require(abs(after_area - 4) <= EPSILON, 'clip failed to end at empty/transparent end slot')
    report = {'batch_slots': expected, 'after_area': after_area,
              'after_triangles': len(after['indices']) // 3}
    if mode != 'fully_outside':
        clipped = batches[0]
        clipped_area = area(clipped)
        require(abs(clipped_area - 1) <= EPSILON, 'native clipper produced incorrect covered area')
        require(all(-0.5 - EPSILON <= x <= 0.5 + EPSILON for x in clipped['positions']),
                'native clipped vertex outside square')
        error = uv_error(clipped, after)
        require(error <= EPSILON, 'native clipper UV interpolation differs from source quad')
        report.update({'clipped_area': clipped_area, 'clipped_vertices': len(clipped['positions']) // 2,
                       'clipped_triangles': len(clipped['indices']) // 3, 'max_uv_affine_error': error})
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pack', type=Path, required=True)
    parser.add_argument('--manifest-sha256', required=True)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--build-proof', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        pack, output, binary = args.pack.resolve(), args.output.resolve(), args.binary.resolve()
        require(not output.is_relative_to(pack), 'fixture output must preserve original pack')
        manifest_path = pack / 'original_ui.json'
        require(sha(manifest_path) == args.manifest_sha256, 'manifest pin mismatch')
        manifest = json.loads(manifest_path.read_text())
        before = {name: sha(source_file(pack, manifest, name)) for name in manifest['files']}
        binary_sha = sha(binary)
        proof = json.loads(args.build_proof.read_text())
        build = proof['build']
        require(build['sdk_git'] == SDK_GIT and build['binary_sha256'] == binary_sha,
                'native binary does not match pinned build proof')
        license_file = binary.parent / 'SPINE_RUNTIME_LICENSE.txt'
        require(sha(license_file) == build['sdk_license_sha256'], 'SDK license notice mismatch')
        atlas_member = manifest['lobby_spines'][KNIGHT_MEMBER]['atlas']
        require(atlas_member == 'UI/Spine/Spine_Knight_Male.atlas', 'unexpected explicit atlas binding')
        atlas = source_file(pack, manifest, atlas_member)
        # The 3.6 atlas separates each page with a blank line. Its header gives
        # the PNG path; region names are the other unindented non-field lines.
        pages, regions, page = set(), set(), None
        for line in atlas.read_text().splitlines():
            value = line.strip()
            if not value:
                page = None
            elif page is None:
                page = str(PurePosixPath(atlas_member).parent / value)
                source_file(pack, manifest, page)
                pages.add(page)
            elif not line[0].isspace() and ':' not in value:
                regions.add(value)
        require(REGION in regions, 'fixture source region absent')
        output.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(license_file, output / 'SPINE_RUNTIME_LICENSE.txt')
        cases = []
        with tempfile.TemporaryDirectory(prefix='native-clip-', dir=output) as directory:
            temporary = Path(directory)
            for mode in ['empty_end', 'transparent_end', 'fully_outside']:
                source = temporary / (mode + '.json')
                source.write_text(json.dumps(fixture(mode), separators=(',', ':')))
                result = subprocess.run([str(binary), '--json', str(source), '--atlas', str(atlas),
                                         '--page-prefix', str(PurePosixPath(atlas_member).parent) + '/',
                                         '--fps', '60'], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                        text=True, timeout=30)
                if result.returncode != 0:
                    (output / (mode + '.failed-fixture.json')).write_text(source.read_text())
                    (output / (mode + '.failed-sdk.log')).write_text(result.stderr)
                    raise ValueError('native clipping fixture failed (' + mode + ', code '
                                     + str(result.returncode) + '): ' + result.stderr)
                data = json.loads(result.stdout)
                require(data['source']['spine_version'] == '3.6.52' and data['coordinate_space'] == 'godot_y_down',
                        'unexpected native sampler envelope')
                require(set(data['clips']) == {'idle'} and data['clips']['idle']['duration'] == 0,
                        'fixture clip changed')
                frames = data['clips']['idle']['frames']
                require(len(frames) == 1 and frames[0]['time'] == 0, 'zero-duration sampling changed')
                setup = verify_pose(data['setup'], mode, pages)
                sampled = verify_pose(frames[0], mode, pages)
                require(setup == sampled, 'clipper state leaked between setup and sampled pose')
                cases.append({'mode': mode, 'fixture_sha256': sha(source), 'setup': setup,
                              'sampled': sampled, 'sdk_log': result.stderr.strip()})
                for suffix in ['.failed-fixture.json', '.failed-sdk.log']:
                    (output / (mode + suffix)).unlink(missing_ok=True)
        require(sha(binary) == binary_sha, 'sampler binary changed during native fixture execution')
        require(sha(manifest_path) == args.manifest_sha256 and
                all(sha(pack / 'originals' / name) == value for name, value in before.items()),
                'original sources changed during fixture execution')
        report = {'schema': 'twilight.spine36.native-clipping-verification.v1', 'ok': True,
                  'binary_sha256': binary_sha, 'build': build,
                  'manifest_sha256': args.manifest_sha256, 'atlas': atlas_member,
                  'atlas_sha256': sha(atlas), 'original_files': len(before),
                  'originals_unchanged': True, 'source_manifest_unchanged': True,
                  'source_region': REGION, 'cases': cases,
                  'scope': 'actual external SDK clipping, area, finite/index/UV interpolation, empty/transparent end-slot and zero-duration pose reset; no image/GPU/original-client acceptance'}
        target = output / 'native-clipping-report.json'
        target.write_text(json.dumps(report, indent=2, ensure_ascii=True, allow_nan=False) + '\n')
        print(json.dumps({'ok': True, 'cases': len(cases), 'report': str(target), 'originals_unchanged': True}))
        return 0
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print('SPINE36_NATIVE_CLIPPING_ERROR ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
