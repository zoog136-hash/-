"""Verify an unpacked private native PNG pack against the checked-in plan.

Use after downloading/unzipping the private artifact; no source art is fetched
or placed in Git. This proof is separate from the legacy original ZIP ledger.
"""
import argparse
import json
from pathlib import Path

from PIL import Image

from build_native_png_maps import ROOT, digest


def verify(pack, plan_path):
    plan = json.loads(plan_path.read_text())
    index = json.loads((pack/'index.json').read_text())
    if index.get('plan_sha256') != digest(plan_path) or set(index['maps']) != set(plan['maps']):
        raise ValueError('Private pack does not match this source/navigation plan')
    chunks = 0
    foregrounds = 0
    rgba_pixels = 0
    for mid, row in index['maps'].items():
        if row['manifest'] != mid+'/manifest.json':
            raise ValueError('Unsafe manifest path')
        path = pack/row['manifest']
        if digest(path) != row['sha256']:
            raise ValueError('Manifest hash mismatch: '+mid)
        manifest = json.loads(path.read_text())
        if manifest['source_sha256'] != plan['sources'][plan['maps'][mid]['file']]['sha256']:
            raise ValueError('Source identity mismatch: '+mid)
        if not manifest.get('layer_rgba_roundtrip', False):
            raise ValueError('Missing composite ownership proof: '+mid)
        for chunk in manifest['chunks']+manifest.get('foreground', []):
            if Path(chunk['file']).name != chunk['file']:
                raise ValueError('Unsafe chunk path')
            image_path = path.parent/chunk['file']
            if digest(image_path) != chunk['sha256']:
                raise ValueError('Chunk hash mismatch: '+str(image_path))
            with Image.open(image_path) as image:
                image.load()
                if list(image.size) != chunk['size'] or max(image.size)>1024 or image.mode != 'RGBA':
                    raise ValueError('Chunk pixel format/dimensions invalid')
                rgba_pixels += image.width*image.height
            if 'foot_image' in chunk:
                foregrounds += 1
            else:
                chunks += 1
        if mid.startswith('albino_'):
            split_path=pack/(mid+'_source.png')
            if row.get('split',{}).get('sha256') != digest(split_path):
                raise ValueError('Split byte identity mismatch')
            with Image.open(split_path) as split:
                split.load()
                if split.size != tuple(manifest['bounds'][2:]):
                    raise ValueError('Split canvas mismatch')
    if any(mid.startswith('albino_') for mid in index['maps']):
        proof = index['albino_partition']
        if not proof['rgba_roundtrip'] or proof['omitted_pixels'] or proof['duplicated_pixels']:
            raise ValueError('Original pixel ownership proof failed')
    return dict(maps=len(index['maps']), chunks=chunks, foreground_cuts=foregrounds, decoded_chunk_pixels=rgba_pixels,
                plan_sha256=index['plan_sha256'], all_chunk_sha256_verified=True,
                production_complete=False, android_device='NOT_RUN')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pack', type=Path, required=True)
    parser.add_argument('--plan', type=Path, default=ROOT/'data/maps/native_png_plan.json')
    args = parser.parse_args()
    print(json.dumps(verify(args.pack, args.plan)))
