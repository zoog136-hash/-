#!/usr/bin/env python3
"""Private source-pixel addon; reuse PR217 SPR/SP2 readers, never guess directions."""
import argparse, hashlib, importlib, json, pathlib, re, sys, tempfile, zipfile, zlib


def read_declarations(spr, root, required):
    """Recover only exact requested headers joined after a literal '?' delimiter.

    The shared reader expects line starts. Slice original bytes without changing
    them; retain original offsets, source hashes and line numbers for auditing.
    """
    paths = sorted(root.glob('*.spr'))
    declarations = spr.read(paths)
    recovered = {}
    for sid in sorted(set(required) - declarations.keys()):
        pattern = re.compile(rb'\?#' + str(sid).encode() + rb'\s+\d+(?:=\d+)?(?=[ \t\r\n])')
        matches = []
        for path in paths:
            raw = path.read_bytes()
            for match in pattern.finditer(raw):
                start = match.start() + 1
                following = re.search(rb'#\d+\s+\d+(?:=\d+)?(?=[ \t\r\n])', raw[start + 1:])
                end = start + 1 + following.start() if following else len(raw)
                matches.append((path, raw, start, end))
        if len(matches) != 1:
            continue
        path, raw, start, end = matches[0]
        payload = raw[start:end]
        original_line = raw[:start].count(b'\n') + 1
        with tempfile.TemporaryDirectory(prefix='twilight-spr-source-slice-') as folder:
            sliced = pathlib.Path(folder) / path.name
            sliced.write_bytes(payload)
            parsed = spr.read([sliced])
        if set(parsed) != {sid} or len(parsed[sid]) != 1:
            raise ValueError('Ambiguous inline source declaration slice')
        declaration = parsed[sid][0]
        declaration.source_line += original_line - 1
        for action in declaration.actions.values():
            action['source_line'] += original_line - 1
            if action.get('fps_provenance'):
                action['fps_provenance']['source_line'] += original_line - 1
        for directive in declaration.directives:
            directive['line'] += original_line - 1
        declarations[sid] = [declaration]
        recovered[sid] = {'source_file': path.name, 'source_line': original_line,
            'byte_start': start, 'byte_end': end,
            'source_file_sha256': hashlib.sha256(raw).hexdigest(),
            'exact_slice_sha256': hashlib.sha256(payload).hexdigest(),
            'method': 'literal_requested_header_after_questionmark; original_bytes_unchanged'}
    return declarations, recovered


def build(args):
    sys.path.insert(0, str(args.source_tools))
    spr = importlib.import_module('original_spr')
    sp2 = importlib.import_module('original_sp2')
    declarations, recovered = read_declarations(spr, args.spr_root, args.sprite_id)
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
    cached = {}
    if args.cached_zip:
        contract = json.loads(args.input_index.read_text())
        expected = {r['file_name']: r['sha256'] for r in contract['combat_existing_payload_ZIPs']}
        for path in args.cached_zip:
            if hashlib.sha256(path.read_bytes()).hexdigest() != expected[path.name]:
                raise ValueError('Cached Library ZIP hash mismatch')
            archive = zipfile.ZipFile(path)
            for name in archive.namelist():
                if name.startswith('Sprite/') and name.endswith('.sp2'):
                    cached.setdefault(pathlib.Path(name).name, (archive, name))
    def raw_member(name):
        if name in files:
            return files[name].read_bytes()
        archive, member = cached[name]
        return archive.read(member)  # ZIPReader verifies this exact member CRC.
    index = json.loads(args.base_manifest.read_text()) if args.base_manifest else {
        'schema': 1, 'mode': 'literal_body_shadow_inspection_only',
        'source_snapshot': 'base508', 'records': {}}
    index.setdefault('source_spell_bindings', {}).update({k: v['source_spell'] for k, v in source['spells'].items()})
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'pixels').mkdir(exist_ok=True)
    (args.output / 'overlays').mkdir(exist_ok=True)
    results = []
    for sid in args.sprite_id:
        try:
            owner, actions = spr.resolve(declarations, sid)
        except ValueError as error:
            results.append({'sprite_id': sid, 'status': 'source_declaration_pending', 'reason': str(error)})
            continue
        if len(actions) != 1:
            results.append({'sprite_id': sid, 'status': 'action_or_attachment_pending'})
            continue
        refs = spr.resolve_references(declarations, sid)
        shadows = [target for ref in refs.get('shadow', []) for target in ref['targets']]
        clothes = [target for ref in refs.get('clothes', []) for target in ref['targets']]
        if len(shadows)>1 or any(not r.get('count_valid', True) for values in refs.values() for r in values):
            results.append({'sprite_id': sid, 'status': 'ambiguous_source_attachment_pending', 'references': refs})
            continue
        action = next(iter(actions.values()))
        if action['errors']:
            raise ValueError(action['errors'])
        decoded, pixels, directions, missing, missing_layers = {}, {}, [], [], []
        def layer(original_id, chunk, bit, frame, relation):
            physical = spr.resolve(declarations, original_id)[0] if original_id in declarations else original_id
            name = f'{physical}-{chunk}.sp2'
            if name not in files and name not in cached:
                raise ValueError('member_not_installed:' + name)
            if name not in decoded:
                decoded[name] = sp2.parse(raw_member(name))
            palette, mask, stored, _ = decoded[name]
            bits = [b for b in range(8) if mask & (1 << b)]
            if bit not in bits:
                raise ValueError('stored_direction_absent_no_mirror_assumption:' + name)
            frame_headers, blocks = stored[bits.index(bit)]
            if frame >= len(frame_headers):
                raise ValueError('source_frame_outside_stored_range:' + name)
            key = (physical, chunk, bit, frame)
            if key not in pixels:
                image, offset = sp2.render(palette, frame_headers, blocks, frame)
                relative = f'pixels/{physical}-{chunk}-{bit}-{frame}.png'
                image.save(args.output / relative)
                pixels[key] = {'path': relative, 'offset': list(offset), 'layer_id': original_id,
                    'pixel_size': list(image.size), 'source_bounds': frame_headers[frame][0],
                    'sha256': hashlib.sha256((args.output / relative).read_bytes()).hexdigest()}
            value = dict(pixels[key])
            value['layer_id'] = original_id
            if relation == 'clothes':
                value['source_attributes'] = [r['body'] for d in declarations.get(original_id, declarations.get(physical, [])) for r in d.directives if r['code'] == 104]
                value['blend_status'] = 'existing_shared_compatibility_policy_not_verified_M'
            return value
        for direction in range(8):
            frames = []
            for group, frame, ticks in action['tokens']:
                chunk, bit = spr.frame_address(group, direction, action['declared_flag'])
                name = f'{owner}-{chunk}.sp2'
                if name not in files and name not in cached:
                    missing.append({'direction': direction, 'member': name, 'reason': 'member_not_installed'})
                    frames = []
                    break
                if name not in decoded:
                    decoded[name] = sp2.parse(raw_member(name))
                palette, mask, stored, _ = decoded[name]
                bits = [b for b in range(8) if mask & (1 << b)]
                if bit not in bits:
                    missing.append({'direction': direction, 'member': name, 'bit': bit, 'reason': 'stored_direction_absent_no_mirror_assumption'})
                    frames = []
                    break
                frame_headers, blocks = stored[bits.index(bit)]
                if frame >= len(frame_headers):
                    raise ValueError('Source frame outside stored range')
                body_layer = layer(owner, chunk, bit, frame, 'body')
                frame_layers, effect_layers = [], []
                for relation, targets in [('shadow', shadows), ('clothes', clothes)]:
                    for target in targets:
                        try:
                            value = layer(target, chunk, bit, frame, relation)
                            (effect_layers if relation == 'clothes' else frame_layers).append(value)
                        except ValueError as error:
                            missing_layers.append({'sprite_id': target, 'relation': relation, 'chunk': chunk,
                                                   'bit': bit, 'frame': frame, 'reason': str(error)})
                frame_layers.append(body_layer)
                frames.append({'duration': ticks / action['fps'] if action['fps'] else None,
                               'source_ticks': ticks, 'source_group': group, 'physical_group': chunk,
                               'stored_direction_bit': bit, 'source_frame': frame, 'layers': frame_layers,
                               'effect_layers': effect_layers})
            directions.append(frames)
        if not any(directions):
            results.append({'sprite_id': sid, 'status': 'source_address_pending', 'missing': missing})
            continue
        attributes = [r['body'] for d in declarations[owner] for r in d.directives if r['code'] == 104]
        record = {'source_sprite_id': sid, 'body_id': owner, 'source_attributes': attributes,
                  'source_declaration_recovery': recovered.get(sid, {}),
                  'one_shot_overlay': True, 'card_skill_partial_overlay': bool(missing),
                  'source_available_directions': [i for i, d in enumerate(directions) if d],
                  'source_missing_directions': missing, 'source_missing_attachments': missing_layers,
                  'source_references': refs, 'source_file_sha256': {
                      name: hashlib.sha256(raw_member(name)).hexdigest() for name in decoded},
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
                        'pixels': len(pixels), 'missing': missing, 'missing_attachments': missing_layers,
                        'source_visual_complete': not missing and not missing_layers})
    (args.output / 'manifest.json').write_text(json.dumps(index, ensure_ascii=False, separators=(',', ':')))
    index['card_skill_effect_readiness'] = {str(r['sprite_id']): {
        'status': r['status'], 'source_visual_complete': r.get('source_visual_complete', False),
        'missing_attachment_members': sorted({x['reason'].split(':', 1)[1] for x in r.get('missing_attachments', []) if x['reason'].startswith('member_not_installed:')})}
        for r in results}
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
    p.add_argument('--cached-zip', type=pathlib.Path, action='append', default=[])
    p.add_argument('--input-index', type=pathlib.Path)
    p.add_argument('--sprite-id', type=int, action='append', required=True)
    build(p.parse_args())
