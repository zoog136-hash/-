#!/usr/bin/env python3
"""Prepare one native movement authoring request without changing saved assets.

Only request JSON is created. No image tool, catalog mutation, approval, staging,
CI, or Git operation is performed. ``prepare`` is pure, including in fixtures.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

import pr122_native_production_approvals as production_approvals


BASE = Path('docs/remake/evidence/pr122-mythic-detailed')
QUEUE = BASE / 'batch01/queue.json'
MANIFEST = BASE / 'batch01/source-manifest.json'
BATCH = BASE / 'batch04'
SOURCE_STEMS = {'transform:413': 'thunder_female'}
DIRECTIONS = {
    'E': 'EAST, screen right; the right-facing side view',
    'SE': 'SOUTHEAST, screen lower-right; front-right three-quarter view',
    'S': 'SOUTH, screen down; full front view',
    'SW': 'SOUTHWEST, screen lower-left; front-left three-quarter view',
    'W': 'WEST, screen left; the left-facing side view',
    'NW': 'NORTHWEST, screen upper-left; back-left three-quarter view',
    'N': 'NORTH, screen up; full back view',
    'NE': 'NORTHEAST, screen upper-right; back-right three-quarter view',
}
PHASES = {
    'walk': ['left_support_right_forward_contact', 'left_support_midstance_right_passage',
             'left_to_right_support_transfer', 'right_support_left_forward_contact',
             'right_support_midstance_left_passage', 'right_to_left_support_transfer'],
    'run': ['left_forefoot_contact', 'left_leg_compression_right_knee_drive',
            'airborne_flight_left_push_off', 'right_forefoot_contact',
            'right_leg_compression_left_knee_drive', 'airborne_flight_right_push_off'],
}


def read_json(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as exc:
        raise ValueError(f'Cannot read saved JSON: {path.name}') from exc


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def local_file(root, saved_path):
    relative = saved_path.removeprefix('res://')
    path = root / relative
    if Path(relative).is_absolute() or '..' in Path(relative).parts:
        raise ValueError('References must be repository-relative files')
    if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(root):
        raise ValueError(f'Missing or unsafe reference: {relative}')
    return path.resolve()


def prepare(root, key, direction, role, version):
    """Return ``(relative_request_path, request)`` without writing any file."""
    root = Path(root).resolve()
    if key not in SOURCE_STEMS:
        raise ValueError('Only the next detailed mythic actor transform:413 is supported')
    if direction not in DIRECTIONS or role not in PHASES:
        raise ValueError('Use a supported direction and walk or run role')
    if not re.fullmatch(r'v[0-9]{2,4}[a-z0-9]*', version):
        raise ValueError('Use an ASCII version such as v01, without path characters')
    queue = read_json(root / QUEUE)
    rows = [row for row in queue if row.get('id') == key]
    if len(rows) != 1 or not rows[0].get('name') or not rows[0].get('grade'):
        raise ValueError('Actor identity and grade must come from exactly one queue entry')
    actor = rows[0]
    manifest = read_json(root / MANIFEST)
    approval_state = production_approvals.load_state(root, manifest=manifest)
    approval_state.require_mutable(key, 'prepare movement for')
    selected = manifest.get('selected_locomotion_sheets', {})
    slot = f'{key}:{direction}:{role}'
    if slot in selected or slot in manifest.get('selected_detailed_action_sheets', {}):
        raise ValueError('This native movement is already selected; never recreate it')
    raw = manifest.get('raw_images', [])
    if any((row.get('key'), row.get('direction'), row.get('role'), row.get('version')) ==
           (key, direction, role, version) for row in raw):
        raise ValueError('This source version already exists, including preserved HOLDs')

    stem = SOURCE_STEMS[key]
    output = BATCH / f'{stem}-{direction}-{role}-{version}.png'
    if not (root / BATCH).resolve().is_relative_to(root):
        raise ValueError('The request/output directory must stay inside the fixture or repository')
    if (root / output).exists() or any((root / BASE).glob(f'batch*/{output.name}')):
        raise ValueError('An output with this source name already exists; preserve it')
    previous = sorted((root / BASE).glob('batch*/request-*.json'))
    for path in previous:
        old = read_json(path)
        if (old.get('key'), old.get('direction'), old.get('role'), old.get('version')) == (
                key, direction, role, version):
            raise ValueError('An authoring request for this exact version already exists')
    ordinals = []
    for path in (root / BATCH).glob('request-*.json'):
        match = re.match(r'request-([0-9]+)-', path.name)
        if not match:
            raise ValueError('Unexpected request name in batch04; preserve and inspect it')
        ordinals.append(int(match.group(1)))
    ordinal = max(ordinals, default=0) + 1
    request_path = BATCH / f'request-{ordinal:03d}-{stem}-{direction}-{role}-{version}.json'
    if (root / request_path).exists():
        raise ValueError('Never replace an existing request file')

    references = [local_file(root, actor['reference'])]
    descriptions = ['Reference 1 is the ORIGINAL PORTRAIT and the sole design/identity authority.']

    def add_selected(heading, movement, required=False):
        source = selected.get(f'{key}:{heading}:{movement}')
        if not source:
            if required:
                raise ValueError('Author and select the same-heading native walk before its run')
            return
        path = local_file(root, source)
        records = [row for row in raw if row.get('key') == key and row.get('source') == source]
        if (len(records) != 1 or records[0].get('geometry', {}).get('status') != 'GEOMETRY_PASS'
                or records[0].get('direction') != heading or records[0].get('role') != movement
                or digest(path) != records[0].get('sha256')):
            raise ValueError('Selected movement reference lacks matching saved geometry and SHA')
        if path not in references:
            references.append(path)
            descriptions.append(f'Reference {len(references)} is saved native {heading} {movement}: '
                                'use its identity/body scale and articulation as a guide, '
                                'never copy its existing poses or facing.')

    if role == 'run':
        add_selected(direction, 'walk', required=True)
    add_selected('E', 'walk')
    add_selected('E', 'run')
    gait = (
        'Author SIX true WALK phases: 0 anatomical LEFT foot bears weight while RIGHT foot '
        'contacts forward; 1 left support with right leg passing; 2 right foot takes support '
        'as left pushes off; 3 RIGHT support with LEFT forward contact; 4 right support with '
        'left leg passing; 5 left foot takes support as right pushes off. Clearly alternate '
        'the actual anatomical support limbs and show toe-off, heel contact, knee/hip '
        'articulation, and passage. Maintain grounded, readable weight transfer; a frozen '
        'support foot with cosmetic leg changes is invalid.'
        if role == 'walk' else
        'Author SIX dedicated RUN phases: 0 LEFT forefoot lands; 1 left compression with '
        'right knee driving; 2 airborne flight after left push-off; 3 RIGHT forefoot lands; '
        '4 right compression with left knee driving; 5 airborne flight after right '
        'push-off. BOTH feet must visibly clear the ground in phases2 and5 only. Opposite '
        'support feet visibly alternate in0 and3. Stronger knee drive, longer stride, deeper '
        'compression, faster arm counter-swing, and more forward lean than walk, with '
        'coordinated torso and equipment response. Draw new sprint articulation, never '
        'reuse or accelerate the walk poses.'
    )
    prompt = (
        f'Author SIX independently drawn high-detail isometric RPG {role.upper()} sprites of '
        f'EXACTLY {actor["name"]} ({actor["grade"]}) from the attached ORIGINAL PORTRAIT. '
        'Preserve the precise face, hair, actual clothing/armor, colors, body proportions, '
        'equipment and exact existing weapon design and anatomical weapon hand. The '
        'portrait determines whether any item or anatomy exists: do not invent wings, '
        'horns, a helmet, demon anatomy, dark armor, or a different weapon. Preserve '
        'identity and detailed craftsmanship throughout all six poses.\n\n'
        'Technical sprite atlas: 1024x1536 pixels, EXACTLY TWO COLUMNS and THREE ROWS, '
        'six512x512 cells, temporal order left-to-right then down. ONE whole character in '
        'each cell. Keep every complete silhouette, including all actual equipment tips, '
        'inside its central320x320 area; at least96pixels of empty transparent gutter on '
        'every cell edge. More than70percent of the sheet remains empty. No pair of '
        'character bounding rectangles overlaps. Use the SAME head and torso scale in '
        'every phase and direction; articulate or re-angle the existing equipment, never '
        'shrink an individual pose, omit a part, or crop tips to fit.\n\n'
        f'All SIX figures face {DIRECTIONS[direction]}, with the same elevated '
        'orthographic isometric camera and local light. Head, torso, hips, toes, and '
        'equipment all agree with that heading. Rear views show the actual back surfaces; '
        'do not turn a rear-facing head toward the viewer. Render the true new perspective '
        'and occlusion, with anatomically consistent handedness; do not mirror another '
        f'direction. {gait}\n\n'
        'All six poses must be independently drawn, with visible limb and joint changes; '
        'never translate, rotate, recolor, mirror, or repeat one pose. Preserve the same '
        'physical character and rigid equipment rather than changing the model between '
        'frames. Crisp hard-edged cutout sprites, rich material shading INSIDE the body. '
        'All body and dark materials fully opaque; alpha0 everywhere outside the exact '
        'silhouette, antialiasing only1-2pixels at its edge. No shadows, floor, diffuse '
        'aura, bloom, halo, lightning trails, background, scenery, labels, grids, text, '
        'extra figures, detached ornaments or spare weapons. Keep any portrait-specific '
        'inset emissive details contained in their real equipment surfaces.\n\n' +
        '\n'.join(descriptions)
    )
    request = dict(
        key=key, name=actor['name'], grade=actor['grade'], direction=direction, role=role,
        version=version, source_stem=stem, source_batch='batch04',
        planned_output_source=output.as_posix(),
        references=[str(path) for path in references], prompt=prompt,
        reference_sha256={str(path): digest(path) for path in references},
        transparent_background=True, phase_contract=PHASES[role], requested_poses=6,
        source_of_identity=actor['reference'],
        user_authorization='production image tools allowed; no chat image attachments',
        status='REQUESTED_NOT_APPROVED', production_connected=False,
        detailed_completed=False, completed_added=0,
        approval_rule='Source/geometry/shared motion do not approve a detailed character; '
                      'existing approved genericFlare and all production catalogs remain unchanged.')
    return request_path, request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--key', required=True)
    parser.add_argument('--direction', required=True, choices=tuple(DIRECTIONS))
    parser.add_argument('--role', required=True, choices=tuple(PHASES))
    parser.add_argument('--version', required=True)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--dry-run', action='store_true', help='Build the request without writing it')
    args = parser.parse_args()
    # A producer may switch priorities after a completed, pushed unit. Never
    # cancel an in-flight image or mutate its request just to change the queue.
    if Path('/workspace/scratch/twilight-authoring-pause').exists():
        print('AUTHORING_PAUSED_AT_SAVED_CHECKPOINT: priority correction; all files preserved', file=sys.stderr)
        return 3
    try:
        relative, request = prepare(args.root, args.key, args.direction, args.role, args.version)
        if not args.dry_run:
            path = args.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open('x') as out:
                out.write(json.dumps(request, ensure_ascii=False, indent=2) + '\n')
        # Only plain text request data; no image/binary content is ever emitted.
        print(json.dumps(dict(path=relative.as_posix(), request=request), ensure_ascii=False))
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f'REQUEST_NOT_CREATED: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
