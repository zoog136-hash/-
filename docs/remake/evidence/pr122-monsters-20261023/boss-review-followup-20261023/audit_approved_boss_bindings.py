#!/usr/bin/env python3
"""Read-only boss binding audit; print JSON without changing repository files.

Reproduce from repository root with:
python docs/remake/evidence/pr122-monsters-20261023/boss-review-followup-20261023/audit_approved_boss_bindings.py

PASS bosses are excluded. Alpha seams are narrow evidence of a region cutting
through visible pixels, not a general visual-quality or animation approval.
"""
from pathlib import Path
import json
import re
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[5]
EVIDENCE = ROOT / 'docs/remake/evidence/pr122-monsters-20261023'


def parse(path):
    text = path.read_text()
    external = {id_: value for value, id_ in re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text)}
    poses = {}
    for id_, body in re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*(.*?)(?=\n\[|\Z)', text, re.S):
        rect = re.search(r'region = Rect2\(([^)]+)\)', body)
        atlas = re.search(r'atlas = ExtResource\("([^"]+)"\)', body)
        if rect and atlas:
            poses[id_] = dict(path=external[atlas[1]], region=[int(float(x.strip())) for x in rect[1].split(',')])
    tracks = {}
    for body, _, name, _ in re.findall(r'\{"frames"\s*:\s*\[(.*?)\],\s*"loop"\s*:\s*(true|false),\s*"name"\s*:\s*&"([^"]+)"\s*,\s*"speed"\s*:\s*([0-9.]+)', text, re.S):
        tracks[name] = dict(poses=[poses[id_] for id_ in re.findall(r'SubResource\("([^"]+)"\)', body)])
    return tracks


def audit():
    rows = []
    for name, field in [('review-boss-a/review.json', 'bosses'), ('review-boss-b/review-results.json', 'reviews'), ('review-boss-c/review-results.json', 'actors')]:
        rows += json.loads((EVIDENCE / name).read_text())[field]
    passes = {row['id'] for row in rows if row.get('current_review', row.get('status')) == 'PASS'}
    profiles = json.loads((ROOT / 'data/combat_animation_profiles.json').read_text())['profiles']
    groups, issues, seams, aliases, textures = {}, [], [], [], {}
    for row in rows:
        key = row['id']
        if key in passes:
            continue
        profile = profiles.get(key)
        if not profile:
            issues.append(dict(keys=[key], issue='MISSING_PROFILE'))
            continue
        groups.setdefault(profile.get('frames_path', ''), []).append(key)
    total = 0
    for framepath, keys in groups.items():
        path = ROOT / framepath.removeprefix('res://')
        if not path.is_file():
            issues.append(dict(keys=keys, issue='MISSING_TRES', path=str(path)))
            continue
        tracks = parse(path)
        for key in keys:
            aliases.append(dict(key=key, animation_names=profiles[key].get('animation_names', {})))
            for direction in range(8):
                for role in ['idle', 'attack', 'hit']:
                    track = tracks.get(f'{role}_{direction}')
                    if not track or not track['poses']:
                        issues.append(dict(keys=[key], issue='MISSING_TRACK', track=f'{role}_{direction}', path=framepath))
                if not (tracks.get(f'run_{direction}') or tracks.get(f'walk_{direction}')):
                    issues.append(dict(keys=[key], issue='MISSING_MOVE_TRACK', track=f'run/walk_{direction}', path=framepath))
            if not any(name.startswith('death_') and track['poses'] for name, track in tracks.items()):
                issues.append(dict(keys=[key], issue='MISSING_DEATH', path=framepath))
        for name, track in tracks.items():
            for phase, pose in enumerate(track['poses']):
                total += 1
                texture = pose['path']
                if texture not in textures:
                    source = ROOT / texture.removeprefix('res://')
                    if not source.is_file():
                        issues.append(dict(keys=keys, issue='MISSING_PNG', path=texture))
                        continue
                    textures[texture] = np.asarray(Image.open(source).convert('RGBA'))[:, :, 3]
                alpha = textures[texture]
                height, width = alpha.shape
                x, y, w, h = pose['region']
                if x < 0 or y < 0 or x + w > width or y + h > height or w <= 0 or h <= 0:
                    issues.append(dict(keys=keys, issue='REGION_OUT_OF_BOUNDS', path=framepath, track=name, phase=phase, region=pose['region'], size=[width, height]))
                    continue
                seam = 0
                if x > 0:
                    seam += int(((alpha[y:y+h, x] > 128) & (alpha[y:y+h, x-1] > 128)).sum())
                if x + w < width:
                    seam += int(((alpha[y:y+h, x+w-1] > 128) & (alpha[y:y+h, x+w] > 128)).sum())
                if y > 0:
                    seam += int(((alpha[y, x:x+w] > 128) & (alpha[y-1, x:x+w] > 128)).sum())
                if y + h < height:
                    seam += int(((alpha[y+h-1, x:x+w] > 128) & (alpha[y+h, x:x+w] > 128)).sum())
                if seam >= 5:
                    seams.append(dict(keys=keys, path=framepath, track=name, phase=phase, region=pose['region'], visible_alpha_seam_pixels=seam, texture=texture))
    return dict(bosses=len(rows), reviewed_approved=sum(bool(row.get('approval_preserved')) for row in rows), skipped_PASS=sorted(passes), audited_nonPASS=len(rows)-len(passes), resource_sets=len(groups), unique_texture_files=len(textures), unique_resource_frame_references=total, issues=issues, nonempty_aliases=[row for row in aliases if row['animation_names']], region_seam_suspects_count=len(seams), region_seam_top=sorted(seams, key=lambda row: -row['visible_alpha_seam_pixels'])[:8])


if __name__ == '__main__':
    print(json.dumps(audit(), ensure_ascii=False, indent=2))
