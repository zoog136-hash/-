"""Lossless PRIVATE preparation of the four user-selected October 19 PNGs.

This compiler never infers server map IDs, collisions or monster coordinates.
The reviewed plan owns every visible Albino pixel exactly once. Runtime chunks
remain at native resolution; previews are used only for the minimap.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
Image.MAX_IMAGE_PIXELS = 180_000_000


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')


def partition(image, cuts):
    """Explicit irregular ridge masks, not equal rectangular subdivisions."""
    width, height = image.size
    yy = np.arange(height)
    boundaries = [np.interp(yy, [p[1] for p in cut], [p[0] for p in cut]) for cut in cuts]
    if len(boundaries) != 2 or np.any(boundaries[0] >= boundaries[1]):
        raise ValueError('Two disjoint, ordered boundary polylines required')
    xx = np.arange(width)[None, :]
    owner = (xx >= boundaries[0][:, None]).astype(np.uint8)
    owner += (xx >= boundaries[1][:, None]).astype(np.uint8)
    rgba = np.asarray(image)
    visible = rgba[:, :, 3] > 0
    result = []
    counts = []
    for index in range(3):
        selected = visible & (owner == index)
        ys, xs = np.nonzero(selected)
        if not len(xs):
            raise ValueError('Empty Albino region')
        box = [int(xs.min()), int(ys.min()), int(xs.max()+1), int(ys.max()+1)]
        left, top, right, bottom = box
        crop = rgba[top:bottom, left:right].copy()
        crop[owner[top:bottom, left:right] != index] = 0
        counts.append(int(selected.sum()))
        result.append((Image.fromarray(crop), box))
    if sum(counts) != int(visible.sum()):
        raise ValueError('Visible terrain lost or duplicated')
    # Readable proof independent of the masks: reassemble each derivative and
    # compare ALL visible RGBA channels, including semitransparent edge pixels.
    restored = np.zeros_like(rgba)
    ownership = np.zeros(visible.shape, np.uint8)
    for crop, (left, top, right, bottom) in result:
        pixels = np.asarray(crop)
        support = pixels[:, :, 3] > 0
        target = restored[top:bottom, left:right]
        target[support] = pixels[support]
        ownership[top:bottom, left:right] += support
    if not np.array_equal(restored[visible], rgba[visible]) or np.any(ownership[visible] != 1):
        raise ValueError('Albino visible pixel roundtrip failed')
    return result, dict(visible_pixels=int(visible.sum()), region_pixels=counts,
                        omitted_pixels=0, duplicated_pixels=0, rgba_roundtrip=True)


def compile_chunks(image, box, destination, chunk_size=1024):
    if not 64 <= chunk_size <= 1024:
        raise ValueError('Chunk edge must be between 64 and 1024')
    destination.mkdir(parents=True)
    left, top, _, _ = box
    chunks = []
    for y in range(0, image.height, chunk_size):
        for x in range(0, image.width, chunk_size):
            crop = image.crop((x, y, min(x+chunk_size, image.width), min(y+chunk_size, image.height)))
            if not crop.getchannel('A').getbbox():
                continue
            path = destination/f'{x//chunk_size}-{y//chunk_size}.png'
            crop.save(path)
            # Decode the written bytes as well as checking the in-memory crop.
            with Image.open(path) as decoded:
                decoded.load()
                if decoded.size != crop.size or decoded.tobytes() != crop.tobytes():
                    raise ValueError('PNG chunk pixel roundtrip failed')
            chunks.append(dict(file=path.name, position=[left+x, top+y],
                               size=list(crop.size), sha256=digest(path), bytes=path.stat().st_size))
    preview = image.copy()
    preview.thumbnail((512, 512))
    preview.save(destination/'overview.png')
    return chunks


def build(sources, plan_path, output):
    output = output.resolve()
    if output.is_relative_to(ROOT) or output.exists():
        raise ValueError('Choose a NEW private directory outside the public checkout')
    plan = json.loads(plan_path.read_text())
    output.mkdir(parents=True)
    originals = {}
    for filename, expected in plan['sources'].items():
        path = sources/filename
        if digest(path) != expected['sha256'] or path.stat().st_size != expected['bytes']:
            raise ValueError('Original byte identity mismatch: '+filename)
        with Image.open(path) as image:
            image.load()
            if list(image.size) != expected['size'] or image.mode != 'RGBA':
                raise ValueError('Original canvas/mode mismatch: '+filename)
        originals[filename] = dict(expected, acquired=True, decoded=True)
    with Image.open(sources/'13474.png') as albino:
        splits, proof = partition(albino, plan['albino_partition']['cuts'])
    built = {}
    for mid, spec in plan['maps'].items():
        if mid.startswith('albino_'):
            image, box = splits[int(mid[-2:])-1]
            image.save(output/(mid+'_source.png'))
        else:
            with Image.open(sources/spec['file']) as original:
                box = list(original.getchannel('A').getbbox())
                image = original.crop(box)
        chunks = compile_chunks(image, box, output/mid)
        manifest = dict(schema=1, map_id=mid, source_file=spec['file'],
                        source_sha256=originals[spec['file']]['sha256'],
                        plan_sha256=digest(plan_path), bounds=[box[0], box[1], image.width, image.height],
                        native_pixel_scale=1, chunks=chunks, overview='overview.png',
                        collision_scope=spec['collision_scope'], foreground_scope='NOT_RECONSTRUCTED')
        write(output/mid/'manifest.json', manifest)
        built[mid] = dict(manifest=mid+'/manifest.json', sha256=digest(output/mid/'manifest.json'),
                          chunks=len(chunks), bounds=manifest['bounds'])
        if mid.startswith('albino_'):
            split = output/(mid+'_source.png')
            built[mid]['split'] = dict(file=split.name, sha256=digest(split), bytes=split.stat().st_size)
    report = dict(schema=1, sources=originals, maps=built, albino_partition=proof,
                  plan_sha256=digest(plan_path), source_map_ids_inferred=False,
                  collision_from_image_colors=False, production_complete=False)
    write(output/'index.json', report)
    print(json.dumps(dict(maps=len(built), chunks=sum(m['chunks'] for m in built.values()),
                          albino_partition=proof, output=str(output))))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', type=Path, required=True)
    parser.add_argument('--plan', type=Path, default=ROOT/'data/maps/native_png_plan.json')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build(args.sources, args.plan, args.output)
