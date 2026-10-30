#!/usr/bin/env python3
"""Install authorized private substitute SPR art; never executes source binaries.
Usage: python3 tools/skills/install_similar_effects.py INPUT_DIRECTORY --root .
Timing is a presentation-only 12 fps convention, not recovered source ticks.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image
from spr_decode import Sprite


def install(source, root):
    bindings = json.loads((source / 'resource_bindings.json').read_text())
    records = {r['sha256']: r for r in bindings['raw_sprite_records']}
    # Check every supplied raw record, including aliases, before producing art.
    for record in bindings['raw_sprite_records']:
        raw = (source / record['package_blob']).read_bytes()
        if hashlib.sha256(raw).hexdigest() != record['sha256']:
            raise ValueError('SPR hash mismatch: ' + record['record_key'])
    destination = root / 'assets/external_spx/similar_skills'
    destination.mkdir(parents=True, exist_ok=True)
    effects = {}
    for binding in bindings['bindings']:
        alias = binding['selected_alias']
        record = records[alias['selected_sha256']]
        sprite = Sprite((source / record['package_blob']).read_bytes())
        images = [sprite.render(i, fixed_canvas=True)[0] for i in range(len(sprite.frames))]
        width, height = images[0].size
        count = len(images)
        if count > 128 or width * height * count > 16_777_216:
            raise ValueError('effect exceeds presentation budget')
        columns = min(8, count)
        atlas = Image.new('RGBA', (width * columns, height * ((count + columns - 1) // columns)))
        for i, image in enumerate(images):
            atlas.paste(image, ((i % columns) * width, (i // columns) * height))
        name = binding['effect_id'] + '.png'
        atlas.save(destination / name)
        # Keep the original grid origin rather than alpha-crop centering frames.
        bounds = sprite.file_bounds('original-grid')
        effects[binding['effect_id']] = {'atlas': name, 'width': width, 'height': height,
            'columns': columns, 'count': count, 'offset': list(bounds[:2]),
            'sha256': hashlib.sha256((destination / name).read_bytes()).hexdigest(),
            'raw_sha256': record['sha256'], 'model_id': alias['model_id'], 'fps': 12}
    (destination / 'manifest.json').write_text(json.dumps({'schema_version': 1,
        'timing': '12fps presentation convention; original action ticks unverified',
        'blend': 'unmodified RGBA; no additive assumption', 'effects': effects}, indent=2) + '\n')
    return {'effects': len(effects), 'raw_records_verified': len(bindings['raw_sprite_records']),
            'directory': str(destination)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--root', type=Path, default=Path('.'))
    args = parser.parse_args()
    print(json.dumps(install(args.source, args.root)))
