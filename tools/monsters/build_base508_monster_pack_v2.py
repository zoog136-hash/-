"""Build private monster body/shadow tracks from exact original SP2 bytes.

No generated/composited/resampled pixels or invented native FPS. The shared
runtime playback policy labels any host compatibility clock explicitly.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lineagem_original'))
import original_sp2
import original_spr

ROLES = {'idle': 3, 'walk': 0, 'attack': 1, 'hit': 2, 'death': 8}

def build(inputs, spr_root, output, selections):
    declarations = original_spr.read(spr_root.glob('*.spr'))
    output.mkdir(parents=True, exist_ok=True)
    pixels = {}; decoded = {}; files = {}; records = {}; models = {}
    for selection in selections:
        if 'spawn_view_id' not in selection: continue
        sid = selection['sprite_id']
        if sid in models:
            previous = models[sid]
            records[str(selection['npc_id'])] = {**{key:selection[key] for key in ('npc_id','sprite_id','spawn_view_id','territory_link_id','land_id')}, 'source_contexts':selection.get('source_contexts',[selection]), **previous}
            continue
        body, actions = original_spr.resolve(declarations, sid)
        refs = original_spr.resolve_references(declarations, sid)
        if any(not ref.get('count_valid', True) for items in refs.values() for ref in items): raise ValueError((sid, 'unresolved source reference count'))
        clothes = [original_spr.resolve(declarations, target)[0] for ref in refs.get('clothes', []) for target in ref['targets']]
        shadows = [original_spr.resolve(declarations, target)[0]
                   for ref in refs.get('shadow', []) for target in ref['targets']]
        if len(shadows) > 1: raise ValueError((sid, 'ambiguous shadow scope'))
        layer_ids = shadows + [body] + clothes
        attributes = {layer: [d["body"] for decl in declarations.get(layer, []) for d in decl.directives if d["code"] == 104] for layer in layer_ids}
        tracks = {}
        for role, code in ROLES.items():
            if code not in actions: raise ValueError((sid, role, 'original action missing'))
            action = actions[code]
            if action['errors']: raise ValueError((sid, role, action['errors']))
            directions = []
            for direction in range(8):
                frames = []
                for source_group, frame, ticks in action['tokens']:
                    group, bit = original_spr.frame_address(source_group, direction, action['declared_flag'])
                    layers = []
                    for layer in layer_ids:
                        name = f'{layer}-{group}.sp2'
                        if name not in decoded:
                            path = inputs / 'Sprite' / name
                            raw = path.read_bytes()
                            decoded[name] = original_sp2.parse(raw)
                            files['Sprite/' + name] = {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
                        palette, mask, stored, _ = decoded[name]
                        bits = [value for value in range(8) if mask & (1 << value)]
                        if bit not in bits: raise ValueError((name, bit, mask))
                        fs, blocks = stored[bits.index(bit)]
                        if frame >= len(fs): raise ValueError((name, frame, len(fs)))
                        key = (layer, group, bit, frame)
                        if key not in pixels:
                            image, offset = original_sp2.render(palette, fs, blocks, frame)
                            relative = f'pixels/{layer}-{group}-{bit}-{frame}.png'
                            target = output / relative
                            target.parent.mkdir(exist_ok=True)
                            image.save(target)
                            pixels[key] = {'path': relative, 'offset': list(offset), 'layer_id': layer, 'pixel_size': list(image.size),
                                           'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}
                            image.close()
                        layers.append({**pixels[key], "relation": "SPR105.clothes" if layer in clothes else ("SPR101.shadow" if layer in shadows else "body"), "source_attributes": attributes[layer]})
                    frames.append({'source_ticks': ticks, 'source_frame': frame, 'source_group': source_group,
                                   'layers': layers})
                directions.append(frames)
            tracks[role] = {'fps': action['fps'], 'source_sprite_id': sid, 'source_body_id': body,
                            'source_action_id': code, 'source_raw_body': action['raw_body'],
                            'source_timing_provenance': action.get('fps_provenance'),
                            'timing_issues': action['errors'], 'loop': role in ('idle', 'walk'),
                            'directions': directions}
        shared = {'source_sprite_id':sid,'body_id':body,'shadow_ids':shadows,'clothes_ids':clothes,'tracks':tracks}
        relative = f'actors/{sid}.json'
        target = output / relative
        target.parent.mkdir(exist_ok=True)
        target.write_text(json.dumps(shared,ensure_ascii=False,separators=(',',':'))+'\n')
        models[sid] = {'tracks_ref':relative,'tracks_sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
        records[str(selection['npc_id'])] = {**{key:selection[key] for key in ('npc_id','sprite_id','spawn_view_id','territory_link_id','land_id')},'source_contexts':selection.get('source_contexts',[selection]),**models[sid]}
        print(json.dumps({'npc_id':selection['npc_id'],'sprite_id':sid,'models':len(models),'pixels':len(pixels)}),flush=True)
    result = {'schema': 1, 'kind': 'base508_monster_pack', 'source_snapshot': 'base508',
              'records': records, 'source_files': files,
              'direction_policy': 'Host facing +3 to stored source direction, same explicit compatibility mapping as source preview; native cardinal semantics unverified.',
              'composition_policy': 'Source body/shadow/clothes remain separate exact pixels and offsets. Clothing uses shared explicit host-compatible attrs8/add, attrs128/half-alpha; native M equations and ordering remain unverified.',
              'clock_policy': 'Use shared source_playback_policy; missing native FPS remains null, host compatible clocks remain labeled.',
              'counts': {'npc_records': len(records), 'png_files': len(pixels), 'original_sp2_files_used': len(files), 'unique_sprite_models': len(models)}}
    (output / 'manifest.json').write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(json.dumps(result['counts']))
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('inputs', 'spr-root', 'output', 'requests'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--npc-ids', help='Optional comma-separated source IDs; otherwise all reviewed selections')
    args = parser.parse_args()
    selections = json.loads(args.requests.read_text())['selections']
    if args.npc_ids:
        wanted = {int(value) for value in args.npc_ids.split(',')}
        selections = [row for row in selections if row['npc_id'] in wanted]
        if {row['npc_id'] for row in selections} != wanted: raise ValueError('Requested source context missing')
    build(args.inputs, args.spr_root, args.output, selections)
