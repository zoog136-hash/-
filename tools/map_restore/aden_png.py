"""Survey Aden.png against the immutable Aden source; build reviewed LOCAL packs.

No image colour becomes collision. Neither operation edits gameplay/source data.
Third-party PNGs, crops and overlays belong outside the public checkout.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile
import zlib

import numpy as np
from PIL import Image, ImageChops, ImageDraw

from formats import read_s32, write_s32

ROOT = Path(__file__).resolve().parents[2]
PNG_SHA = '9ce95ca285f9bee72bab355c5015779122dd354fd26e73d9664a355bf9c86be3'
GRID_SHA = 'c22aa61ed083a3680230c659202503d7afaef30cb41b86d4655e9f843c81a7c4'
ARCHIVE_SHA = '2d25c6d5408aaf29443167c4c82c30b32d1a83b16039d988471ba0c832eb7d20'
Image.MAX_IMAGE_PIXELS = 160_000_000


def sha(path):
    with Path(path).open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def write(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')


def world(source):
    x, y = np.asarray(source, dtype=float) - [32448, 32064]
    return np.array([24*(x+y), 12*(-x+y)+24576])


def fit(anchors):
    """World-to-image least squares; residuals also reported in world pixels."""
    a = np.array([world(row['source']) for row in anchors])
    b = np.array([row['image'] for row in anchors], dtype=float)
    design = np.column_stack((a, np.ones(len(a))))
    if len(a) < 3 or np.linalg.matrix_rank(design) != 3:
        raise ValueError('At least three noncollinear source control points required')
    matrix = np.linalg.lstsq(design, b, rcond=None)[0].T
    if abs(np.linalg.det(matrix[:, :2])) < 1e-8:
        raise ValueError('Singular fit')
    error = design @ matrix.T-b
    world_error = error @ np.linalg.inv(matrix[:, :2]).T
    result = []
    for i, row in enumerate(anchors):
        result.append(dict(row, world=a[i].tolist(), residual_png=float(np.linalg.norm(error[i])),
                           residual_world=float(np.linalg.norm(world_error[i]))))
    return dict(world_to_image=matrix.ravel().tolist(), control_points=result,
                rms_png=float(np.sqrt(np.mean(np.sum(error**2, axis=1)))),
                max_world=float(np.max(np.linalg.norm(world_error, axis=1))),
                singular_values=np.linalg.svd(matrix[:, :2])[1].tolist())


def navigation():
    base = ROOT/'data/map_remake/private/aden'
    definition = base/'definitions/aden_world.json'
    value = json.loads(definition.read_text())
    packed = (base/'navigation-00.bin').read_bytes()
    raw_grid = np.zeros((1536, 2048), np.uint8)
    masks = raw_grid.copy()
    for x, y, w, h, shard, at, count, digest in value['navigation']['chunks']:
        assert shard == 0
        raw = zlib.decompress(packed[at:at+count])
        assert hashlib.sha256(raw).hexdigest() == digest
        raw_grid[y*64:y*64+h, x*64:x*64+w] = np.frombuffer(raw[:w*h], np.uint8).reshape(h, w)
        masks[y*64:y*64+h, x*64:x*64+w] = np.frombuffer(raw[w*h:], np.uint8).reshape(h, w)
    assert hashlib.sha256(raw_grid.tobytes()).hexdigest() == GRID_SHA
    return masks, value, sha(definition)


def overlay(image, masks, region, fitted, output):
    rect = region['image_review_rect']
    crop = image.crop(rect).convert('RGBA')
    lines = Image.new('RGBA', crop.size)
    draw = ImageDraw.Draw(lines)
    mapping = np.array(fitted['world_to_image']).reshape(2, 3)
    x0, y0, w, h = region['source_rect']
    for y in range(y0, y0+h):
        for x in range(x0, x0+w):
            mask = int(masks[y, x])
            if not mask:
                continue
            corners = []
            for dx, dy in [(0, 0), (1, 0), (1, 1), (0, 1)]:
                point = mapping @ np.r_[world([x+32448+dx, y+32064+dy]), 1]
                corners.append(tuple(point-np.array(rect[:2])))
            for heading in [0, 2, 4, 6]:
                if not mask & (1 << heading):
                    draw.line([corners[heading//2], corners[(heading//2+1) % 4]], fill=(255, 35, 45, 230))
    Image.alpha_composite(crop, lines).save(output)


def survey(args):
    assert sha(args.png) == PNG_SHA, 'Wrong original PNG'
    image = Image.open(args.png)
    assert image.size == (15728, 7987), 'Unexpected original dimensions'
    masks, definition, definition_sha = navigation()
    survey = json.loads(args.survey.read_text())
    output = args.output.resolve()
    if output.is_relative_to(ROOT):
        raise ValueError('PNG overlays must remain outside the public checkout')
    output.mkdir(parents=True, exist_ok=True)
    source = {'archive': 'NOT_SUPPLIED'}
    if args.a3:
        assert sha(args.a3) == ARCHIVE_SHA
        with zipfile.ZipFile(args.a3) as archive:
            grid = np.frombuffer(archive.read('data/mapcache/4.map')[20:], np.uint8).reshape(2048, 1536).T
            assert hashlib.sha256(grid.tobytes()).hexdigest() == GRID_SHA
            selected = [n for n in archive.namelist() if re.fullmatch(r'data/client_maps/normal/4/[0-9a-fA-F]{8}\.s32', n)]
            groups = nonempty_groups = 0
            for name in selected:
                raw = archive.read(name)
                decoded = read_s32(raw, name)
                assert write_s32(decoded) == raw
                groups += decoded['counts']['groups']
                nonempty_groups += sum(bool(group['tiles']) for group in decoded['objects'])
            source = dict(archive_sha256=ARCHIVE_SHA, grid_sha256=GRID_SHA,
                          canonical_s32=len(selected), object_groups=groups, nonempty_object_groups=nonempty_groups,
                          selected_member_crc='PASS', lossless_s32_roundtrip='PASS')
    results = []
    for region in survey['regions']:
        result = fit(region['control_points'])
        # Geometry and image identities need human evidence, even if a fitted
        # transform has a tiny least-squares error. No automatic approval.
        result.update(id=region['id'], status='REVIEW_REQUIRED',
                      source_rect=region['source_rect'],
                      collision_status='NOT_VERIFIED', occlusion_status='NOT_VERIFIED',
                      threshold_world=4.0,
                      numerical_fit='PASS' if result['max_world'] <= 4 else 'FAIL')
        overlay(image, masks, region, result, output/(region['id']+'-source-collision.png'))
        results.append(result)
    report = dict(schema=1, map_id='aden_world', png=dict(bytes=args.png.stat().st_size,
                  size=list(image.size), sha256=PNG_SHA, public_redistribution='NOT_AUTHORIZED'),
                  source=source, verified_navigation_chunks=len(definition['navigation']['chunks']),
                  source_definition_sha256=definition_sha, source_grid_sha256=GRID_SHA,
                  original_png_sha256=PNG_SHA, regions=results,
                  global_transform_status='NOT_ESTABLISHED_LOCAL_SURVEY_MUST_NOT_BE_EXTRAPOLATED',
                  navigation_regenerated=False, actor_scale_changed=False,
                  runtime_eligible_regions=0, original_layers='SINGLE_COMPOSITE')
    write(output/'analysis.json', report)
    print(json.dumps({k: report[k] for k in ['runtime_eligible_regions', 'global_transform_status']}))
    for row in results:
        print(row['id'], 'max_world', row['max_world'], row['numerical_fit'], row['status'])


def build(args):
    """Only a separately reviewed survey can produce an installable local pack."""
    plan = json.loads(args.survey.read_text())
    assert sha(args.png) == PNG_SHA
    if args.output.resolve().is_relative_to(ROOT):
        raise ValueError('Private original artwork cannot be built inside the public checkout')
    for row in plan['regions']:
        if any(row.get(k) != 'VERIFIED' for k in ['status', 'collision_status', 'occlusion_status']):
            raise ValueError('Region lacks verified coordinate/collision/foreground review: '+row['id'])
        if len(row['control_points']) < 5 or any(p.get('status') != 'VERIFIED' for p in row['control_points']):
            raise ValueError('Five verified independent control points required')
        fitted = fit(row['control_points'])
        if fitted['max_world'] > 4:
            raise ValueError('Residual exceeds the actual 4px foot radius')
        x, y, w, h = row['source_rect']
        left, top, right, bottom = row['image_review_rect']
        if not (0 <= left < right <= 15728 and 0 <= top < bottom <= 7987):
            raise ValueError('Crop must be entirely inside original PNG')
        mapping = np.array(fitted['world_to_image']).reshape(2, 3)
        for dx, dy in [(0, 0), (w, 0), (w, h), (0, h)]:
            px, py = mapping @ np.r_[world([32448+x+dx, 32064+y+dy]), 1]
            if not (left-.01 <= px <= right+.01 and top-.01 <= py <= bottom+.01):
                raise ValueError('PNG crop does not cover the reviewed source region')
    image = Image.open(args.png).convert('RGBA')
    args.output.mkdir(parents=True, exist_ok=True)
    _, _, definition_sha = navigation()
    regions = []
    for row in plan['regions']:
        fitted = fit(row['control_points'])
        rect = row['image_review_rect']
        original = image.crop(rect)
        if max(original.size) > 2048:
            raise ValueError('Split the reviewed region; texture limit is 2048 pixels')
        ground = original.copy()
        restored = Image.new('RGBA', original.size)
        cuts = []
        used = Image.new('L', original.size)
        for cut in row['cuts']:
            mask = Image.new('L', original.size)
            ImageDraw.Draw(mask).polygon([(x-rect[0], y-rect[1]) for x, y in cut['image_polygon']], fill=255)
            if ImageChops.multiply(mask, used).getbbox():
                raise ValueError('Foreground masks overlap')
            used = ImageChops.lighter(used, mask)
            layer = Image.new('RGBA', original.size)
            layer.paste(original, (0, 0), mask)
            bbox = mask.getbbox()
            name = 'cut-%d-%d.png' % (len(regions), len(cuts))
            layer.crop(bbox).save(args.output/name)
            restored = Image.alpha_composite(restored, layer)
            ground.paste((0, 0, 0, 0), (0, 0), mask)
            cuts.append(dict(id=cut['id'], file=name, sha256=sha(args.output/name),
                             image_origin=[rect[0]+bbox[0], rect[1]+bbox[1]], foot_world=cut['foot_world']))
        composed = Image.alpha_composite(ground, restored)
        if any(channel.getbbox() for channel in ImageChops.difference(composed, original).split()):
            raise ValueError('Ground/foreground do not recompose exactly')
        name = 'ground-%d.png' % len(regions)
        ground.save(args.output/name)
        regions.append(dict(id=row['id'], source_rect=row['source_rect'], status='VERIFIED',
                            collision_status='VERIFIED', occlusion_status='VERIFIED',
                            world_to_image=fitted['world_to_image'], control_points=fitted['control_points'],
                            image_origin=rect[:2], file=name, sha256=sha(args.output/name), cuts=cuts))
    write(args.output/'manifest.json', dict(schema=1, map_id='aden_world', original_png_sha256=PNG_SHA,
          source_grid_sha256=GRID_SHA, source_definition_sha256=definition_sha, regions=regions))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['survey', 'build'])
    parser.add_argument('--png', type=Path, required=True)
    parser.add_argument('--a3', type=Path)
    parser.add_argument('--survey', type=Path, default=ROOT/'data/maps/aden_png_alignment.json')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    (survey if args.operation == 'survey' else build)(args)
