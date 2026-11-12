#!/usr/bin/env python3
"""Run the transition gate in a small, real-resource project, never player data.

Historical visual/map audits keep their own manual workflows. This gate checks
actual Main startup and current-map save compatibility, not visual equivalence.
The stage contains production code/data and the resource graph referenced by
production code, scenes and their runtime catalogs. Bytes come from this exact
Git revision; it creates no replacement art and never edits the source tree.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile

TEXT = {'.gd', '.tscn', '.tres', '.json', '.godot', '.cfg', '.gdshader'}
REFERENCE = re.compile(r'["\']((?:res://)?(?:assets|data|scripts|scenes|tests|docs|addons|shaders)/[^"\'\n]+)["\']')
CHECKS = [
    ('reference_sp2_asset_sharing_test', []),
    ('reference_sp2_load_memo_test', []),
    ('boot_progress_log_test', []),
    ('source523_texture_cache_test', []),
    ('frame_hot_paths_test', []),
    ('frame_hitch_log_test', []),
    ('sp2_parse_cache_test', []),
    ('bounded_weak_lru_test', []),
    ('static_cache_compaction_test', []),
    ('source523_image_pack_texture_cache_test', []),
    ('current523_definition_stream_test', []),
    ('current523_native_register_bounded_test', []),
    ('original_ui_page_cache_test', []),
    ('original_ui_hud_field_test', []),
    ('original_ui_change_window_test', []),
    ('original_ui_inventory_snapshot_test', []),
    ('player_skills523_policy_test', []),
    ('core_runtime_save_test', []),
    ('current523_aden_pack_test', []),
    ('current523_aden_review_unit_test', []),
    ('current523_aden_preferences_test', []),
    ('current523_aden_install_test', []),
    ('current523_aden_play_options_test', []),
    ('current523_aden_play_renderer_test', []),
    ('current523_aden_play_controller_test', []),
    ('current523_prior_renderer_release_test', []),
    ('current523_aden_source_field_test', []),
    ('current523_aden_source_portals_test', []),
    ('current523_source_pack_test', []),
    ('current523_source_field_test', []),
    ('current523_source_travel_test', []),
    ('save_identical_payload_test', []),
    ('deferred_save_gate_test', ['--gate-only']),
    ('lineagem_pack_resolution_test', []),
    ('lineagem_pack_settings_main_test', ['--settings-test-snapshot523', '--lineagem-original-preview=user://settings-test-523.json']),
    ('presentation_settings_test', []),
    ('symbol_source523_test', []),
    ('symbol_source523_main_ui_test', []),
    ('symbol_absolute_followup_test', []),
    ('symbol_travel_test', []),
    ('symbol_offline_combat_test', []),
    ('symbol_history_test', []),
    ('halphas_star_enchant_test', []),
    ('halphas_star_enchant_transaction_test', []),
    ('mastery523_main_test', []),
    ('patch523_world_links_test', ['--patch523-game-field']),
    ('patch523_spawn_policy_test', []),
    ('host_portal_navigation_test', []),
    ('auto_selection_order_test', []),
    ('patch523_monster_drops_test', []),
    ('expedition523_catalog_test', []),
    ('expedition523_estimate_model_test', []),
    ('expedition523_cold_selection_test', []),
    ('monsterbook523_cold_selection_test', []),
    ('patch523_rules_cold_bake_test', []),
    ('cards_static_records_test', []),
    ('current523_bake_producer_key_test', []),
    ('expedition523_main_ui_test', []),
    ('patch523_equipment_test', []),
    ('patch523_equipment_main_test', []),
    ('equipment523_smith_smelt_test', []),
    ('equipment523_set_invoke_test', []),
    ('equipment523_alchemy_test', []),
    ('equipment523_service_test', []),
    ('equipment523_combat_test', []),
    ('equipment523_element_loss_test', []),
    ('equipment523_effect_store_test', []),
    ('equipment523_invoke_debuff_test', []),
    ('equipment523_set_effects_test', []),
    ('equipment523_set_lifecycle_test', []),
    ('equipment523_runtime_bridges_test', []),
    ('equipment523_spell_visuals_test', []),
    ('equipment523_native_catalog_test', []),
    ('items523_equipment_status_resistance_test', []),
    ('equipment523_alchemy_pending_migration_test', []),
    ('source_spawn_admission_cache_test', []),
    ('source523_pack_test', []),
    ('current523_item_use_numeric_test', []),
    ('current523_draw_ticket_test', []),
    ('current523_item_lifetime_test', []),
    ('current523_card_item_test', []),
    ('current523_bless_rate_test', []),
    ('bless_refine523_test', []),
    ('card_deck_bonus523_test', []),
    ('einasad523_test', []),
    ('items523_einasad_experience_test', []),
    ('current523_host_world_test', []),
    ('current523_main_ui_test', []),
    ('updater_test', []),
    ('current523_server_profile_test', []),
    ('current523_bank_objects_test', []),
    ('current523_ti2_display_alpha_test', []),
    ('current523_buff_effect_test', []),
    ('current523_mastery_points_test', []),
    ('current523_installed_spawn_definitions_test', []),
    ('boot_index_once_test', []),
    ('source523_image_pack_bake_test', []),
    ('source_gender_selection_test', []),
    ('current523_sp2_bounds_rule_test', []),
    ('zip_table_rows_test', []),
    ('source523_prebake_test', []),
    ('domination_stone_test', []),
    ('routine523_test', []),
    ('acquisition_emblem523_test', []),
    ('spell_move523_test', []),
    ('polymorph_weapon_limit523_test', []),
    ('spell_move_polymorph523_main_test', []),
    ('skill523_source_hold_test', []),
]
# transformation_movement_scope.gd consumes only flags, grades and actor IDs
# from these versioned policy records. Their citations/staging ledgers are
# authoring evidence, not ResourceLoader inputs. Copy the policies unchanged.
DATA_ONLY_POLICIES = {
    'data/pr122_transform_motion_scope.json':'pr122-transform-motion-scope-v1',
    'data/pr122_monster_production_scope.json':'pr122-monster-motion-scope-v1',
}
ACTOR_PREFIXES = ('assets/actors/eight_direction/', 'assets/monsters/reviewed_source/',
                  'assets/local_source_transforms/')

def current_actor_scope(read, exists):
    """Import every current-map actor, not every inactive historical appearance.

    Catalog bytes stay unchanged. The complete graph still checks resource
    references; only engine import of inactive actor art is deferred to the
    retained manual animation audits. Never substitute fallback images.
    """
    policy_path = 'data/maps/source_map_runtime.json'
    if not exists(policy_path):
        return None  # small standalone staging fixtures / pre-source-map trees
    policy = json.loads(read(policy_path))
    current_map = policy['maps']['aden_world']
    snapshot = current_map['gameplay_snapshot'].removeprefix('res://')
    if '..' in PurePosixPath(snapshot).parts or not snapshot.startswith('data/'):
        raise ValueError('unsafe current gameplay snapshot')
    gameplay = json.loads(read(snapshot))['gameplay']
    names = {name for region in gameplay['monster_spawn'] for name in region['monster_types']}
    # Main appends these existing populations after loading the snapshot.
    # Include their current-grid resources too; opening a real UI allows the
    # population child to drain its queue even while World._process is paused.
    for path in ['data/monsters/source3_map_spawns.json', 'data/monsters/local_source_habitats.json']:
        if not exists(path):
            continue
        for row in json.loads(read(path)).get('rows', []):
            if (row.get('map_id') == 'aden_world'
                    and row.get('grid_sha256') == current_map.get('grid_sha256')
                    and row.get('layout_revision') == current_map.get('layout_revision')):
                names.update(row.get('monster_types', [row['name']] if 'name' in row else []))
    source_ids = set()
    spawn_path = 'data/monsters/source3_map_spawns.json'
    pinned_identity = bool(current_map.get('grid_sha256')) and current_map.get('layout_revision') is not None
    if exists(spawn_path):
        for row in json.loads(read(spawn_path)).get('rows', []):
            if row.get('map_id') != 'aden_world' or 'game_source_id' not in row:
                continue
            if pinned_identity and (row.get('grid_sha256') != current_map['grid_sha256']
                                    or row.get('layout_revision') != current_map['layout_revision']):
                continue
            source_ids.add(str(row['game_source_id']))
    profiles = json.loads(read('data/combat_animation_profiles.json'))['profiles']
    keys = {key for key in profiles if key.startswith('class:') or key in {'monster:'+n for n in names}}
    records = [profiles[key] for key in sorted(keys)]
    records += [row for row in json.loads(read('data/game_db_v17.json'))['몬스터'] if row['name'] in names]
    for path in ['data/monsters/reviewed_source_monsters.json', 'data/monsters/reviewed_source_additions.json']:
        if exists(path):
            live_source = [row for row in json.loads(read(path)).get('records', [])
                           if row.get('name') in names or str(row.get('sourceId', '')) in source_ids]
            records += live_source
            names.update(row['name'] for row in live_source if 'name' in row)
    for path, field in [('data/monsters/reviewed_existing_visuals.json','bindings'),
                        ('data/visuals/runtime_manifest.json','monsters')]:
        if exists(path):
            records += [value for key,value in json.loads(read(path))[field].items() if key in names]
    paths = {m.group(1).removeprefix('res://') for m in REFERENCE.finditer(json.dumps(records, ensure_ascii=False))}
    return {'map_id':'aden_world', 'monster_names':sorted(names), 'profile_keys':sorted(keys),
            'paths':paths, 'basis':snapshot, 'source_spawn_ids':sorted(source_ids)}

def git(root: Path, *args: str, **kw):
    return subprocess.check_output(['git', '-C', str(root), *args], **kw)

def ensure_objects(root: Path, objects: list[str]):
    if not objects:
        return
    result = git(root, 'cat-file', '--batch-check', input=('\n'.join(objects)+'\n').encode(),
                 env={**os.environ, 'GIT_NO_LAZY_FETCH':'1'}).decode()
    missing = [line.split()[0] for line in result.splitlines() if line.endswith(' missing')]
    if missing:
        # Like Git's own promisor fetch, do not advertise shallow commits as
        # complete "have" sets: their filtered blobs are precisely missing.
        subprocess.run(['git','-c','fetch.negotiationAlgorithm=noop','-C',str(root),'fetch','origin','--no-tags','--no-write-fetch-head',
                        '--recurse-submodules=no','--filter=blob:none','--stdin'],
                       input='\n'.join(missing)+'\n', text=True, check=True,
                       stdout=subprocess.DEVNULL)

def stage(root: Path, destination: Path) -> dict:
    if destination.exists() and {p.name for p in destination.iterdir()} != {'.godot'}:
        raise ValueError('stage must be new; refusing to overwrite an existing project')
    tree = {}
    for row in git(root, 'ls-tree', '-rz', 'HEAD').split(b'\0'):
        if row:
            meta, raw = row.split(b'\t', 1)
            tree[raw.decode()] = meta.decode().split()[2]
    # Include in-flight tracked/new gate code for local validation. Remote CI
    # already has the committed version. No asset can be synthesized this way.
    def exists(path: str) -> bool:
        return path in tree or (root / path).is_file()
    def read(path: str) -> bytes:
        p = root / path
        if p.is_file():
            return p.read_bytes()
        return git(root, 'show', 'HEAD:' + path)
    selected = {'project.godot', 'Main.tscn'}
    selected.update(str(p.relative_to(root)) for folder in ['scripts', 'data', 'scenes', 'addons', 'shaders']
                    for p in (root / folder).rglob('*') if p.is_file())
    selected.update('tests/' + name + '.gd' for name, _ in CHECKS)
    selected.add('tests/qa_class_selection.gd')
    # Code/scenes are graph roots. Data is copied to retain dynamic catalog
    # access, but only catalogs referenced by code seed additional art.
    queue = [p for p in selected if not p.startswith('data/')]
    scanned = set()
    unresolved = set()
    while queue:
        path = queue.pop()
        if path in scanned or PurePosixPath(path).suffix not in TEXT:
            continue
        scanned.add(path)
        text = read(path).decode('utf-8', errors='strict')
        if path in DATA_ONLY_POLICIES:
            policy = json.loads(text)
            if isinstance(policy, dict) and policy.get('schema') == DATA_ONLY_POLICIES[path]:
                continue
        sprite_frames = PurePosixPath(path).suffix == '.tres' and re.search(r'^\[gd_resource\b[^\n]*type="SpriteFrames"',text)
        # Resolve required preload quote positions once, avoiding a whole-prefix
        # search for every removed optional resource in large JSON catalogs.
        preload_positions = {m.end() for m in re.finditer(r"preload\s*\(\s*(?=[\"'])", text)}
        for match in REFERENCE.finditer(text):
            # SpriteFrames' external resource declarations are engine inputs.
            # Metadata also records old review/provenance paths; those strings
            # do not load a resource and must not pull in its entire history.
            if sprite_frames and not text[text.rfind('\n',0,match.start())+1:match.start()].lstrip().startswith('[ext_resource '):
                continue
            child = match.group(1).removeprefix('res://')
            if '..' in PurePosixPath(child).parts:
                raise ValueError('unsafe resource reference: ' + child)
            if not PurePosixPath(child).suffix or '%' in child:
                continue  # dynamic directory/template; exercised by Main
            if not exists(child):
                required = PurePosixPath(path).suffix in {'.tscn', '.tres'} or match.start() in preload_positions
                if required:
                    raise FileNotFoundError('required resource '+child+' referenced by '+path)
                unresolved.add(child)  # optional guarded paths are not art proof
                continue
            selected.add(child)
            queue.append(child)
            if exists(child + '.import'):
                selected.add(child + '.import')
    # A complete catalog includes thousands of historical per-pose PNGs.
    # Importing them exhausted the 30-minute importer budget before Main ran.
    # Preserve full structural path checking above, but import the complete
    # current-map roster, all class banks and all direct code/scene references.
    scope = current_actor_scope(read, exists)
    deferred = []
    if scope is not None:
        actor_queue = list(scope['paths'])
        for path in scanned:
            if PurePosixPath(path).suffix in {'.gd','.tscn'}:
                actor_queue += [m.group(1).removeprefix('res://') for m in REFERENCE.finditer(read(path).decode())]
        live = set()
        # Exact current-grid source IDs above already retain appended actors'
        # portraits/tracks, including replacements not in the frozen name join.
        # Do not re-pin every stale portrait merely because its catalog is read.
        while actor_queue:
            path = actor_queue.pop()
            if path in live or not path.startswith(ACTOR_PREFIXES) or not PurePosixPath(path).suffix or '%' in path:
                continue
            if not exists(path):
                # Pre-November actor art was removed (user decision 2026-11-10):
                # an actor without original art stays empty instead of failing.
                continue
            live.add(path)
            if PurePosixPath(path).suffix in {'.tres','.res'}:
                text = read(path).decode()
                actor_queue += re.findall(r'^\[ext_resource\b[^\n]*path="res://([^"\n]+)"', text, re.M)
        for path in sorted(selected):
            base = path.removesuffix('.import')
            if base.startswith(ACTOR_PREFIXES) and PurePosixPath(base).suffix in {'.png','.webp','.tres','.res'} and base not in live:
                selected.remove(path)
                deferred.append({'path':path, 'git_blob':tree.get(path),
                                 'reason':'inactive actor; full animation audit remains manual'})
        scope['paths'] = sorted(live)
    print('CORE_RESOURCE_GRAPH',len(selected),'files; metadata',len(scanned),
          'inactive actor imports deferred',len(deferred), flush=True)
    ensure_objects(root, sorted({tree[p] for p in selected if p in tree and not (root/p).is_file()}))
    destination.mkdir(parents=True, exist_ok=True)
    receipts = []
    for path in sorted(selected):
        target = destination / path
        target.parent.mkdir(parents=True, exist_ok=True)
        data = read(path)
        if path.startswith('assets/') and PurePosixPath(path).suffix in {'.png','.webp','.ttf','.wav','.ogg'} and (root/path).is_file():
            try:
                os.link(root/path, target, follow_symlinks=True)
            except OSError:
                target.write_bytes(data)
        else:
            target.write_bytes(data)
        receipts.append({'path':path, 'bytes':len(data), 'sha256':hashlib.sha256(data).hexdigest()})
    # Assets are immutable input. Imported textures stay inside this disposable
    # stage. Original packs are read through an explicit external environment.
    # This gate executes Linux/headless, not Android. Avoid producing Android
    # ETC2/ASTC derivatives during import; production settings and image bytes
    # are unchanged. Record this validation-only platform choice explicitly.
    project = destination/'project.godot'
    source_project = project.read_text()
    linux_project = re.sub(r'(?m)^textures/vram_compression/import_etc2_astc=true$',
                           'textures/vram_compression/import_etc2_astc=false', source_project)
    overrides = []
    if linux_project != source_project:
        project.write_text(linux_project)
        overrides.append({'key':'rendering/textures/vram_compression/import_etc2_astc',
                          'value':False,'scope':'disposable Linux/headless stage only'})
        entry = next(r for r in receipts if r['path']=='project.godot')
        entry['source_sha256'] = entry['sha256']
        entry['stage_sha256'] = hashlib.sha256(project.read_bytes()).hexdigest()
    result = {'revision':git(root,'rev-parse','HEAD').decode().strip(), 'files':receipts, 'validation_overrides':overrides, 'current_actor_scope':scope,
              'deferred_actor_imports':deferred, 'guarded_or_dynamic_literals':sorted(unresolved),
              'scope':'production Main core; not full art/gameplay acceptance'}
    (destination / 'core-resource-paths.json').write_text(json.dumps(result, indent=2))
    return result

def run(command: list[str], path: Path, log: Path, env: dict, timeout: int, marker: str = ''):
    with log.open('w') as stream:
        result = subprocess.run(command, cwd=path, env=env, stdout=stream,
                                stderr=subprocess.STDOUT, timeout=timeout)
    lines = log.read_text(errors='replace').splitlines()
    errors = [x for x in lines if 'SCRIPT ERROR:' in x or 'ERROR:' in x or '_FAIL' in x]
    marker_ok = not marker or any(line.startswith(marker+' ') and json.loads(line[len(marker):].strip()).get('failures') == [] for line in lines)
    if result.returncode or errors or not marker_ok:
        for line in (errors or lines[-12:])[:12]:
            print('::error title=Core runtime::' + line.replace('%','%25').replace('\r','%0D').replace('\n','%0A'), flush=True)
        raise RuntimeError(f'{log.name}: exit={result.returncode}, errors={len(errors)}, completion={marker_ok}')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('.'))
    parser.add_argument('--stage', type=Path, required=True)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--logs', type=Path, required=True)
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    root, target, logs = args.root.resolve(), args.stage.resolve(), args.logs.resolve()
    logs.mkdir(parents=True, exist_ok=True)
    manifest = stage(root, target)
    (logs / 'resource-paths.json').write_text(json.dumps(manifest, indent=2))
    print('CORE_RESOURCE_PATHS', len(manifest['files']), sum(r['bytes'] for r in manifest['files']), flush=True)
    if args.prepare_only:
        return
    env = os.environ.copy()
    if not env.get('TWILIGHT_SOURCE_MAP_PACK'):
        raise ValueError('verified current source-map pack is required, never a skip')
    with tempfile.TemporaryDirectory(prefix='twilight-core-') as profile:
        env.update(XDG_DATA_HOME=profile + '/data', XDG_CONFIG_HOME=profile + '/config', XDG_CACHE_HOME=profile + '/cache')
        run([args.godot, '--headless', '--path', str(target), '--editor', '--import', '--quit'], target, logs/'import.txt', env, 1800)
        for name, user_args in CHECKS:
            command = [args.godot, '--headless', '--path', str(target), '--script', 'res://tests/'+name+'.gd']
            if user_args:
                command += ['--', *user_args]
            marker = {'reference_sp2_asset_sharing_test':'REFERENCE_SP2_ASSET_SHARING_RESULT',
                      'reference_sp2_load_memo_test':'REFERENCE_SP2_LOAD_MEMO_RESULT',
                      'boot_progress_log_test':'BOOT_PROGRESS_LOG_RESULT',
                      'source523_texture_cache_test':'SOURCE523_TEXTURE_CACHE_RESULT',
                      'sp2_parse_cache_test':'SP2_PARSE_CACHE_RESULT',
                      'frame_hitch_log_test':'FRAME_HITCH_LOG_RESULT',
                      'frame_hot_paths_test':'FRAME_HOT_PATHS_RESULT',
                      'bounded_weak_lru_test':'BOUNDED_WEAK_LRU_RESULT',
                      'static_cache_compaction_test':'STATIC_CACHE_COMPACTION_RESULT',
                      'source523_image_pack_texture_cache_test':'SOURCE523_IMAGE_PACK_TEXTURE_CACHE_RESULT',
                      'current523_definition_stream_test':'CURRENT523_DEFINITION_STREAM_RESULT',
                      'current523_native_register_bounded_test':'CURRENT523_NATIVE_REGISTER_BOUNDED_RESULT',
                      'original_ui_page_cache_test':'ORIGINAL_UI_PAGE_CACHE_RESULT',
                      'original_ui_hud_field_test':'ORIGINAL_UI_HUD_FIELD_RESULT',
                      'original_ui_change_window_test':'ORIGINAL_UI_CHANGE_WINDOW_RESULT',
                      'original_ui_inventory_snapshot_test':'ORIGINAL_UI_INVENTORY_SNAPSHOT_RESULT',
                      'player_skills523_policy_test':'SKILLS523_POLICY_RESULT',
                      'core_runtime_save_test':'CORE_RUNTIME_SAVE_RESULT',
                      'current523_aden_pack_test':'CURRENT523_ADEN_PACK_RESULT',
                      'current523_aden_review_unit_test':'CURRENT523_ADEN_REVIEW_UNIT_RESULT',
                      'current523_aden_preferences_test':'CURRENT523_ADEN_PREFERENCES_RESULT',
                      'current523_aden_install_test':'CURRENT523_INSTALL_FOCUSED_RESULT',
                      'current523_aden_play_options_test':'CURRENT523_ADEN_PLAY_OPTIONS_RESULT',
                      'current523_aden_play_renderer_test':'CURRENT523_ADEN_PLAY_RENDERER_RESULT',
                      'current523_aden_play_controller_test':'CURRENT523_ADEN_PLAY_CONTROLLER_RESULT',
                      'current523_prior_renderer_release_test':'CURRENT523_PRIOR_RENDERER_RESULT',
                      'current523_aden_source_field_test':'CURRENT523_ADEN_SOURCE_FIELD_RESULT',
                      'current523_aden_source_portals_test':'CURRENT523_ADEN_SOURCE_PORTALS_RESULT',
                      'current523_source_pack_test':'CURRENT523_SOURCE_PACK_RESULT',
                      'current523_source_field_test':'CURRENT523_SOURCE_FIELD_RESULT',
                      'current523_source_travel_test':'CURRENT523_SOURCE_TRAVEL_RESULT',
                      'save_identical_payload_test':'SAVE_IDENTICAL_PAYLOAD_RESULT',
                      'deferred_save_gate_test':'DEFERRED_SAVE_GATE_RESULT',
                      'lineagem_pack_resolution_test':'LINEAGEM_PACK_RESOLUTION_RESULT',
                      'lineagem_pack_settings_main_test':'LINEAGEM_PACK_SETTINGS_RESULT',
                      'presentation_settings_test':'PRESENTATION_SETTINGS_RESULT',
                      'symbol_source523_test':'SYMBOL523_TEST',
                      'symbol_source523_main_ui_test':'SYMBOL523_MAIN_RESULT',
                      'symbol_absolute_followup_test':'SYMBOL_ABSOLUTE_RESULT',
                      'symbol_travel_test':'SYMBOL_TRAVEL_RESULT',
                      'symbol_offline_combat_test':'SYMBOL_OFFLINE_RESULT',
                      'symbol_history_test':'SYMBOL_HISTORY_RESULT',
                      'halphas_star_enchant_test':'HALPHAS_STAR_ENCHANT_RESULT',
                      'halphas_star_enchant_transaction_test':'HALPHAS_STAR_TRANSACTION_RESULT',
                      'mastery523_main_test':'MASTERY_MAIN_RESULT',
                      'patch523_world_links_test':'PATCH523_WORLD_LINKS_RESULT',
                      'patch523_spawn_policy_test':'PATCH523_SPAWN_POLICY_RESULT',
                      'host_portal_navigation_test':'HOST_PORTAL_NAVIGATION_RESULT',
                      'auto_selection_order_test':'AUTO_SELECTION_RESULT',
                      'patch523_monster_drops_test':'PATCH523_MONSTER_DROPS_RESULT',
                      'expedition523_catalog_test':'EXPEDITION523_CATALOG_RESULT',
                      'expedition523_estimate_model_test':'EXPEDITION523_ESTIMATE_MODEL_RESULT',
                      'expedition523_cold_selection_test':'EXPEDITION523_COLD_SELECTION_RESULT',
                      'monsterbook523_cold_selection_test':'MONSTERBOOK523_COLD_SELECTION_RESULT',
                      'patch523_rules_cold_bake_test':'PATCH523_RULES_COLD_BAKE_RESULT',
                      'cards_static_records_test':'CARDS_STATIC_RECORDS_RESULT',
                      'current523_bake_producer_key_test':'CURRENT523_BAKE_PRODUCER_KEY_RESULT',
                      'expedition523_main_ui_test':'EXPEDITION523_MAIN_UI_RESULT',
                      'patch523_equipment_test':'PATCH523_EQUIPMENT_RESULT',
                      'patch523_equipment_main_test':'PATCH523_MAIN_RESULT',
                      'equipment523_smith_smelt_test':'EQUIPMENT523_SMITH_SMELT_RESULT',
                      'equipment523_set_invoke_test':'EQUIPMENT523_SET_INVOKE_RESULT',
                      'equipment523_alchemy_test':'EQUIPMENT523_ALCHEMY_RESULT',
                      'equipment523_service_test':'EQUIPMENT523_SERVICE_RESULT',
                      'equipment523_combat_test':'EQUIPMENT523_COMBAT_RESULT',
                      'equipment523_element_loss_test':'EQUIPMENT523_ELEMENT_LOSS_RESULT',
                      'equipment523_effect_store_test':'EQUIPMENT523_EFFECT_STORE_RESULT',
                      'equipment523_invoke_debuff_test':'EQUIPMENT523_INVOKE_DEBUFF_RESULT',
                      'equipment523_set_effects_test':'EQUIPMENT523_SET_EFFECTS_RESULT',
                      'equipment523_set_lifecycle_test':'EQUIPMENT523_SET_LIFECYCLE_RESULT',
                      'equipment523_runtime_bridges_test':'EQUIPMENT523_RUNTIME_BRIDGES_RESULT',
                      'equipment523_spell_visuals_test':'EQUIPMENT523_SPELL_VISUALS_RESULT',
                      'equipment523_native_catalog_test':'EQUIPMENT523_NATIVE_CATALOG_RESULT',
                      'items523_equipment_status_resistance_test':'ITEMS523_EQUIP_STATUS_RESULT',
                      'equipment523_alchemy_pending_migration_test':'EQUIPMENT523_ALCHEMY_PENDING_MIGRATION_RESULT',
                      'source_spawn_admission_cache_test':'SPAWN_ADMISSION_CACHE_RESULT',
                      'source523_pack_test':'SOURCE523_PACK_RESULT',
                      'current523_item_use_numeric_test':'CURRENT523_ITEM_USE_NUMERIC_RESULT',
                      'current523_draw_ticket_test':'CURRENT523_DRAW_TICKET_RESULT',
                      'current523_item_lifetime_test':'CURRENT523_ITEM_LIFETIME_RESULT',
                      'current523_card_item_test':'CURRENT523_CARD_ITEM_RESULT',
                      'current523_bless_rate_test':'CURRENT523_BLESS_RATE_RESULT',
                      'bless_refine523_test':'BLESS_REFINE523_RESULT',
                      'card_deck_bonus523_test':'CARD_DECK_BONUS523_RESULT',
                      'einasad523_test':'EINASAD523_RESULT',
                      'items523_einasad_experience_test':'ITEMS523_EINASAD_EXP_RESULT',
                      'current523_host_world_test':'CURRENT523_HOST_WORLD_RESULT',
                      'updater_test':'UPDATER_RESULT',
                      'current523_server_profile_test':'CURRENT523_SERVER_PROFILE_RESULT',
                      'current523_bank_objects_test':'CURRENT523_BANK_OBJECTS_RESULT',
                      'current523_ti2_display_alpha_test':'CURRENT523_TI2_DISPLAY_ALPHA_RESULT',
                      'current523_buff_effect_test':'CURRENT523_BUFF_EFFECT_RESULT',
                      'current523_main_ui_test':'CURRENT523_MAIN_UI_RESULT',
                      'current523_mastery_points_test':'CURRENT523_MASTERY_POINTS_RESULT',
                      'current523_installed_spawn_definitions_test':'CURRENT523_INSTALLED_SPAWN_DEFINITIONS_RESULT',
                      'boot_index_once_test':'BOOT_INDEX_ONCE_RESULT',
                      'source523_image_pack_bake_test':'SOURCE523_IMAGE_PACK_BAKE_RESULT',
                      'source_gender_selection_test':'SOURCE_GENDER_SELECTION_RESULT',
                      'current523_sp2_bounds_rule_test':'CURRENT523_SP2_BOUNDS_RULE_RESULT',
                      'zip_table_rows_test':'ZIP_TABLE_ROWS_RESULT',
                      'source523_prebake_test':'SOURCE523_PREBAKE_RESULT',
                      'domination_stone_test':'DOMINATION_STONE_RESULT',
                      'routine523_test':'ROUTINE523_RESULT',
                      'acquisition_emblem523_test':'ACQEMB523_RESULT',
                      'spell_move523_test':'SPELL_MOVE523_RESULT',
                      'polymorph_weapon_limit523_test':'POLYMORPH_WEAPON_LIMIT523_RESULT',
                      'spell_move_polymorph523_main_test':'SPELL_MOVE_POLYMORPH523_MAIN_RESULT',
                      'skill523_source_hold_test':'SKILL523_SOURCE_HOLD_RESULT'}[name]
            run(command, target, logs/(name+'.txt'), env, 180, marker)
            print('CORE_CHECK_OK', name, flush=True)

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('::error title=Core gate::'+str(error).replace('%','%25').replace('\r','%0D').replace('\n','%0A'), flush=True)
        raise



