"""Verify an unpacked private native PNG pack against the checked-in plan.

Use after downloading/unzipping the private artifact; no source art is fetched
or placed in Git. This proof is separate from the legacy original ZIP ledger.
"""
import argparse
import json
from pathlib import Path

from PIL import Image

from build_native_png_maps import ROOT, digest


def plan_identity(pack, plan_path, receipt_path=None):
    """Return the plan identity the pack must carry, mirroring native_png_registry.gd.

    Normally that is the plan file's own hash. A receipt may instead keep an
    earlier shared plan_sha256 as the maps' geometry/save identity (e.g. Faith
    maps after Aden was retired) while plan_document_sha256 authenticates the
    current plan document. Both pins are required; neither is relaxed.
    """
    if receipt_path is None:
        return digest(plan_path)
    receipt = json.loads(Path(receipt_path).read_text())
    if receipt.get('index_sha256') != digest(pack/'index.json'):
        raise ValueError('Receipt does not pin this private pack index')
    if receipt.get('plan_document_sha256', digest(plan_path)) != digest(plan_path):
        raise ValueError('Receipt does not authenticate this plan document')
    return receipt.get('plan_sha256')


def verify(pack, plan_path, receipt_path=None):
    plan = json.loads(plan_path.read_text())
    index = json.loads((pack/'index.json').read_text())
    if index.get('plan_sha256') != plan_identity(pack, plan_path, receipt_path) or set(index['maps']) != set(plan['maps']):
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
    parser.add_argument('--receipt', type=Path, default=None,
                        help='tracked pack receipt (data/maps/*_pack.json) pinning the index and plan document')
    args = parser.parse_args()
    print(json.dumps(verify(args.pack, args.plan, args.receipt)))
