#!/usr/bin/env python3
"""Batch private SPX pack: SHA cache, A3 order/ticks/events and aligned layers.

Output must be outside the checkout. This does not approve art, blending, IDs,
the illustrative tick clock, or a relationship to the fixed 498 game actors.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

from PIL import Image
from spx_decode import decode_spx
from spx_source_actions import parse_entry, children, role_for

ACTORS = {'21624': ['21625', '21626', '21627'], '21653': ['21654', '21655', '21656']}
EFFECTS = ['19521', '19522'] + [str(i) for a, b in [(21916, 21923), (21928, 21933),
           (21951, 21966), (21968, 21971)] for i in range(a, b + 1)]
PREFIX = 'assets/external_spx/source_motion'
CACHE_SCHEMA = 1


def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def decoded(path, cache, expected):
    if not 0 < path.stat().st_size <= 64*1024*1024:
        raise ValueError('SPX source byte budget exceeded: '+path.name)
    digest = sha(path)
    if expected and digest != expected['source_sha256']:
        raise ValueError('Source SHA mismatch: ' + path.name)
    directory = cache / digest
    metadata = directory / 'frames.json'
    if metadata.is_file():
        saved = json.loads(metadata.read_text())
        expected_matches = not expected or (len(saved['frames']) == len(expected['frames']) and all(
            all(f.get(k) == old.get(k) for k in ['index','empty','xy_offset','size','rgba_sha256','source_types'])
            for f,old in zip(saved['frames'],expected['frames'])))
        if (saved.get('schema') == CACHE_SCHEMA and saved.get('source_sha256') == digest
                and expected_matches
                and all((directory / f['image']).is_file() and sha(directory / f['image']) == f['png_sha256']
                        for f in saved['frames'] if f.get('image'))):
            return saved['frames'], directory, True
    directory.mkdir(parents=True, exist_ok=True)
    frames = []
    for index, (meta, image) in enumerate(decode_spx(path.read_bytes())):
        meta['source_sha256'] = digest
        if expected:
            old = expected['frames'][index]
            if meta['xy_offset'] != old['xy_offset'] or meta['size'] != old['size']:
                raise ValueError('Source geometry differs from audit: ' + path.name)
            meta['source_types'] = old['source_types']
        if image is not None:
            rgba_sha = hashlib.sha256(image.tobytes()).hexdigest()
            if expected and rgba_sha != expected['frames'][index].get('rgba_sha256'):
                raise ValueError('RGBA differs from audit: ' + path.name)
            meta['rgba_sha256'] = rgba_sha
            meta['image'] = f'{index:03}.png'
            image.save(directory / meta['image'])
            meta['png_sha256'] = sha(directory / meta['image'])
        frames.append(meta)
    if expected and len(frames) != len(expected['frames']):
        raise ValueError('Record count differs from audit: ' + path.name)
    write_json(metadata, {'schema': CACHE_SCHEMA, 'source_sha256': digest, 'frames': frames})
    return frames, directory, False


class Atlas:
    def __init__(self, dest):
        self.dest = dest
        dest.mkdir(parents=True, exist_ok=True)
        self.page = Image.new('RGBA', (2048, 2048))
        self.x = self.y = self.height = self.used = 0
        self.pages = []

    def flush(self):
        if not self.used:
            return
        name = f'atlas_{len(self.pages):02}.png'
        self.page.crop((0, 0, 2048, self.used)).save(self.dest / name)
        self.pages.append(name)
        self.page = Image.new('RGBA', (2048, 2048))
        self.x = self.y = self.height = self.used = 0

    def add(self, image):
        w, h = image.size
        if w + 2 > 2048 or h + 2 > 2048:
            raise ValueError('Atlas capacity exceeded')
        if self.x + w + 2 > 2048:
            self.x = 0
            self.y += self.height
            self.height = 0
        if self.y + h + 2 > 2048:
            self.flush()
        rect = [self.x + 1, self.y + 1, w, h]
        self.page.paste(image, tuple(rect[:2]))
        result = {'page': len(self.pages), 'rect': rect}
        self.x += w + 2
        self.height = max(self.height, h + 2)
        self.used = max(self.used, self.y + h + 2)
        return result


def emit_frames(layer, actions, direction_map, tick_rate, aliases, only_direction=None):
    frames, pages, bounds = layer['frames'], layer['atlases'], layer['bounds']
    if only_direction is not None:
        needed = {f'{f["sequence_base"]+(direction_map[only_direction] if a["directional"] else 0)}/{f["frame"]}'
                  for a in actions.values() for f in a['frames']}
        frames = {k:dict(v) for k,v in frames.items() if k in needed}
        used = sorted({f['page'] for f in frames.values()})
        pages = ['../'+pages[i] for i in used]
        for f in frames.values(): f['page'] = used.index(f['page'])
    ids = {key: f'F{i}' for i, key in enumerate(frames)}
    w, h = bounds[2] - bounds[0], bounds[3] - bounds[1]
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(ids)+len(pages)+1} format=3]', '']
    lines += [f'[ext_resource type="Texture2D" path="{p}" id="T{i}"]' for i, p in enumerate(pages)]
    for key, meta in frames.items():
        x, y, cw, ch = meta['rect']
        ox, oy = meta['offset']
        lines += ['', f'[sub_resource type="AtlasTexture" id="{ids[key]}"]',
                  f'atlas = ExtResource("T{meta["page"]}")', f'region = Rect2({x}, {y}, {cw}, {ch})',
                  f'margin = Rect2({ox-bounds[0]}, {oy-bounds[1]}, {w-cw}, {h-ch})']
    animations, metadata = [], {}
    for aid, action in actions.items():
        directions = range(8 if action['directional'] else 1) if only_direction is None else [only_direction]
        for direction in directions:
            source_direction = direction_map[direction] if action['directional'] else 0
            records = []
            for frame in action['frames']:
                key = f'{frame["sequence_base"]+source_direction}/{frame["frame"]}'
                if key not in frames:
                    raise ValueError(f'Unresolved frame: {key}')
                records.append((frame, key))
            # Godot requires duration > 0. Zero records remain in events/manifest.
            positive = [(f, key) for f, key in records if f['ticks'] > 0]
            track = ','.join('{"duration":'+str(float(f['ticks']))+',"texture":SubResource("'+ids[key]+'")}'
                             for f, key in positive)
            names = [f'source_action_{aid}_dir_{direction}']
            role = role_for(action['source_name']) if aliases else None
            if role:
                names.append(role + '_' + str(direction))
            for name in names:
                loop = action['source_name'].split()[0] in ['walk', 'runL', 'runR', 'breath']
                animations.append('{"name":&"'+name+'","speed":'+str(tick_rate)+',"loop":'+str(loop).lower()+',"frames":['+track+']}')
                metadata[name] = {'action_id': aid, 'source_direction': source_direction,
                                  'hit_frames': [i for i, (f, key) in enumerate(positive) if f['hit_marker']],
                                  'source_name': action['source_name']}
    lines += ['', '[resource]', 'animations = [' + ',\n'.join(animations) + ']',
              'metadata/twilight_source_tracks = ' + json.dumps(metadata, ensure_ascii=False), '']
    return '\n'.join(lines)


def write_lazy_tracks(output, report):
    """Only text resources; existing pixel atlases are not decoded or rewritten."""
    count = 0
    for section in ['actors', 'effects']:
        for group, entry in report[section].items():
            layers = entry['layers'] if section == 'actors' else [group]
            for aid, action in entry['actions'].items():
                for direction in range(8 if action['directional'] else 1):
                    for layer_id in layers:
                        layer = report['groups'][layer_id]
                        dest = output/PREFIX/layer_id/'tracks'
                        dest.mkdir(parents=True,exist_ok=True)
                        resource = emit_frames(layer,{aid:action},report['direction_map'],report['tick_rate'],False,direction)
                        (dest/f'source_action_{aid}_dir_{direction}.tres').write_text(resource)
                        count += 1
    report['lazy_track_resources'] = count
    write_json(output/'data/external_spx/source_motion.json',report)
    return count


def build(args):
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    if output == root or output.is_relative_to(root):
        raise ValueError('Third-party output must be outside the repository')
    output.mkdir(parents=True, exist_ok=True)
    expected = {Path(x['path']).name: x for x in json.loads(args.audit.read_text())} if args.audit else {}
    text_bytes = args.actions.read_bytes()
    if not b'#21624 ' in text_bytes or b'\0' in text_bytes:
        raise ValueError('Only the supplied plaintext A3 action table is supported')
    text = text_bytes.decode('cp949')
    report = {'schema': 1, 'action_sha256': hashlib.sha256(text_bytes).hexdigest(),
              'tick_rate': args.tick_rate, 'tick_rate_verified': False, 'direction_map': args.direction_map,
              'actors': {}, 'effects': {}, 'groups': {}, 'failures': [], 'cache_hits': 0,
              'decoded_files': 0, 'records': 0, 'nonempty': 0, 'empty': 0,
              'source_id_to_twilight_id': {}, 'skill_bindings': {}, 'redistribution': 'HOLD_NO_PERMISSION'}
    decoded_groups = {}
    for path in sorted(args.source.glob('*.spx')):
        match = re.fullmatch(r'(\d+)-(\d+)\.spx', path.name)
        if not match:
            continue
        group, seq = match.groups()
        try:
            records, cachedir, hit = decoded(path, args.cache, expected.get(path.name))
            decoded_groups.setdefault(group, {})[int(seq)] = (records, cachedir)
            report['cache_hits' if hit else 'decoded_files'] += 1
            report['records'] += len(records)
            report['nonempty'] += sum(not r['empty'] for r in records)
            report['empty'] += sum(r['empty'] for r in records)
        except (ValueError, OSError, IndexError) as error:
            report['failures'].append({'file': path.name, 'reason': str(error)})
    entries = {}
    rgba_counts = Counter((tuple(record['size']),record.get('rgba_sha256'))
                          for sequences in decoded_groups.values() for records,_cache in sequences.values()
                          for record in records if not record['empty'])
    report['unique_RGBA_images'] = len(rgba_counts)
    report['duplicate_RGBA_records'] = sum(count-1 for count in rgba_counts.values())
    report['duplicate_policy'] = 'Identify duplicates; preserve every source record because offset, type and timing can differ'
    for group in decoded_groups:
        try:
            entries[group] = parse_entry(text, group)
        except ValueError as error:
            report['failures'].append({'group': group, 'reason': str(error)})
    for group, sequences in decoded_groups.items():
        try:
            entry = entries.get(group, {})
            atlas = Atlas(output / PREFIX / group)
            frames = {}
            for seq, (records, cachedir) in sequences.items():
                for record in records:
                    image = Image.open(cachedir / record['image']).convert('RGBA') if record.get('image') else Image.new('RGBA', (1, 1))
                    box = image.getbbox() or (0, 0, 1, 1)
                    cropped = image.crop(box)
                    packed = atlas.add(cropped)
                    packed.update(offset=[record['xy_offset'][0]+box[0], record['xy_offset'][1]+box[1]],
                                  empty=record['empty'], source_types=record.get('source_types', []),
                                  original_size=record['size'], original_offset=record['xy_offset'],
                                  alpha_crop=list(box), rgba_sha256=record.get('rgba_sha256'))
                    frames[f'{seq}/{record["index"]}'] = packed
            atlas.flush()
            visible = [f for f in frames.values() if not f['empty']]
            bounds = [min(f['offset'][0] for f in visible), min(f['offset'][1] for f in visible),
                      max(f['offset'][0]+f['rect'][2] for f in visible), max(f['offset'][1]+f['rect'][3] for f in visible)]
            report['groups'][group] = {'frames': frames, 'bounds': bounds, 'attributes': entry.get('attributes', {}),
                'atlases': atlas.pages, 'blend': 'UNVERIFIED', 'source_header': entry.get('source_header', ''),
                'rgba_memory_bytes': sum(Image.open(atlas.dest / p).width * Image.open(atlas.dest / p).height * 4 for p in atlas.pages)}
        except (ValueError, OSError) as error:
            report['failures'].append({'group': group, 'reason': str(error)})
    for body, layer_ids in ACTORS.items():
        try:
            base = report['groups'][body]
            for layer_id in layer_ids:
                layer = report['groups'][layer_id]
                if set(layer['frames']) != set(base['frames']):
                    raise ValueError('Layer/body record mismatch: ' + layer_id)
            # One source-coordinate canvas for every body, shadow and clothing frame.
            layers = [body] + layer_ids
            bs = [report['groups'][i]['bounds'] for i in layers]
            bounds = [min(b[0] for b in bs), min(b[1] for b in bs), max(b[2] for b in bs), max(b[3] for b in bs)]
            for layer_id in layers:
                layer = report['groups'][layer_id]
                layer['bounds'] = bounds
                resource = emit_frames(layer, entries[body]['actions'], args.direction_map, args.tick_rate, True)
                (output / PREFIX / layer_id / 'SpriteFrames.tres').write_text(resource)
            report['actors'][body] = {'layers': layers, 'actions': entries[body]['actions'], 'bounds': bounds,
                                      'identity': 'UNMAPPED', 'blending': 'HOLD', 'reference_validation': 'PASS'}
        except (KeyError, ValueError) as error:
            report['failures'].append({'actor': body, 'reason': str(error)})
    for group in EFFECTS:
        try:
            entry = entries[group]
            owner = group
            if not entry['actions']:
                parents = [g for g in EFFECTS if g in entries and group in children(entries[g])]
                if len(parents) != 1:
                    raise ValueError('No unique effect action owner')
                owner = parents[0]
                entry = entries[owner]
            layer = report['groups'][group]
            resource = emit_frames(layer, entry['actions'], list(range(8)), args.tick_rate, False)
            (output / PREFIX / group / 'SpriteFrames.tres').write_text(resource)
            report['effects'][group] = {'owner': owner, 'layers': [group]+children(entries[group]),
                'actions': entry['actions'], 'resource': f'res://{PREFIX}/{group}/SpriteFrames.tres',
                'reference_validation': 'PASS', 'production_approved': False,
                'blend': 'UNVERIFIED', 'position_basis': 'source coordinate origin; target attachment unverified'}
        except (KeyError, ValueError) as error:
            report['failures'].append({'effect': group, 'reason': str(error)})
    sound_dest = output / 'assets/external_spx/source_sounds'
    sound_dest.mkdir(parents=True, exist_ok=True)
    report['sounds'] = {}
    for source in sorted(args.source.glob('*.ogg')):
        if source.stem not in ['10827', '10828', '10829', '10830']:
            continue
        shutil.copyfile(source, sound_dest / source.name)
        report['sounds'][source.stem] = {'sha256': sha(source), 'path': 'res://assets/external_spx/source_sounds/' + source.name}
    report['missing_sounds'] = ['10831', '10832']
    write_json(output / 'data/external_spx/source_motion.json', report)
    write_lazy_tracks(output,report)
    summary = {k: v for k, v in report.items() if k not in ['groups', 'actors', 'effects']}
    summary.update(spx_files=sum(len(g) for g in decoded_groups.values()), groups=len(decoded_groups),
                   actor_candidates=len(report['actors']), effect_candidates=len(report['effects']))
    write_json(args.report, summary)
    print(json.dumps(summary, ensure_ascii=False))
    return report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--actions', type=Path, required=True)
    p.add_argument('--cache', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--report', type=Path, required=True)
    p.add_argument('--audit', type=Path)
    p.add_argument('--track-resources-only', action='store_true', help='Add lazy text resources to an already pixel-verified pack without rewriting atlases')
    p.add_argument('--tick-rate', type=float, default=24.0)
    p.add_argument('--direction-map', type=lambda s: [int(i) for i in s.split(',')], default=list(range(8)))
    a = p.parse_args()
    if sorted(a.direction_map) != list(range(8)) or not 0 < a.tick_rate <= 240:
        p.error('Explicit permutation of eight source directions and finite positive clock required')
    if a.track_resources_only:
        report = json.loads((a.output/'data/external_spx/source_motion.json').read_text())
        if report['action_sha256'] != sha(a.actions):
            p.error('Source action SHA changed; revalidate first')
        print('LAZY_SOURCE_TRACKS',write_lazy_tracks(a.output,report))
    else:
        build(a)


if __name__ == '__main__':
    main()
