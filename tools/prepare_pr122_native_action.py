#!/usr/bin/env python3
"""Save an exact six-phase authoring request for the next missing native action."""
import hashlib
import json
from pathlib import Path

import stage_pr122_native_locomotion as staging


FACINGS = dict(E='EAST / screen right', SE='SOUTHEAST / screen down-right',
               S='SOUTH / screen down', SW='SOUTHWEST / screen down-left',
               W='WEST / screen left', NW='NORTHWEST / screen up-left',
               N='NORTH / screen up', NE='NORTHEAST / screen up-right')
PHASES = dict(
    attack=['poised guard', 'visible backswing / anticipation', 'loaded compression',
            'active forward strike / CONTACT', 'follow-through', 'recovery toward guard'],
    hit=['stable guard', 'impact response', 'maximum stagger / recoil',
         'counterbalance', 'regaining control', 'recovered guard'],
    death=['fatal hit / unstable', 'loss of balance', 'body falling / knees collapsing',
           'ground impact', 'settling', 'fully fallen motionless corpse'],
    idle=['neutral breathing', 'inhale begins', 'inhale peak',
          'weight / wing settling', 'exhale', 'return close to initial guard'])


def prepare(root):
    register = json.loads((root / staging.REGISTER).read_text())
    target = register['next_detailed_source']
    assert target, 'No unheld missing action remains in this queue'
    key, direction, role = (target[k] for k in ('key', 'direction', 'role'))
    manifest = json.loads((root / staging.SOURCE_MANIFEST).read_text())
    selected = manifest.get('selected_detailed_action_sheets', {})
    assert f'{key}:{direction}:{role}' not in selected
    queue = json.loads((root / 'docs/remake/evidence/pr122-mythic-detailed/batch01/queue.json').read_text())
    actor = next(a for a in queue if a['id'] == key)
    refs = [root / actor['reference'].removeprefix('res://'),
            root / manifest['selected_locomotion_sheets'][f'{key}:{direction}:walk']]
    guide = selected.get(f'{key}:E:{role}')
    if guide:
        refs.append(root / guide)
    name = staging.ACTORS[key].rsplit('_', 1)[0]
    folder = root / 'docs/remake/evidence/pr122-mythic-detailed/batch03'
    ordinal = 1 + max(int(p.name.split('-')[1]) for p in folder.glob('request-*.json'))
    version = 'v01'
    assert not (folder / f'{name}-{direction}-{role}-{version}.png').exists(), 'Never repeat an existing source'
    phase_text = '; '.join(f'{i}: {p}' for i, p in enumerate(PHASES[role]))
    prompt = f'''Author SIX independently drawn, high-detail isometric RPG {role.upper()} animation sprites of EXACTLY {actor['name']}. The first original portrait is identity authority. The second saved {direction} native WALK sheet establishes facing and anatomy ONLY, not the requested motion. Any third sheet establishes this action's phase progression only; redraw its anatomy and occlusion for {direction}.

Transparent atlas: 1024x1536, EXACTLY TWO COLUMNS and THREE ROWS in temporal order left-to-right then down. Six 512x512 cells. ONE complete connected character in each cell, inside the central 300x300 area; at least106 transparent pixels at every edge. Keep coherent head/torso scale; fold/re-angle existing wings rather than crop them. Never let bounding rectangles overlap. All equipment and wing/weapon tips must remain inside each cell.

Every phase faces {FACINGS[direction]}, with the same isometric camera, correct view-dependent face and armor occlusion, unchanged weapon hand, original horns/helmet, black armor, wings, colors and materials. Retain the exact character rather than a generic demon. Do not invent weapons, limbs or ornaments. Animate actual joints and coherent body mechanics: {phase_text}.

Six true successive poses with independently articulated body/arms/legs/weapon/wings. No copying locomotion, rigid translation/rotation/recoloring, mirroring, mixed directions, sprite clones, or perspective changes. Preserve all existing equipment and connected anatomy. High-detail material shading stays inside fully opaque bodies, including dark materials. No background, floor, shadows, grid, labels, smoke, diffuse aura, halos, detached effects, long energy trails, or spare body parts. Alpha0 outside each silhouette, antialiasing only one or two edge pixels.'''
    if role == 'attack':
        prompt += '\nPhase3 must visibly extend the actual referenced weapon or natural striking limb toward the facing direction, at contact. Strong anticipation, release and follow-through; hands retain the same weapon throughout.'
    elif role == 'death':
        prompt += '\nThis is a genuine irreversible fall, not a bow or hit recoil. Phase5 must be fully fallen, resting on the ground with folded/spread original wings and recognizable anatomy; no standing final pose. Keep equipment attached, no gore.'
    elif role == 'hit':
        prompt += '\nThis is a brief impact stagger followed by controlled recovery, not an attack or a death. No weapon swing toward a target. Original appendages react physically to the torso recoil.'
    else:
        prompt += '\nThis is an idle breathing/hover loop. Keep the support/root stable, with coherent chest and wing articulation. Last phase should lead naturally back to phase0.'
    request = dict(**target, name=actor['name'], version=version, references=[str(p) for p in refs],
                   reference_sha256={str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in refs},
                   prompt=prompt, transparent_background=True,
                   user_authorization='production image tools allowed; no chat image attachments',
                   phase_contract=PHASES[role], status='REQUESTED_NOT_APPROVED')
    if role == 'attack':
        request['intended_contact_frame'] = 3
    path = folder / f'request-{ordinal:03d}-{name}-{direction}-{role}-{version}.json'
    assert not path.exists()
    path.write_text(json.dumps(request, ensure_ascii=False, indent=2) + '\n')
    return path.relative_to(root).as_posix(), request


if __name__ == '__main__':
    path, request = prepare(Path(__file__).resolve().parents[1])
    print(json.dumps(dict(path=path, request=request), ensure_ascii=False))
