"""Compile actual supplied PNGs into a LOCAL Godot review pack, without scaling
the actors, recolouring pixels, deriving collisions, or modifying navigation.

Uses the existing source-coordinate field and streamed chunk renderer. Review
packs require --png-review and never write a player's normal save file.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from aden_png import ROOT, fit, sha, write

Image.MAX_IMAGE_PIXELS = 180_000_000


def compile_map(png, definition, catalog, output, mapping, source_rect, provenance):
    if output.resolve().is_relative_to(ROOT):
        raise ValueError('Original PNG derivatives must remain outside the public repository')
    if sha(png) != catalog['png_sha256']:
        raise ValueError('Original PNG SHA mismatch: '+str(png))
    image = Image.open(png).convert('RGBA')
    if list(image.size) != catalog['png_size']:
        raise ValueError('Original PNG dimensions mismatch')
    output.mkdir(parents=True, exist_ok=True)
    bx, by = definition['coordinate_mapping']['basis_x'], definition['coordinate_mapping']['basis_y']
    translation = definition['coordinate_mapping']['translation']
    matrix = np.asarray(mapping).reshape(2, 3)

    def pixel(x, y):
        world = np.array(bx)*x + np.array(by)*y + translation
        return matrix @ np.r_[world, 1]

    x0, y0, width, height = source_rect
    if any(v % 32 for v in source_rect):
        raise ValueError('Region must align with the existing 32-cell chunks')
    regions = []
    for y in range(y0, y0+height, 32):
        for x in range(x0, x0+width, 32):
            corners = np.array([pixel(x+dx, y+dy) for dx, dy in [(0, 0), (32, 0), (32, 32), (0, 32)]])
            left, top = np.maximum([0, 0], np.floor(corners.min(axis=0))-1).astype(int)
            right, bottom = np.minimum(image.size, np.ceil(corners.max(axis=0))+1).astype(int)
            if np.any(corners < [left-.01, top-.01]) or np.any(corners > [right+.01, bottom+.01]):
                raise ValueError('Region projects outside the original PNG')
            if max(right-left, bottom-top) > 2048:
                raise ValueError('A source chunk exceeds the texture limit')
            name = f'ground-{x//32}-{y//32}.png'
            image.crop((left, top, right, bottom)).save(output/name)
            regions.append(dict(source_rect=[x, y, 32, 32], world_to_image=list(mapping),
                                image_origin=[int(left), int(top)], file=name, sha256=sha(output/name), cuts=[]))
    value = dict(schema=2, map_id=definition['map_id'], source_map_id=definition['source_map_id'],
                 status='REVIEW_REQUIRED', collision_status='SOURCE_RULES_ACTIVE_PNG_CORRESPONDENCE_REVIEW_REQUIRED',
                 occlusion_status='COMPOSITE_NOT_YET_SEPARATED', png_sha256=sha(png), png_size=list(image.size),
                 source_grid_sha256=definition['source_sha256'], coordinate_evidence=provenance,
                 actor_scale_changed=False, navigation_regenerated=False, regions=regions)
    value['review_spawn_cell'] = ([981, 740] if definition['map_id'] == 'aden_world' else
                                 list(np.asarray(definition['spawn_source'])-definition['origin']))
    write(output/'manifest.json', value)
    return dict(map_id=definition['map_id'], original_png=png.name, source_grid_sha256=definition['source_sha256'],
                chunks=len(regions), status=value['status'], coordinate_evidence=provenance)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--aden', type=Path)
    p.add_argument('--towers', type=Path)
    p.add_argument('--topology', type=Path, help='Existing build_remake.py output; never rebuilt here')
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    catalog = json.loads((ROOT/'data/maps/png_map_sources.json').read_text())['maps']
    reports = []
    if args.aden:
        definition = json.loads((ROOT/'data/map_remake/private/aden/definitions/aden_world.json').read_text())
        survey = json.loads((ROOT/'data/maps/aden_png_alignment.json').read_text())['regions'][0]
        measured = fit(survey['control_points'])
        reports.append(compile_map(args.aden, definition, catalog['aden_world'], args.output/'aden_world',
                       measured['world_to_image'], survey['source_rect'], dict(method='LOCAL_AFFINE_CANDIDATE',
                       control_points=measured['control_points'], max_error_world=measured['max_world'],
                       rms_png=measured['rms_png'], verified=False)))
    if args.towers:
        if not args.topology:
            p.error('--towers requires the already verified --topology pack')
        for floor in range(1, 11):
            mid = f'oman_{floor:02}'
            definition = json.loads((args.topology/'definitions'/f'{mid}.json').read_text())
            reports.append(compile_map(args.towers/f'{100+floor}.png', definition, catalog[mid], args.output/mid,
                           [1, 0, 0, 0, 1, 0], [0, 0, *definition['dimensions']],
                           dict(method='NATIVE_48_24_CANVAS_IDENTITY_CANDIDATE', verified=False,
                                reason='PNG is 9216x4608, same as 192x192 source projection; wall/occlusion review remains')))
    args.output.mkdir(parents=True, exist_ok=True)
    write(args.output/'build_report.json', dict(maps=reports, original_art_public=False,
          faithful_complete=0, saving_enabled=False, source_collision='ORIGINAL_DIRECTIONAL_EDGES',
          domination_summit='NEEDS_IDENTIFIED_PNG_NOT_SUBSTITUTED_WITH_111'))
    print(json.dumps(dict(maps=len(reports), chunks=sum(r['chunks'] for r in reports), output=str(args.output))))


if __name__ == '__main__':
    main()
