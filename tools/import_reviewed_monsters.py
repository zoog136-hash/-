#!/usr/bin/env python3
"""Build an approved batch from its pinned, read-only source package.

No executables, spawn edits, source timing conversion or anatomical foot claims.
The package's standalone decoder and strict resolver are required inputs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

BATCHES = {
    'late-judges-v2': ({'45955', '45956', '45957', '45958', '45959', '45960', '45961', '45962'}, 'OFFLINE_PROVISIONAL_NEW_NAMED_NPC_IDENTITY_SUPPORTED', 'libfile_3c2a6bb073ec8191a56ce653c00614a7', 'ae8a0cf693d39a41980f0780c3382c372ec0c898e491fb928d5729b159f4d24e'),
    'mythic-pair-v2': ({'46066', '46067'}, 'APPROVED_FOR_MYTHIC_PAIR_SOURCE_CATALOG_BATCH_AT_CURRENT_318_SNAPSHOT', 'libfile_505e33192e4881918007d14f2f53c97e', '9b3109cdecc69709756947c7a231675b7baba21bbcf2b6b05847583518dfdfa7'),
    'small-base-pair-v2': ({'45166', '45153'}, 'OFFLINE_SEMANTIC_IDENTITY_SUPPORTED_EXPLICIT_BASE_AND_ATTACHMENTS', 'libfile_e12aeb2adf4881918b9d65f62ccba52f', 'ea9c93465e699c42d213432e908341768b75bc48a341ebf1ff8372c900e6547e'),
    'dragon-45681-v2': ({'45681'}, 'OFFLINE_PROVISIONAL_NEW_NAMED_IDENTITY_REVIEWED', 'libfile_a72ddb6420c48191a7d01f1cc4a3d51a', '5a02b01e0b52af6488f1d22866c4f6d01b4313a6cedfba643285c7f654c7d4a2'),
    'dragon-45682-v2': ({'45682'}, 'OFFLINE_PROVISIONAL_NEW_NAMED_IDENTITY_REVIEWED', 'libfile_4fda6b1f86688191bbcee8a4adb23d87', 'b2635d17897fd316380ef0b055f17aae35788b817ab60dcc320d97394ff10bdb'),
    'dragon-45683-v2': ({'45683'}, 'OFFLINE_PROVISIONAL_NEW_NAMED_IDENTITY_REVIEWED', 'libfile_657c1f6e385881919e52b01649c5d205', 'fa49611f612451e4e16b2d53df45d5a86096d1367271f64edc5f359a8440378b'),
    'dragon-45684-v2': ({'45684'}, 'OFFLINE_PROVISIONAL_NEW_NAMED_IDENTITY_REVIEWED', 'libfile_e1e9546a5c8081918aef2dd72d956174', '96895231fdfbd6257a83fb26baa104c0895ba5a3569aef5d70a32d8974a8519e'),
    'late-named-seven-v2': ({'46025', '46026', '46037', '81163', '97068', '45941', '45943'}, 'OFFLINE_PROVISIONAL_NEW_NAMED_IDENTITY_REVIEWED', 'libfile_bb447fd15b40819189f754612620535f', '6e5a0843796ca33263fdc4ec662910185099bb7c23f9b13b0f430947210d89ca'),
    'late-second-v2': ({'46048', '95001', '46065', '97097', '46113', '95002', '95004', '95008', '95010', '95014', '95016', '95018'}, 'APPROVED_FOR_LATE_SECOND_SOURCE_CATALOG_BATCH_AT_CURRENT_318_SNAPSHOT', 'libfile_3e5439e8299c819188d9004a19fd1c09', '758401f7201f006fa49a8ce9141464fb519b3e2dfd05fe0cfa7e418f7da45c48'),
    'second-middle-v2': ({'45413', '45625', '45685', '45675', '45585', '45548'}, 'PROVISIONAL_OFFLINE_IDENTITY_REVIEW_ONLY_CURRENT318_NO_EXTERNAL_APPLY_AUTHORITY', 'libfile_0eccfa5a93e88191811c64d5e1e3f8e4', '2795b16974a713e2ee4d3dd02ad46c15edcca4b9f9374517b3f093f2d6f95c43'),
    'elder-stonegolem': ({'45215', '45126'}, 'APPROVED_CURRENT318_MONSTER_ELDER_STONEGOLEM_REVIEW', 'libfile_84c31724ae048191b941388563ccb9d1', '01310d070ca86b94bcf0218c091de6c8d351fadf80dddb90cf2939820c8cc4fd'),
    'third-middle-v2': ({'45777', '45504', '45588', '45602', '45612', '45574', '45646', '45539'}, 'PROVISIONAL_OFFLINE_NAMED_IDENTITY_REVIEW_ONLY_CURRENT318_NO_EXTERNAL_APPLY_AUTHORITY', 'libfile_23840498219c8191aa4cc787a0ccc2c4', '275882200f7dbbf1f66a5bc1ef24379144c9c070231f8f404c360c264804118a'),
    'fourth-middle-v2': ({'45615', '45671'}, 'PROVISIONAL_OFFLINE_NAMED_IDENTITY_REVIEW_ONLY_CURRENT318_NO_EXTERNAL_APPLY_AUTHORITY', 'libfile_01294ff808508191a7b50af246b0d699', 'c00bce5cad7df86339c8cc6f0644147633bcf4b62f7e1ff02f4a67760c25d6a1'),
    'early-thirteen': ({'45027', '45280', '45213', '45088', '45160', '45235', '45257', '45258', '45279', '45285', '45295', '45296', '45299'}, 'APPROVED_CURRENT318_MONSTER_EARLY_THIRTEEN_REVIEW', 'libfile_31681f02720481918c47d2ee1a8d35c9', '7e6908a3270d26e643296c55541b1099ecf103b87dfeec19fb241879957e8695'),
    'middle-twelve': ({'45557', '45726', '45734', '45745', '45750', '45752', '45648', '45651', '45680', '45676', '45677', '45678'}, 'APPROVED_CURRENT318_MONSTER_MIDDLE_TWELVE_REVIEW', 'libfile_b49130bface88191a33ba3e982c438bf', '14b06b0b45a6fe5c57c04d3902bfbc83e6c19a5091814a396dfbf6387f264908'),
    'first-four': ({'45006', '45023', '45060', '45097'}, 'APPROVED_CURRENT318_FIRST_FOUR_REVIEW', 'libfile_67387d64c4608191a75145a6e7d565dd', '53098d67e768cff1b90ee2208825eb1a3bf7a4f455d0d3a4ed769ee027ba61bb'),
    'next-nine': ({'45010', '45015', '45029', '45039', '45040', '45044', '45048', '45055', '45077'}, 'APPROVED_CURRENT318_NEXT_NINE_REVIEW', 'libfile_4f5261c43d44819196c42c6e8035738b', '009c1defbb2bbb53c6105373ef1fcd310f81caceff6af2058fe2f56088555042'),
    'next-thirteen': ({'45041', '45192', '45147', '45116', '45083', '45089', '45321', '45154', '45172', '45195', '45214', '45246', '45249'}, 'APPROVED_CURRENT318_MONSTER_NEXT_THIRTEEN_REVIEW', 'libfile_60f80ab18ef88191935fb5d806cd91d1', '54106d786b5803c1c056f7a1d71b875f00745c6a767e57b90af7baedeb4bfa95'),
    'late-ten': ({'45322', '45375', '45549', '46042', '46044', '81159', '81368', '46107', '46109', '46115'}, 'APPROVED_CURRENT318_MONSTER_LATE_TEN_REVIEW', 'libfile_1a0ccf59ac108191923ecbc79636e576', 'becfbeb2d8fdc58971d8a6d767d9f863cb4c793fb568babfe764c6d6d6ac7a63'),
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def build(package, root, allow_heading0_reuse, batch):
    # Check the producer inventory before importing or executing decoder code.
    inventory = json.loads((package / 'package_files.json').read_text())
    for item in inventory['files']:
        relative = Path(item['path'])
        assert not relative.is_absolute() and '..' not in relative.parts
        data = (package / relative).read_bytes()
        assert len(data) == item['bytes'] and sha(data) == item['sha256'], relative
    sys.path[:0] = [str(package), str(package / 'decoder')]
    from package_reader import Package
    from spr_decode import Sprite
    from PIL import Image
    pkg = Package(package)
    first = batch == 'first-four'
    expected, approval, library_id, package_sha = BATCHES[batch]
    candidates = [c for c in pkg.candidates if c['import_enabled']]
    assert {c['source_npc_id'] for c in candidates} == expected
    output = {'schema': 1, 'package_library_id': 'libfile_67387d64c4608191a75145a6e7d565dd',
              'package_sha256': '53098d67e768cff1b90ee2208825eb1a3bf7a4f455d0d3a4ed769ee027ba61bb',
              'heading_policy': 'Visual review: E,SE,S,SW,W,NW,N,NE use source slots 3,4,5,6,7,0,1,2. Sparse tracks explicitly reuse slot0.',
              'timing_policy': 'Local presentation 8fps; raw source durations retained, units unverified. Existing gameplay clocks unchanged.',
              'anchor_is_foot': False, 'attachment_composition': 'body only; shadow/clothes preserved in input package, composition unverified',
              'records': [], 'assets': {}}
    manifest_path = root / 'data/monsters/reviewed_source_monsters.json'
    record_order = {}
    if first and manifest_path.exists():
        prior = json.loads(manifest_path.read_text())
        if any(r['source_npc_id'] not in expected for r in prior['records']):
            raise ValueError('Refusing to overwrite another approved batch with a first-four-only rebuild')
    if not first:
        output = json.loads(manifest_path.read_text())
        record_order = {r['source_npc_id']: index for index, r in enumerate(output['records'])}
        # Preserve prior identities and files byte-for-byte; replacing only this
        # same pinned batch makes a repeated build idempotent.
        output['records'] = [r for r in output['records'] if r['source_npc_id'] not in expected]
        assert {r['source_npc_id'] for r in output['records']} <= set().union(*(b[0] for b in BATCHES.values()))
        assert BATCHES['first-four'][0] <= {r['source_npc_id'] for r in output['records']}
        for filename, digest in output['assets'].items():
            assert sha((root / filename).read_bytes()) == digest
        packages = output.setdefault('packages', [{'library_id': output['package_library_id'], 'sha256': output['package_sha256'], 'batch': 'first-four'}])
        current = {'library_id': library_id, 'sha256': package_sha, 'batch': batch}
        previous = [p for p in packages if p['batch'] == batch]
        assert not previous or previous == [current]
        if not previous: packages.append(current)
    for c in candidates:
        assert c['identity_approval'] == approval
        ident = c['proposed_game_id']
        directory = root / 'assets/monsters/reviewed_source' / ident
        directory.mkdir(parents=True, exist_ok=True)
        binding = pkg.bindings[c['binding_id']]
        assert binding['binding_id'] == c['binding_id']
        assert binding['import_enabled']
        if batch.endswith('-v2'):
            assert binding['source_gfxid'] == int(c['source_raw_fields']['gfxid'])
            assert binding['explicit_resolved_body_prefix'] == binding['body_model_prefix']
        codes = {a['code'] for a in binding['actions']}
        own_idle = 3 if 3 in codes and c['source_npc_id'] != '45060' else 0
        assert own_idle in codes
        roles = {'idle': own_idle, 'walk': 0 if 0 in codes else own_idle,
                 'run': 0 if 0 in codes else own_idle, 'attack': 1 if 1 in codes else own_idle,
                 'hit': 2 if 2 in codes else own_idle, 'death': 8 if 8 in codes else own_idle}
        tracks, sprites = {}, {}
        for role, code in roles.items():
            action = next(a for a in binding['actions'] if a['code'] == code)
            for facing in range(8):
                refs = [pkg.resolve(c['binding_id'], code, step, (facing + 3) % 8,
                                    allow_heading0_reuse) for step in range(len(action['references']))]
                for r in refs:
                    if r['blob_sha256'] not in sprites:
                        raw = Path(r['blob_path']).read_bytes()
                        assert sha(raw) == r['blob_sha256']
                        sprites[r['blob_sha256']] = Sprite(raw)
                tracks[f'{role}_{facing}'] = refs
        bounds = [s.file_bounds() for s in sprites.values()]
        canvas = (min(b[0] for b in bounds), min(b[1] for b in bounds),
                  max(b[2] for b in bounds), max(b[3] for b in bounds))
        width, height = canvas[2] - canvas[0], canvas[3] - canvas[1]
        frames, unique, mapping, transparent = [], {}, {}, []
        for track, refs in tracks.items():
            indices = []
            for r in refs:
                key = (r['blob_sha256'], r['frame_index'])
                if key not in unique:
                    im, _ = sprites[key[0]].render(key[1], canvas_bounds=canvas)
                    # Some source timelines intentionally contain empty poses
                    # (burrowing/disappearance). Preserve them, never clamp to
                    # a visible neighbour or substitute another creature.
                    if im.getbbox() is None: transparent.append(len(frames))
                    unique[key] = len(frames)
                    frames.append(im)
                indices.append(unique[key])
            mapping[track] = indices
        # Keep original pixel cells and shared origin; never downsample a large
        # dragon to fit a GPU texture. Page atlases below 8192 on either axis.
        assert width <= 8192 and height <= 8192
        columns = min(16, 8192 // width)
        per_page = columns * (8192 // height)
        page_count = (len(frames) + per_page - 1) // per_page
        page_names = []
        for page in range(page_count):
            start = page * per_page
            count = min(per_page, len(frames) - start)
            atlas = Image.new('RGBA', (width * columns, height * ((count + columns - 1) // columns)))
            for local, im in enumerate(frames[start:start + count]):
                atlas.paste(im, ((local % columns) * width, (local // columns) * height))
            filename = 'atlas.png' if page_count == 1 else f'atlas_{page:03d}.png'
            atlas.save(directory / filename)
            page_names.append(filename)
        frames[mapping['idle_2'][0]].save(directory / 'portrait.png')
        prefix = 'res://' + directory.relative_to(root).as_posix()
        tres = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(frames) + page_count + 1)]
        for page, filename in enumerate(page_names):
            tres.append('[ext_resource type="Texture2D" path="%s/%s" id="%d"]' % (prefix, filename, page + 1))
        for i in range(len(frames)):
            page, local = divmod(i, per_page)
            tres.extend(['[sub_resource type="AtlasTexture" id="F%d"]' % i,
                         'atlas = ExtResource("%d")' % (page + 1),
                         'region = Rect2(%d, %d, %d, %d)' % ((local % columns) * width, (local // columns) * height, width, height),
                         'metadata/source_frame_index = %d' % i])
        animations = []
        for track, indices in mapping.items():
            entries = ', '.join('{"duration": 1.0, "texture": SubResource("F%d")}' % i for i in indices)
            loop = str(track.startswith(('idle_', 'walk_', 'run_'))).lower()
            animations.append('{"name": &"%s", "speed": 8.0, "loop": %s, "frames": [%s]}' % (track, loop, entries))
        tres.extend(['[resource]', 'animations = [\n' + ',\n'.join(animations) + '\n]'])
        (directory / 'frames.tres').write_text('\n\n'.join(tres) + '\n')
        raw = c['source_raw_fields']
        record = {'name': c['name'], 'sourceId': ident, 'source_id': c['source_id'],
                  'source_npc_id': c['source_npc_id'], 'source_name_original': c['source_name_original'],
                  'source_version': c['source_version'], 'source_locale': c['source_locale'],
                  'source_raw_fields': raw, 'identity_review_evidence': c['identity_review_evidence'],
                  'catalog_only': True, 'import_enabled': True, 'identity_approval': c['identity_approval'],
                  'source_portrait': prefix + '/portrait.png',
                  'lv': int(raw['lvl']), 'hp': int(raw['hp']), 'mp': int(raw['mp']),
                  'ac': int(raw['ac']), 'mr': int(raw['mr']), 'xp': int(raw['exp']),
                  'undead': raw['undead'] != '0', 'grade': '일반', 'drop': [],
                  'runtime_limits': 'Catalog/source stats retained; current actor clamps HP>=30, XP>=10 and supplies absent combat/movement defaults. No balance or source speed conversion approved; no map spawns.',
                  'animation_profile': {'frames_path': prefix + '/frames.tres', 'layout': 'directional8',
                                        'pixel_scale': 1.0, 'authored_motion_weight': 0.0,
                                        'body_kind': 'beast' if c['source_npc_id'] in ['45023', '45010', '45015', '45039', '45040', '45044', '45048'] else 'special',
                                        'sprite_offset': [canvas[0] + width / 2, canvas[1] + height / 2]},
                  'source_animation': {'binding_id': c['binding_id'], 'body_gfx': binding['body_model_prefix'],
                                       'atlas_columns': columns, 'atlas_frames_per_page': per_page,
                                       'atlas_pages': [prefix + '/' + filename for filename in page_names],
                                       'transparent_atlas_frames': transparent,
                                       'canvas_original_grid': canvas, 'anchor_is_foot': False, 'tracks': {}}}
        if batch.endswith('-v2'):
            # Retain the package's provisional/offline status verbatim. The
            # current user authorizes only this pinned local implementation;
            # that is distinct from external publication or source review.
            record['local_application_authorization'] = 'USER_AUTHORIZED_LOCAL_NAMED_V2_CATALOG_ONLY'
            record['source_binding'] = {key: binding[key] for key in [
                'binding_id', 'source', 'source_gfxid', 'body_model_prefix',
                'variant', 'definition_id', 'definition_index',
                'explicit_resolved_body_prefix', 'attachments']}
            record['source_display_name_status'] = c.get('display_name_status', '')
            record['source_animation']['resolved_raw_prefix'] = binding['body_model_prefix']
            record['source_animation']['source_gfxid'] = binding['source_gfxid']
            record['source_animation']['variant_context'] = binding['variant']
        if c['source_npc_id'] == '45153':
            # The user explicitly permits this single appearance HOLD. Source
            # identity/stats/bindings and body drafts remain preserved; neither
            # the incomplete body nor an unverified composite is active art.
            record['source_import_enabled'] = c['import_enabled']
            record['import_enabled'] = False
            record['appearance_status'] = 'HOLD_FAIRY_COMPOSITE_READABILITY'
            record['appearance_hold_reason'] = '854 body alone is a tiny silver line. Exact same-suffix/frame 855/856/5558 layers pass range checks, but two layer orders at 1x/2x/4x in actual Monster rendering obscure the body or fail small-fairy readability. attr8/t/hflag/blend semantics remain unverified; no guessed color key or other-creature replacement applied.'
            record['appearance_candidate'] = {'body_only_frames': record['animation_profile']['frames_path'],
                                               'body_only_portrait': record['source_portrait'],
                                               'approved': False, 'source_layer_prefixes': [854, 855, 856, 5558],
                                               'actual_runtime_qa': '2 local source-only orders x 3 scales x 8 role/facing cases; appearance not approved'}
            record['animation_profile']['frames_path'] = ''
            record['source_portrait'] = ''
        for track, refs in tracks.items():
            role = track.rsplit('_', 1)[0]
            record['source_animation']['tracks'][track] = {
                'requested_role': role, 'source_action_code': refs[0]['action_code'],
                'source_action_label': refs[0]['action_label'], 'requested_heading': refs[0]['requested_heading_slot'],
                'source_heading': refs[0]['heading_slot'], 'heading0_reused': refs[0]['explicit_heading0_reuse_applied'],
                'action_substitution': role == 'run' or (role == 'walk' and 0 not in codes) or (role == 'attack' and 1 not in codes) or (role == 'hit' and 2 not in codes) or (role == 'death' and (8 not in codes or c['source_npc_id'] == '81159')) or (role == 'idle' and (c['source_npc_id'] == '45060' or 3 not in codes)),
                'frames': [{k: r[k] for k in ['blob_sha256', 'frame_index', 'duration_raw', 'file_suffix']} for r in refs]}
        output['records'].append(record)
        record_order.setdefault(c['source_npc_id'], len(record_order))
        for f in directory.iterdir():
            output['assets'][f.relative_to(root).as_posix()] = sha(f.read_bytes())
        print(ident, len(frames), 'frames', canvas)
    output['records'].sort(key=lambda record: record_order[record['source_npc_id']])
    manifest_path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--allow-heading0-reuse', action='store_true')
    parser.add_argument('--batch', choices=list(BATCHES), default='first-four')
    args = parser.parse_args()
    build(args.package.resolve(), args.root.resolve(), args.allow_heading0_reuse, args.batch)
