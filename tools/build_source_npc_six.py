#!/usr/bin/env python3
"""Decode the explicitly approved six-NPC package; no executable or implicit variant lookup."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from PIL import Image

def read(path):
    return json.loads(path.read_text())

def build(package, handoff, root):
    for row in read(package / 'package_files.json')['files']:
        data = (package / row['path']).read_bytes()
        assert len(data) == row['bytes'] and hashlib.sha256(data).hexdigest() == row['sha256'], row['path']
    sys.path.insert(0, str(package))
    from package_reader import Package
    spec = importlib.util.spec_from_file_location('npc_spr_decode', package / 'decoder/spr_decode.py')
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    sprites = {}
    decoded_frames = 0
    for path in sorted((package / 'sprites').glob('*.spr')):
        data = path.read_bytes()
        assert hashlib.sha256(data).hexdigest() == path.stem
        sprite = decoder.Sprite(data)
        for frame in range(len(sprite.frames)):
            image, meta = sprite.render(frame)
            assert image.mode == 'RGBA'
            decoded_frames += 1
        sprites[str(path)] = sprite
    resolver = Package(package)
    catalog = read(handoff / 'npc_additions.json')
    assert {n['source_npc_id'] for n in catalog['npcs']} == {'70649','70650','70739','70794','71094','80093'}
    assert all(not n[k] for n in catalog['npcs'] for k in ['shop_enabled','quest_execution_enabled','combat_enabled','source_stats_import_enabled'])
    output = root / 'assets/npc/source_six'
    output.mkdir(parents=True, exist_ok=True)
    for npc in catalog['npcs']:
        binding = resolver.bindings[npc['visual_binding_id']]
        idle = next(a for a in binding['actions'] if a['code'] == 3)
        headings = range(8) if idle['eight_slot_bounds_pass_conditional'] else [0]
        resolved = [resolver.resolve(binding['binding_id'], 3, i, h) for h in headings for i in range(len(idle['references']))]
        bounds = decoder.union_bounds([sprites[r['blob_path']].frame_bounds(r['frame_index']) for r in resolved])
        w, h = bounds[2] - bounds[0], bounds[3] - bounds[1]
        count = len(idle['references'])
        atlas = Image.new('RGBA', (w * count, h * len(headings)))
        pixel_hashes = []
        for index, ref in enumerate(resolved):
            frame, meta = sprites[ref['blob_path']].render(ref['frame_index'], canvas_bounds=bounds)
            assert meta['nonzero_alpha_pixels'] > 0
            atlas.alpha_composite(frame, ((index % count) * w, (index // count) * h))
            pixel_hashes.append(meta['rgba_sha256'])
        relative = 'assets/npc/source_six/' + npc['source_npc_id'] + '.png'
        atlas.save(root / relative)
        npc['visual'] = {'atlas': 'res://' + relative, 'sha256': hashlib.sha256((root / relative).read_bytes()).hexdigest(),
            'atlas_rgba_sha256': hashlib.sha256(atlas.tobytes()).hexdigest(),
            'cell_size': [w, h], 'frames': count, 'heading_slots': len(headings), 'canvas_bounds': bounds,
            'pixel_origin_in_canvas': [-bounds[0], -bounds[1]], 'actor_foot': None,
            'actor_foot_status': 'HOLD: raster origin is not an anatomical foot',
            'direction_semantics_verified': False, 'heading_policy': 'literal slots; horse explicitly reuses same-identity slot 0',
            'seconds_per_frame': 0.12, 'timing_policy': 'TWILIGHT cosmetic loop; original duration units unverified',
            'source_binding': binding, 'rgba_sha256': pixel_hashes}
        npc['placement_status'] = 'HOLD: current source-map binding, collision and actor foot require integration review'
    catalog['handoff'] = {'library_file_id': 'libfile_52e6fe00307081918f0b17bc13c5ae56', 'version': 1,
        'sha256': '4a8fe87073024226e1ce4c4e1b68a7fbdf9c7904ebbbb40e52d6a82df6bf31c0',
        'raw_spr_count': len(sprites), 'decoded_frames': decoded_frames}
    target = root / 'data/npc/source_six.json'
    target.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
    (root / 'data/npc/source_six_dialogues.json').write_bytes((handoff / 'dialogue_additions.json').read_bytes())
    print(json.dumps({'npcs': len(catalog['npcs']), 'decoded_spr': len(sprites), 'decoded_frames': decoded_frames}))

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--package', type=Path, required=True)
    p.add_argument('--handoff', type=Path, required=True)
    p.add_argument('--root', type=Path, required=True)
    a = p.parse_args()
    build(a.package.resolve(), a.handoff.resolve(), a.root.resolve())
