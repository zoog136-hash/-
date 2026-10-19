"""Assemble every actual frame, preserving raw PNG bytes and source failures."""
from pathlib import Path
import json
import os
import shutil
import sys

repo = Path('/workspace/twilight')
sys.path.insert(0, str(repo / 'tools'))
import import_original_based_motion as core

stage = Path('/workspace/runtime/batch16/Main-project')
if not stage.exists():
    excluded = {'.git', '.godot', 'docs', '.agents', '.codex', 'build',
                'test-results', 'qa', 'screenshots', 'generated_images', '__pycache__'}
    def copy_asset(source, destination):
        if Path(source).suffix.lower() in {'.png', '.webp', '.jpg', '.ogg', '.ttf', '.wav'}:
            os.link(source, destination)
        else:
            shutil.copy2(source, destination)
        return destination
    shutil.copytree(repo, stage, copy_function=copy_asset,
                    ignore=lambda p, names: [n for n in names if n in excluded])

root = Path('/workspace/runtime/batch16')
old = repo / 'docs/remake/evidence/pr122-remaining106/batch13'
reference_height = 335.5 * 256 / 640
sheets = []
proofs = []

def add(path, role, rows, directions, axis, canvas=None):
    sample_rows = [0, 1] if role in {'idle', 'hit'} else [0]
    provisional = core.analyze(path, rows, sample_rows, directions_axis=axis,
        canvas_size=1536, directions=directions)
    # One uniform scale for the complete source sheet, never per-frame sizing.
    if canvas is None:
        canvas = round(provisional['neutral_height'] * 256 / reference_height / 8) * 8
    geometry = core.analyze(path, rows, sample_rows, directions_axis=axis,
        canvas_size=canvas, directions=directions)
    core.require_complete_pose_regions(path, geometry)
    spec = {'output_path': str(path), 'rows': rows, 'roles': {role: list(range(rows))},
            'directions': directions, 'directions_axis': axis,
            'canvas_size': canvas, 'reference_rows': sample_rows,
            'scale_review_note': 'One reviewed canvas for this whole source resolution; no per-pose scale or altered raster pixels.'}
    sheets.append(spec)
    proofs.append({'file': str(path), 'role': role, 'directions': directions,
                   'sha256': core.sha(path), 'canvas': canvas, 'geometry': geometry})

add(old / 'albino-mutated-golem-idle16-pilot01.png', 'idle', 2, core.DIRECTIONS, 'columns', 640)
add(old / 'hit16-pilot01.png', 'hit', 2, core.DIRECTIONS, 'columns', 640)
for direction in core.DIRECTIONS:
    add(root / ('golem-walk-' + direction + '-v01.png'), 'walk', 8, [direction], 'phase_grid4')
for role in ['attack', 'death']:
    for pair in ['E-SE', 'S-SW', 'W-NW', 'N-NE']:
        add(root / ('golem-' + role + '-' + pair + '-v01.png'), role, 3, pair.split('-'), 'rows')

candidate = {'key': 'monster:알비노 변이된 골렘',
    'prompt': 'Batch16: exact saved image-generation requests; newly drawn reference-based 64 walk,24 attack,24 death poses plus preserved16 idle/16 hit. Not SPX originals. No copied/reflected/generated motion by whole-image transforms.',
    'review': {'identity_preserved': True, 'eight_views': True, 'motion_roles': True,
               'no_clipping': True, 'notes': 'Raw sheet review of all eight views and five roles; strict complete-source bounds/ownership/uniqueness validated before staging. Actual Main and transition-scale review are still required before production approval.'},
    'sheets': sheets}
actor = 'albino_mutated_golem_batch16_authored'
result = core.import_sheet(stage, candidate, actor, [candidate['key']], True)
(root / 'golem-candidate.json').write_text(json.dumps(candidate, ensure_ascii=False, indent=2) + '\n')
(root / 'golem-all-sources.json').write_text(json.dumps(proofs, ensure_ascii=False, indent=2) + '\n')
fixture = {'cases': [{'name': '알비노 변이된 골렘', 'folder': actor,
                     'slug': 'albino-mutated-golem'},
                    {'name': '알비노 이구아나', 'folder': 'albino_iguana_monster_authored',
                     'slug': 'preserved-iguana-baseline'}]}
(stage / 'tests/fixtures/pr122_batch16.json').write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(result, ensure_ascii=False))
print('COMPLETE_SOURCE_MATRIX', sum(len(p['geometry']['frames']) for p in proofs))
