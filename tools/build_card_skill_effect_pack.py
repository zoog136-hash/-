#!/usr/bin/env python3
"""Private source-pixel addon; reuse PR217 SPR/SP2 readers, never guess directions."""
import argparse, hashlib, importlib, json, pathlib, sys, zlib


def build(args):
    sys.path.insert(0, str(args.source_tools))
    spr = importlib.import_module('original_spr')
    sp2 = importlib.import_module('original_sp2')
    declarations = spr.read(args.spr_root.glob('*.spr'))
    source = json.loads(args.catalog.read_text())
    files = {}
    for root in args.sp2_root:
        manifest = json.loads((root / 'input_manifest.json').read_text())
        for asset in manifest['assets']:
            name = asset.get('member', asset.get('original_inner_path', ''))
            path = root / name
            if not name.endswith('.sp2') or not path.is_file():
                continue
            raw = path.read_bytes()
            if len(raw) != asset['bytes'] or hashlib.sha256(raw).hexdigest() != asset['sha256']:
                raise ValueError('Source size/SHA mismatch: ' + name)
            if f'{zlib.crc32(raw):08x}' != asset['crc32']:
                raise ValueError('Source CRC mismatch: ' + name)
            if pathlib.Path(name).name in files and files[pathlib.Path(name).name].read_bytes() != raw:
                raise ValueError('Conflicting source member: ' + name)
            files[pathlib.Path(name).name] = path
    index = json.loads(args.base_manifest.read_text()) if args.base_manifest else {
        'schema': 1, 'mode': 'literal_body_shadow_inspection_only',
        'source_snapshot': 'base508', 'records': {}}
    index.setdefault('source_spell_bindings', {}).update({k: v['source_spell'] for k, v in source['spells'].items()})
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'pixels').mkdir(exist_ok=True)
    (args.output / 'overlays').mkdir(exist_ok=True)
    results = []
    for sid in args.sprite_id:
        owner, actions = spr.resolve(declarations, sid)
        if len(actions) != 1 or spr.resolve_references(declarations, sid):
            results.append({'sprite_id': sid, 'status': 'action_or_attachment_pending'})
            continue
        action = next(iter(actions.values()))
        if action['errors']:
            raise ValueError(action['errors'])
        decoded, pixels, directions, missing = {}, {}, [], []
        for direction in range(8):
            frames = []
            for group, frame, ticks in action['tokens']:
                chunk, bit = spr.frame_address(group, direction, action['declared_flag'])
                name = f'{owner}-{chunk}.sp2'
                if name not in files:
                    missing.append({'direction': direction, 'member': name, 'reason': 'member_not_installed'})
                    frames = []
                    break
                if name not in decoded:
                    decoded[name] = sp2.parse(files[name].read_bytes())
                palette, mask, stored, _ = decoded[name]
                bits = [b for b in range(8) if mask & (1 << b)]
                if bit not in bits:
                    missing.append({'direction': direction, 'member': name, 'bit': bit, 'reason': 'stored_direction_absent_no_mirror_assumption'})
                    frames = []
                    break
                frame_headers, blocks = stored[bits.index(bit)]
                if frame >= len(frame_headers):
                    raise ValueError('Source frame outside stored range')
                key = (chunk, bit, frame)
                if key not in pixels:
                    image, offset = sp2.render(palette, frame_headers, blocks, frame)
                    relative = f'pixels/{owner}-{chunk}-{bit}-{frame}.png'
                    image.save(args.output / relative)
                    pixels[key] = {'path': relative, 'offset': list(offset), 'layer_id': owner,
                                   'pixel_size': list(image.size), 'source_bounds': frame_headers[frame][0],
                                   'sha256': hashlib.sha256((args.output / relative).read_bytes()).hexdigest()}
                frames.append({'duration': ticks / action['fps'] if action['fps'] else None,
                               'source_ticks': ticks, 'source_group': group, 'physical_group': chunk,
                               'stored_direction_bit': bit, 'source_frame': frame, 'layers': [pixels[key]]})
            directions.append(frames)
        if not any(directions):
            results.append({'sprite_id': sid, 'status': 'source_address_pending', 'missing': missing})
            continue
        attributes = [r['body'] for d in declarations[owner] for r in d.directives if r['code'] == 104]
        record = {'source_sprite_id': sid, 'body_id': owner, 'source_attributes': attributes,
                  'one_shot_overlay': True, 'card_skill_partial_overlay': bool(missing),
                  'source_available_directions': [i for i, d in enumerate(directions) if d],
                  'source_missing_directions': missing, 'source_file_sha256': {
                      name: hashlib.sha256(files[name].read_bytes()).hexdigest() for name in decoded},
                  'tracks': {'idle': {'fps': action['fps'], 'source_timing_provenance': action['fps_provenance'],
                      'source_action_id': action['code'], 'source_action': action['name'], 'source_sprite_id': sid,
                      'source_raw_body': action['raw_body'], 'source_annotations': action['source_annotations'],
                      'timing_issues': action['errors'], 'static_pending_timing': action['fps'] is None,
                      'directions': directions, 'loop': False}},
                  'compatibility_semantics': 'Existing host direction(+3), blend and unresolved-clock policy; not verified M travel/server timing'}
        relative = f'overlays/{sid}.json'
        (args.output / relative).write_text(json.dumps(record, ensure_ascii=False, separators=(',', ':')))
        index['records'][f'overlay:{sid}'] = {'manifest': relative}
        results.append({'sprite_id': sid, 'status': 'partial_source_directions' if missing else 'source_overlay',
                        'pixels': len(pixels), 'missing': missing})
    (args.output / 'manifest.json').write_text(json.dumps(index, ensure_ascii=False, separators=(',', ':')))
    (args.output / 'card_skill_effect_status.json').write_text(json.dumps(results, indent=2))
    print(json.dumps(results))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-tools', type=pathlib.Path, required=True)
    p.add_argument('--spr-root', type=pathlib.Path, required=True)
    p.add_argument('--sp2-root', type=pathlib.Path, action='append', required=True)
    p.add_argument('--catalog', type=pathlib.Path, required=True)
    p.add_argument('--output', type=pathlib.Path, required=True)
    p.add_argument('--base-manifest', type=pathlib.Path)
    p.add_argument('--sprite-id', type=int, action='append', required=True)
    build(p.parse_args())
