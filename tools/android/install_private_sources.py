#!/usr/bin/env python3
"""Install/update TWILIGHT using packed Git code and authenticated private ZIPs.

No per-runtime-file HTTP downloads, reset/clean, Drive writes, or game execution.
The private, owner-maintained plan is kept outside the public repository.
"""
import argparse
import base64
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
import zlib

from private_drive_transport import DriveTransport, DownloadError, sha256_file, _DriveRedirects

REPO = 'https://github.com/zoog136-hash/-.git'
STATE = '.twilight_private_install_state.json'
RESOURCE_STATE = '.twilight_resource_state.json'
GENERATED = ('twilight_private_install.json', 'scripts/install/private_source_bootstrap.gd')
RUNTIME_ROOTS = {'addons', 'assets', 'data', 'external_map_packs', 'scenes', 'scripts'}
RUNTIME_FILES = {'project.godot', 'Main.tscn', 'external_map_packs/.gdignore'}
RUNTIME_MAPS = {'native_png_v5', 'aden_faith_png_v1', 'domination_png_v1',
                'oman_png_v1', 'oman_v2', 'source84_v3'}
SUFFIXES = {'.gd', '.gdshader', '.gdshaderinc', '.gdextension', '.tscn', '.tres',
            '.res', '.uid', '.cfg', '.json', '.bin', '.nav', '.l1jpng', '.png',
            '.jpg', '.jpeg', '.webp', '.svg', '.ttf', '.otf', '.ogg', '.wav',
            '.mp3', '.flac', '.glb'}
OFFLINE_DIRS = ('assets/maps/aden_city_region', 'assets/maps/aden_modular_district_01',
                'assets/maps/aden_modular_pilot', 'assets/maps/aden_rebuild_preview',
                'assets/maps/aden_world_draft', 'assets/original_sheets')
OFFLINE_FILES = {'scripts/maps/aden_modular_preview_renderer.gd',
                 'data/map_remake/private/aden/effective_layouts_build.json',
                 'data/skills/research_inventory.json', 'data/resource_delivery_ledger.json',
                 'data/animation_authoring_sources.json', 'data/v19_extraction_manifest.json',
                 'data/visuals/pr80_original_asset_hashes.json', 'data/maps/aden_faith_png_archive.json',
                 'data/maps/native_png_archive.json', 'scenes/SkillVFXLab.tscn'}


def log(message):
    print(message, flush=True)


def relative(value):
    if (not isinstance(value, str) or not value or '\\' in value or ':' in value
            or any(ord(c) < 32 for c in value)):
        raise ValueError('Unsafe relative path')
    parts = value.split('/')
    if any(part in ('', '.', '..') for part in parts):
        raise ValueError('Unsafe relative path: ' + value)
    if any(part.casefold() in ('.git', '.godot', 'user', 'user_data') for part in parts):
        raise ValueError('Protected relative path: ' + value)
    return PurePosixPath(value)


def no_links(path):
    path = Path(os.path.abspath(path))
    for part in (path, *path.parents):
        if part.is_symlink():
            raise ValueError('Symlink in installer destination: ' + str(part))


def inside(root, name):
    result = root / relative(name)
    no_links(result)
    return result


def pin(value):
    if not isinstance(value, str) or not re.fullmatch('[0-9a-f]{64}', value):
        raise ValueError('An explicit SHA256 is required')
    return value


def json_write(path, value):
    no_links(path)
    fd, temporary_name = tempfile.mkstemp(prefix='.' + path.name + '-', dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as target:
            json.dump(value, target, ensure_ascii=False, sort_keys=True, indent=2)
            target.write('\n')
            target.flush()
            os.fsync(target.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def read_json(path, maximum=32 * 1024 * 1024):
    no_links(path)
    if path.stat().st_size > maximum:
        raise ValueError('Oversized installer metadata')
    return json.loads(path.read_text(encoding='utf-8'))


def run(args, *, cwd=None, capture=False, input_text=None):
    environment = dict(os.environ, GIT_LFS_SKIP_SMUDGE='1', GIT_TERMINAL_PROMPT='0')
    return subprocess.run(args, cwd=cwd, env=environment, check=True,
                          input=input_text, text=True,
                          stdout=subprocess.PIPE if capture else None).stdout


def runtime_path(name):
    if name.split('/', 1)[0] not in RUNTIME_ROOTS and name not in RUNTIME_FILES:
        return False
    path = relative(name)
    if name in RUNTIME_FILES:
        return True
    if path.parts[0] not in RUNTIME_ROOTS or name in OFFLINE_FILES:
        return False
    if any(name == x or name.startswith(x + '/') for x in OFFLINE_DIRS):
        return False
    if name.startswith('data/pr122_'):
        return False
    if re.match(r'assets/actors/eight_direction/native_locomotion_staging/transform_[^/]+/draft001/', name):
        return False
    if path.parts[0] == 'external_map_packs':
        if len(path.parts) < 2 or path.parts[1] not in RUNTIME_MAPS:
            return False
        if name.startswith('external_map_packs/source84_v3/') and name.endswith('.u8.gz'):
            return True
    return path.suffix.lower() in SUFFIXES and not name.endswith(('.bak', '.tmp', '.backup'))


def packed_code(cache):
    """Git checkout fetches missing sparse blobs together in a pack, not raw URLs."""
    repo = cache / 'github-runtime'
    no_links(repo)
    if not repo.exists():
        run(['git', 'clone', '--filter=blob:none', '--depth=1', '--no-checkout',
             '--single-branch', '--branch', 'main', '--no-tags', REPO, str(repo)])
    else:
        if run(['git', 'remote', 'get-url', 'origin'], cwd=repo, capture=True).strip() != REPO:
            raise ValueError('Unexpected code-cache origin; no checkout changed')
        run(['git', 'fetch', '--filter=blob:none', '--depth=1', '--no-tags', 'origin',
             '+refs/heads/main:refs/remotes/origin/main'], cwd=repo)
    commit = run(['git', 'rev-parse', 'refs/remotes/origin/main'], cwd=repo, capture=True).strip()
    if not re.fullmatch('[0-9a-f]{40}', commit):
        raise ValueError('Invalid pinned main commit')
    # The tree is metadata only. No blobs are requested individually here.
    # --long would ask for each absent blob's size and can trigger thousands
    # of lazy object requests in a partial clone. Tree SHAs alone are enough.
    output = subprocess.check_output(['git', 'ls-tree', '-r', '-z', commit], cwd=repo)
    inventory = {}
    for entry in output.split(b'\0'):
        if not entry:
            continue
        header, raw_name = entry.split(b'\t', 1)
        mode, kind, digest = header.decode('ascii').split()
        name = raw_name.decode('utf-8')
        if not runtime_path(name):
            continue
        if kind != 'blob' or mode not in ('100644', '100755'):
            raise ValueError('Unsupported runtime tree entry: ' + name)
        inventory[name] = {'blob_sha1': digest}
    if not {'project.godot', 'Main.tscn'}.issubset(inventory):
        raise ValueError('Incomplete Godot runtime tree')
    # no-cone patterns are exact escaped file names, not broad root downloads.
    patterns = ['/' + re.sub(r'([\\*?\[\]!#])', r'\\\1', n) for n in sorted(inventory)]
    log('GitHub main %s: %d runtime files, fetched in Git object packs.' % (commit[:12], len(inventory)))
    run(['git', 'sparse-checkout', 'set', '--no-cone', '--stdin'], cwd=repo,
        input_text='\n'.join(patterns) + '\n')
    run(['git', '-c', 'advice.detachedHead=false', 'checkout', '--detach', commit], cwd=repo)
    # Initialize the sparse index after --no-checkout even when HEAD already
    # points to the requested commit. read-tree hydrates required blobs together.
    run(['git', 'read-tree', '-mu', commit], cwd=repo)
    return repo, commit, inventory


def fetch_plan(args, cache):
    if args.plan_inline:
        # A private handoff can travel in the user's one pasted command. It
        # contains only pack metadata, never tokens or original asset bytes.
        if len(args.plan_inline) > 4 * 1024 * 1024:
            raise ValueError('Oversized inline handoff')
        compressed = base64.b64decode(args.plan_inline, altchars=b'-_', validate=True)
        decoder = zlib.decompressobj()
        data = decoder.decompress(compressed, 2 * 1024 * 1024 + 1)
        if (len(data) > 2 * 1024 * 1024 or not decoder.eof
                or decoder.unconsumed_tail or decoder.unused_data):
            raise ValueError('Invalid or oversized compressed inline handoff')
        digest = hashlib.sha256(data).hexdigest()
        if args.plan_sha256 and digest != pin(args.plan_sha256):
            raise ValueError('Inline handoff SHA256 mismatch')
        document = json.loads(data.decode('utf-8'))
        if not isinstance(document, dict):
            raise ValueError('Inline handoff must be a JSON object')
        return document, digest
    if args.plan:
        return read_json(args.plan), sha256_file(args.plan)
    if not args.plan_id or not re.fullmatch('[A-Za-z0-9_-]+', args.plan_id):
        raise ValueError('Private installation handoff is required: --plan or --plan-id. No pack IDs are invented.')
    # The authenticated, explicitly selected owner plan is a mutable index.
    # Optional immutable pin prevents its replacement when desired.
    fd, temporary_name = tempfile.mkstemp(prefix='plan-', dir=cache)
    os.close(fd)
    temporary = Path(temporary_name)
    try:
        if args.token_file:
            transport = DriveTransport(cache / 'bundles', token_file=args.token_file)
            request = transport._request(args.plan_id)
            # Same redirect restrictions as bundle downloads; never forward a
            # bearer to an arbitrary host named by an HTTP redirect.
            with urllib.request.build_opener(_DriveRedirects()).open(request, timeout=60) as response:
                data = response.read(2 * 1024 * 1024 + 1)
            if len(data) > 2 * 1024 * 1024:
                raise ValueError('Oversized private plan')
            temporary.write_bytes(data)
        else:
            run(['rclone', 'backend', 'copyid', args.remote + ':', args.plan_id,
                 str(temporary), '--retries', '1', '--low-level-retries', '1',
                 '--stats', '0', '--log-level', 'ERROR'])
        if args.plan_sha256 and sha256_file(temporary) != pin(args.plan_sha256):
            raise ValueError('Private plan SHA256 mismatch')
        return read_json(temporary), sha256_file(temporary)
    finally:
        temporary.unlink(missing_ok=True)


def file_record(path):
    no_links(path)
    if not path.is_file():
        raise ValueError('Expected regular installed file: ' + str(path))
    return {'bytes': path.stat().st_size, 'sha256': sha256_file(path)}


def matches(path, record):
    return (not path.is_symlink() and path.is_file()
            and path.stat().st_size == record['bytes']
            and sha256_file(path) == record['sha256'])


def owned_state(root, filename=STATE):
    path = root / filename
    if not path.exists():
        return {}
    document = read_json(path)
    if document.get('schema') != 1 or not isinstance(document.get('files'), dict):
        raise ValueError('Invalid prior installation ownership state')
    for name, record in document['files'].items():
        relative(name)
        if (not isinstance(record, dict) or not isinstance(record.get('bytes'), int)
                or record['bytes'] < 0):
            raise ValueError('Invalid managed file record')
        pin(record.get('sha256'))
    for name in document.get('directories', []):
        relative(name)
    return document


def copy_file(source, destination):
    no_links(source)
    no_links(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def safe_extract(archive, root, include_prefixes=None):
    """Pinned archive + ZIP CRC, no traversal/links/case aliases, bounded space."""
    inventory = {}
    case_names = {}
    existing_cases = {path.relative_to(root).as_posix().casefold(): path.relative_to(root).as_posix()
                      for path in root.rglob('*')}
    if include_prefixes is not None:
        if not isinstance(include_prefixes, list) or not include_prefixes:
            raise ValueError('An archive filter must be a nonempty explicit list')
        for prefix in include_prefixes:
            relative(prefix.rstrip('/'))
    def selected(name):
        return include_prefixes is None or any(
            name.startswith(prefix) if prefix.endswith('/') else name == prefix
            for prefix in include_prefixes)
    with zipfile.ZipFile(archive) as zf:
        entries = zf.infolist()
        if len(entries) > 250000:
            raise ValueError('ZIP member limit exceeded')
        total = sum(x.file_size for x in entries if selected(x.filename))
        if total > shutil.disk_usage(root).free:
            raise ValueError('Not enough space to extract the private ZIP; prior install retained')
        for info in entries:
            name = info.filename.rstrip('/')
            relative(name)
            key = name.casefold()
            if key in case_names:
                raise ValueError('Duplicate/case-aliased ZIP path: ' + name)
            case_names[key] = name
            mode = info.external_attr >> 16
            if mode and stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR):
                raise ValueError('Link/special ZIP entry rejected: ' + name)
            if info.flag_bits & 1:
                raise ValueError('Encrypted ZIP entry rejected')
            if not selected(info.filename):
                continue
            if key in existing_cases and existing_cases[key] != name:
                raise ValueError('Case-aliased archive overlay rejected: ' + name)
            existing_cases[key] = name
            target = inside(root, name)
            if info.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            # Archive overlaps are allowed only for identical bytes. The
            # complete ZIP pin still binds every original compressed payload.
            fd, temp_name = tempfile.mkstemp(prefix='.extract-', dir=target.parent)
            os.close(fd)
            temporary = Path(temp_name)
            try:
                with zf.open(info) as source, temporary.open('wb') as dest:
                    shutil.copyfileobj(source, dest, 1024 * 1024)
                if temporary.stat().st_size != info.file_size:
                    raise ValueError('Truncated ZIP entry: ' + name)
                record = file_record(temporary)
                if target.exists():
                    if not matches(target, record):
                        raise ValueError('Conflicting archive member: ' + name)
                else:
                    os.replace(temporary, target)
                inventory[name] = record
            finally:
                temporary.unlink(missing_ok=True)
    return inventory


def assembled(pack, downloaded, cache):
    if pack['format'] != 'joined-zip':
        return [downloaded[row['sha256']] for row in pack['files']]
    pin(pack.get('sha256'))
    rows = sorted(pack['files'], key=lambda x: x.get('order', 0))
    if [x.get('order') for x in rows] != list(range(1, len(rows) + 1)):
        raise ValueError('Joined ZIP requires explicit contiguous part order')
    target = cache / (pack['sha256'] + '.zip')
    no_links(target)
    if target.exists():
        if not matches(target, pack):
            raise ValueError('Assembled ZIP changed; preserved without use')
        return [target]
    fd, name = tempfile.mkstemp(prefix='join-', dir=cache)
    os.close(fd)
    temporary = Path(name)
    try:
        if pack['bytes'] > shutil.disk_usage(cache).free:
            raise ValueError('Not enough space to join private parts')
        with temporary.open('wb') as output:
            for row in rows:
                with downloaded[row['sha256']].open('rb') as source:
                    shutil.copyfileobj(source, output, 1024 * 1024)
        if not matches(temporary, pack):
            raise ValueError('Joined ZIP failed its complete size/SHA256')
        os.replace(temporary, target)
        return [target]
    finally:
        temporary.unlink(missing_ok=True)


def prepare_resources(plan, downloaded, resources, cache):
    identity = hashlib.sha256(json.dumps({'packs': plan['packs'], 'bindings': plan['bindings']},
                                       sort_keys=True).encode()).hexdigest()
    destination = resources / identity
    no_links(destination)
    if destination.exists():
        state = owned_state(destination, RESOURCE_STATE)
        if not state or state.get('identity') != identity:
            raise ValueError('Unowned or changed existing resource version')
        for name, record in state['files'].items():
            if not matches(inside(destination, name), record):
                raise ValueError('Installed resource changed: ' + name)
        log('Reusing verified installed resource version ' + identity[:12])
        return destination, state
    # An interrupted extraction keeps verified archives. Rebuilding in a new
    # owned directory never modifies the current resources or input archives.
    stage = Path(tempfile.mkdtemp(prefix='unpack-', dir=resources))
    inventory = {}
    try:
        selected = set()
        for pack in plan['packs']:
            if pack['id'] in selected or not set(pack.get('depends_on', [])).issubset(selected):
                raise ValueError('Duplicate or unsatisfied private pack dependency')
            selected.add(pack['id'])
            root = inside(stage, pack['install_root'])
            root.mkdir(parents=True, exist_ok=True)
            archives = assembled(pack, downloaded, cache)
            if pack['format'] == 'file':
                if len(archives) != 1:
                    raise ValueError('File pack needs exactly one payload')
                row = pack['files'][0]
                target = inside(root, row['name'])
                copy_file(archives[0], target)
                # Even directly consumed table ZIPs must pass every member CRC.
                if zipfile.is_zipfile(target):
                    with zipfile.ZipFile(target) as zf:
                        if zf.testzip() is not None:
                            raise ValueError('Table ZIP CRC mismatch')
                payload = {row['name']: file_record(target)}
            elif pack['format'] in ('zip', 'joined-zip'):
                payload = {}
                for archive in archives:
                    payload.update(safe_extract(archive, root, pack.get('include_prefixes')))
            else:
                raise ValueError('Unsupported pack format')
            for name, record in payload.items():
                inventory[pack['install_root'] + '/' + name] = record
        retained = []
        if 'world_map' in plan['bindings']:
            retained.append(plan['bindings']['world_map']['contract_path'])
            retained.extend(x['path'] for x in plan['bindings']['world_map'].get('source_manifests', []))
        # UI roots remain usable by an explicit existing source-ui selection.
        # New formal defaults never authorize retiring those original paths.
        retained.extend(name for name in inventory if name.startswith(('source-ui/', 'ui/')))
        state = {'schema': 1, 'identity': identity, 'files': inventory,
                 'directories': managed_directories(inventory), 'retained_files': retained}
        json_write(stage / RESOURCE_STATE, state)
        # Verify descriptor bindings before making this resource version visible.
        descriptor(plan, stage)
        os.replace(stage, destination)
        return destination, state
    except BaseException:
        # Do not recursively remove a failed directory: partial files remain
        # task-owned evidence, while downloaded archives are reusable.
        log('Incomplete resource staging retained at ' + str(stage))
        raise


def persistent_contract(source, root, digest):
    """Retain immutable relation bytes referenced by a never-overwritten cfg.

    This source copy is deliberately outside full-version ownership cleanup,
    like the original archive cache. Existing user settings may still select
    this exact pin after newer input versions have been installed.
    """
    directory = inside(root, pin(digest))
    directory.mkdir(parents=True, exist_ok=True)
    destination = inside(directory, source.name)
    record = file_record(source)
    if record['sha256'] != digest:
        raise ValueError('Persistent relation source pin mismatch')
    if destination.exists():
        if not matches(destination, record):
            raise ValueError('Persistent relation input changed; retained without overwrite')
        return destination
    fd, name = tempfile.mkstemp(prefix='.relation-', dir=directory)
    os.close(fd)
    temporary = Path(name)
    try:
        copy_file(source, temporary)
        if not matches(temporary, record):
            raise ValueError('Persistent relation copy did not retain its source identity')
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)
    return destination


def gd_function(source, name):
    """Read a named existing function; never import or execute game code."""
    source = re.sub(r'(?m)^\s*#.*$', '', source)
    if name is None:
        return re.sub(r'\s+', '', source)
    match = re.search(r'(?ms)^(?:static\s+)?func\s+' + re.escape(name) +
                      r'\s*\(.*?(?=^(?:static\s+)?func\s+|\Z)', source)
    return re.sub(r'\s+', '', match.group(0)) if match else ''


def source_contract_evidence(code_root, requirements):
    evidence = {'ready': False, 'files': {}, 'blockers': []}
    sources = {}
    if code_root is None:
        evidence['blockers'].append('Target runtime code is not staged yet')
        return evidence, sources
    for name, functions in requirements.items():
        path = inside(code_root, name)
        if not path.is_file() or path.stat().st_size > 16 * 1024 * 1024:
            evidence['blockers'].append('Missing owner module: ' + name)
            continue
        source = path.read_text(encoding='utf-8')
        sources[name] = source
        evidence['files'][name] = sha256_file(path)
        for function, markers in functions:
            body = gd_function(source, function)
            if not body or any(marker not in body for marker in markers):
                evidence['blockers'].append('Missing owner boundary: ' + name + ':' + str(function or 'module'))
    evidence['ready'] = not evidence['blockers']
    return evidence, sources


def combined_ui_code_contract(code_root):
    requirements = {
        'scripts/ui/original_ui/source_main_selection.gd': [('selected_pack', ['selection_contract'])],
        'scripts/ui/original_ui/source_main_hud.gd': [('configure', ['InventoryView.PARENT',
            'QuickslotView.ROOT', 'candidate.configure(pack,hud,Callable('])],
        'scripts/ui/original_ui/source_main_inventory_slots.gd': [('_slot_binding', ['Markers.build', 'node_scopes']),
            ('refresh_slot', ['Markers.build', 'set_bound_visible'])],
        'scripts/ui/original_ui/source_main_inventory_markers.gd': [('build', ['_is_item_equipped', 'item_locks']),
            (None, ['EQUIPPED', '8328', 'LOCKED', '7304'])],
        'scripts/ui/original_ui/source_main_quickslot_view.gd': [('_stage', ['build_group(group)',
            'pages.register_original_page(page,PANEL,int(model.pages[group]))',
            'pages.set_page_index(int(model.pages[group]))'])],
        'scripts/ui/original_ui/source_main_quickslot_bindings.gd': [('build_group', []),
            (None, ['1628', '1360', '1104', '848', '592', '18488'])],
        'scripts/ui/original_ui/source_main_quickslot_images.gd': [(None, [])],
        'scripts/ui/original_ui/source_page_view.gd': [('register_original_page', []),
            ('set_page_index', []), ('input_control', [])],
        'scripts/ui/original_ui/source_button.gd': [('_source_input', ['handle_native_touch',
            'InputEventScreenTouch', 'InputEventScreenDrag']), ('handle_native_touch', ['event.canceled',
            '_dispatch_activation']), ('cancel_native_touch', [])],
        'scripts/ui/original_ui/source_main_world_map.gd': [('open', ['_register_native_button(map_all.player,29552)',
            '7440', '4508']), ('_register_native_button', ['source_button', 'handle_native_touch']),
            ('_input', ['InputEventScreenTouch', 'InputEventScreenDrag', 'handle_native_touch',
                        '_forward_native_scroll', 'set_input_as_handled']),
            ('_forward_native_scroll', ['_route_source_input(local)']),
            ('_cancel_native_input', ['cancel_native_touch'])],
    }
    evidence, _ = source_contract_evidence(code_root, requirements)
    return evidence


def world_map_code_contract(code_root):
    # These are existing owner interfaces/call boundaries, not PR-number or
    # filename-only assertions. Changed code is read from the actual Git stage.
    requirements = {
        'scripts/world.gd': [('_ready', ['_bind_current523_world_map_from_settings.call_deferred()']),
            ('_world_map_input', ['res://scripts/maps/current523_world_map_input.gd', 'add_child']),
            ('_bind_current523_world_map_from_settings', ['configure_from_settings']),
            ('bind_current523_world_map', ['configure'])],
        'scripts/maps/current523_world_map_input.gd': [(None, ['user://current523_world_map.cfg']),
            ('configure_from_settings', ['open_contract', 'configure']),
            ('configure', ['bind_original_world_map', 'Callable(self,"context")', 'Callable(self,"input")',
                           'original_world_map_image_clicked']),
            ('_on_image_clicked', ['COORDINATES.project', 'WALK.request']),
            ('input', ['InputEventScreenTouch', 'InputEventScreenDrag'])],
        'scripts/maps/current523_world_map_coordinates.gd': [(None, ['OWN_SOURCE_CELL_CENTER_FIELD_RATIO_V1']),
            ('project', [])],
        'scripts/maps/current523_world_map_walk.gd': [('ticket', []),
            ('request', ['point_clear', 'find_world_path', 'set_manual_click_path'])],
        'scripts/ui/renewal_hud.gd': [(None, ['original_world_map_image_clicked']),
            ('_bind_selected_original_main_ui', []), ('bind_original_world_map', []),
            ('toggle_map', ['has_world_map_binding'])],
        'scripts/ui/original_ui/source_main_hud.gd': [('bind_world_map', ['configure']),
            ('toggle_world_map', []), (None, ['world_image_clicked'])],
        'scripts/ui/original_ui/source_main_world_map.gd': [('open', ['notfield_mapisObject', 'is_instance_valid(field_map)']),
            ('image_pixel_at', []), ('submit_world_image_click', []), ('set_scroll_position', []),
            ('scroll_geometry', []), ('_route_source_input', ['InputEventScreenTouch', 'InputEventScreenDrag']),
            (None, ['configure_nodes', 'project_player'])],
        'scripts/ui/original_ui/source_main_map_bindings.gd': [('build_map_scene', ['field_map:Object']),
            ('bind_area_presented', ['field_map:Object']), ('select_world', ['apply_declared_field_image']),
            ('viewport_to_world_image_pixel', []), ('submit_world_image_click', []),
            (None, ['apply_field_world'])],
        'scripts/ui/original_ui/sprite_scene.gd': [('configure_nodes', []), ('project_player', []),
            ('set_bound_source_asset_result', [])],
        'scripts/ui/original_ui/source_scroll.gd': [('bind_input', []), ('_forward_input', []),
            (None, ['gui_input', 'input_control'])],
        'scripts/ui/original_ui/source_button.gd': [('_source_input', [])],
        'scripts/maps/source523_map_image_adapter.gd': [('open_contract', []), ('world_candidates', ['Object']),
            ('resolve_field_world', ['Object']), ('apply_field_world', ['Object']),
            ('_field_context', ['current523_source_field']), ('resolve_world', ['IMAGES.resolve_asset_value'])],
        'scripts/ui/source523_image_assets.gd': [('_ensure_selection', ['TWILIGHT_SOURCE523_IMAGES',
            'TWILIGHT_SOURCE523_IMAGES_SHA256']), ('selected', []), ('active', ['_ensure_selection']),
            ('configure', ['PACK.open']),
            ('resolve_asset_value', []), ('resolve_asset', [])],
        'scripts/resources/source523_image_pack.gd': [('open', []), ('resolve_asset', []),
            (None, ['source523-exact-original-image-pack', 'patch523', 'unchanged_original_file_bytes'])],
        'scripts/ui/original_ui/source_main_selection.gd': [('selected_pack', ['TWILIGHT_SOURCE_UI',
            'TWILIGHT_SOURCE_UI_SHA256', '.open('])],
        'scripts/ui/original_ui/source_pack.gd': [('open', []), (None, ['twilight-original-ui-v1', 'original_ui.json'])],
    }
    evidence, sources = source_contract_evidence(code_root, requirements)
    if code_root is None:
        return evidence
    project = inside(code_root, 'project.godot')
    if project.is_file():
        evidence['project_sha256'] = sha256_file(project)
        project_source = re.sub(r'(?m)^\s*;.*$', '', project.read_text(encoding='utf-8'))
        mouse_emulation = re.search(r'(?ms)^\[input_devices\]\s*(.*?)(?=^\[|\Z)', project_source)
        setting = re.search(r'(?m)^pointing/emulate_mouse_from_touch\s*=\s*(true|false)\s*$',
                            mouse_emulation.group(1)) if mouse_emulation else None
        mouse_emulation = setting.group(1) == 'true' if setting else None
    else:
        mouse_emulation = False
    button = gd_function(sources.get('scripts/ui/original_ui/source_button.gd', ''), '_source_input')
    touch = button.find('InputEventScreenTouch')
    mouse_only = button.find('not event is InputEventMouseButton'.replace(' ', ''))
    native_touch = touch >= 0 and (mouse_only < 0 or touch < mouse_only) and '.pressed' in button
    evidence['requires_mouse_emulation'] = not native_touch
    if mouse_emulation is False and not native_touch:
        evidence['blockers'].append('Original World row has no declared Android touch activation path')
    evidence['ready'] = not evidence['blockers']
    return evidence


def world_map_input_contract(result, resources, bindings, main_ui):
    evidence = {'ready': False, 'files': {}, 'blockers': []}
    def require(key, path, digest, size=None):
        if (not path.is_file() or sha256_file(path) != pin(digest)
                or size is not None and path.stat().st_size != size):
            evidence['blockers'].append('Missing/mismatched world-map input: ' + key)
        else:
            evidence['files'][key] = {'path': str(path), 'sha256': digest}
    if main_ui is None or 'main_ui' not in result:
        evidence['blockers'].append('Main UI original selection is absent')
    else:
        root = Path(result['main_ui']['root'])
        require('main_ui_manifest', root / 'original_ui.json', result['main_ui']['manifest_sha256'])
        scopes = {'UI/MapScene.csb': [132], 'UI/Map/Map_All.csb': [35332,34904,30312,29552,29228,31656],
                  'UI/Map/Map_Tab_Area.csb': [44440,37316], 'UI/Map/Map_List_Button.csb': [7440,4508,7492,4560]}
        for member, offsets in scopes.items():
            scene = main_ui['scenes'].get(member, {})
            if (not isinstance(scene, dict)
                    or not set(offsets).issubset(main_ui.get('node_scopes', {}).get(member, []))
                    or not set(offsets).issubset(scene.get('_selected_source_offsets', []))):
                evidence['blockers'].append('Original map control scope is absent: ' + member)
        if main_ui.get('externally_bound_texture_nodes', {}).get('UI/Map/Map_Tab_Area.csb') != [44440]:
            evidence['blockers'].append('Original World-image slot declaration is absent')
        for member, record in main_ui['files'].items():
            require('main_ui:' + member, inside(root, 'originals/' + member), record['sha256'], record['bytes'])
    if 'images' not in result:
        evidence['blockers'].append('Original image pack selection is absent')
    else:
        root = Path(result['images']['root'])
        require('image_manifest', root / 'manifest.json', result['images']['manifest_sha256'])
        supplement = bindings['images'].get('required_supplement')
        if not supplement:
            evidence['blockers'].append('Original dummy declarations are absent')
        else:
            require('image_dummy', inside(root, supplement['path']), supplement['sha256'], supplement['bytes'])
        images = bindings['world_map'].get('required_world_images', [])
        covered = set()
        for image in images:
            require('world_image:' + str(image['world_id']), inside(root, image['path']),
                    image['sha256'], image['bytes'])
            covered.add((str(image['land_id']), image['world_id']))
        offers = {(land, offer['world_id']) for land, offer in bindings['world_map']['offered_worlds'].items()}
        if not offers or covered != offers:
            evidence['blockers'].append('Exact offered World image inputs are not supplied')
    evidence['ready'] = not evidence['blockers']
    return evidence


def descriptor(plan, resources, persistent_contracts=None, code_root=None):
    bindings = plan['bindings']
    result = {'schema': 1}
    main_ui_document = None
    if 'maps' in bindings:
        row = bindings['maps']
        raw = inside(resources, row['source_root'])
        tile = inside(resources, row['tile_root'])
        for path, digest in ((raw / row['source_manifest'], row['source_manifest_sha256']),
                             (tile / row['tile_manifest'], row['tile_manifest_sha256'])):
            if sha256_file(path) != pin(digest):
                raise ValueError('Map manifest pin mismatch')
        result['maps'] = {'raw_root': str(raw), 'tile_root': str(tile),
                          'source_manifest_sha256': row['source_manifest_sha256'],
                          'tile_manifest_sha256': row['tile_manifest_sha256'],
                          'native_land_id': row['native_land_id']}
    if 'tables' in bindings:
        result['tables_zip'] = str(inside(resources, bindings['tables']['path']))
    if 'images' in bindings:
        row = bindings['images']
        root = inside(resources, row['root'])
        if sha256_file(inside(root, row['manifest'])) != pin(row['manifest_sha256']):
            raise ValueError('Image manifest pin mismatch')
        if row.get('required_supplement'):
            supplement = row['required_supplement']
            if not matches(inside(root, supplement['path']), supplement):
                raise ValueError('Required original dummy declaration missing/mismatched')
        result['images'] = {'root': str(root), 'manifest_sha256': row['manifest_sha256']}
    if 'main_ui' in bindings:
        row = bindings['main_ui']
        root = inside(resources, row['root'])
        manifest_path = root / 'original_ui.json'
        if sha256_file(manifest_path) != pin(row['manifest_sha256']):
            raise ValueError('Main UI original manifest pin mismatch')
        manifest = read_json(manifest_path, maximum=128 * 1024 * 1024)
        if (not isinstance(manifest, dict) or manifest.get('schema') != 'twilight-original-ui-v1'
                or any(not isinstance(manifest.get(key), dict) for key in ('scenes', 'files', 'atlases'))
                or not isinstance(manifest.get('blockers'), list) or manifest['blockers']):
            raise ValueError('Main UI original pack contract is incomplete or has blockers')
        result['main_ui'] = {'root': str(root), 'manifest_sha256': row['manifest_sha256']}
        if row.get('expected_composition'):
            expected = row['expected_composition']
            composition = manifest.get('selection_contract')
            if (not isinstance(composition, dict)
                    or any(composition.get(key) != expected[key]
                           for key in ('schema', 'mode', 'extends_manifest_sha256'))
                    or any(key not in composition for key in ('retained_base_files', 'retained_base_node_scopes'))):
                raise ValueError('Formal combined UI composition handoff does not match its original manifest')
            # Retention fields stay opaque and unchanged; their exact bytes
            # are covered by the supplied manifest pin, not a guessed schema.
            result['main_ui']['expected_composition'] = expected
            result['main_ui']['owner_code_contract'] = combined_ui_code_contract(code_root)
            if code_root is not None:
                for blocker in result['main_ui']['owner_code_contract']['blockers']:
                    log('COMBINED UI CODE PENDING: ' + blocker)
        main_ui_document = manifest
    if 'world_map' in bindings:
        row = bindings['world_map']
        path = inside(resources, row['contract_path'])
        digest = pin(row['contract_sha256'])
        if sha256_file(path) != digest:
            raise ValueError('World-map relation pin mismatch')
        document = read_json(path, maximum=4 * 1024 * 1024)
        if not isinstance(document, dict) or not isinstance(document.get('image_infos'), list):
            raise ValueError('World-map relation input does not match the existing adapter')
        for source in row.get('source_manifests', []):
            if not matches(inside(resources, source['path']), source):
                raise ValueError('World-map relation source receipt mismatch')
        activation = row.get('enabled')
        enabled = activation if isinstance(activation, bool) else False
        offered = row.get('offered_worlds', {})
        scale = row.get('ratio_scale', 1.0)
        offset = row.get('source_anchor_offset', [0.5, 0.5])
        if activation is not None and not isinstance(activation, bool) or not isinstance(offered, dict):
            raise ValueError('World-map selection requires explicit boolean/offered dictionary')
        for land, offer in offered.items():
            if (not isinstance(land, str) or not re.fullmatch(r'0|[1-9][0-9]*', land)
                    or len(land) > 10 or int(land) > 2147483647
                    or not isinstance(offer, dict) or type(offer.get('world_id')) is not int
                    or not 1 <= offer['world_id'] <= 2147483647
                    or 'label' in offer and (not isinstance(offer['label'], str) or not offer['label'])):
                raise ValueError('World-map offer requires exact decimal Land and explicit World ID')
        if (row.get('coordinate_policy') != 'OWN_SOURCE_CELL_CENTER_FIELD_RATIO_V1'
                or type(scale) not in (int, float) or not math.isfinite(scale) or not 0 < scale <= 1000000
                or not isinstance(offset, list) or len(offset) != 2
                or any(type(x) not in (int, float) or not math.isfinite(x) or abs(x) > 1 for x in offset)):
            raise ValueError('World-map OWN coordinate configuration is invalid')
        if persistent_contracts is not None:
            path = persistent_contract(path, persistent_contracts, digest)
        result['world_map'] = {'enabled': enabled, 'contract_path': str(path),
                               'contract_sha256': digest, 'offered_worlds': offered,
                               'coordinate_policy': row['coordinate_policy'],
                               'ratio_scale': scale, 'source_anchor_offset': offset}
        code = world_map_code_contract(code_root)
        composition_code = result.get('main_ui', {}).get('owner_code_contract')
        if composition_code is not None:
            code['files'].update(composition_code['files'])
            code['blockers'].extend(composition_code['blockers'])
            code['ready'] = not code['blockers']
        inputs = world_map_input_contract(result, resources, bindings, main_ui_document)
        if activation is None:
            inputs['blockers'].append('Explicit fresh world-map activation choice is absent')
            inputs['ready'] = False
        result['world_map'].update(code_contract=code, input_contract=inputs,
                                 ready_for_fresh_install=code['ready'] and inputs['ready'])
        if code_root is not None:
            for blocker in code['blockers'] + inputs['blockers']:
                log('WORLD MAP PENDING: ' + blocker)
    if 'map_definitions' in bindings:
        row = bindings['map_definitions']
        directory = inside(resources, row['directory'])
        if sha256_file(directory / 'manifest.json') != pin(row['manifest_sha256']):
            raise ValueError('Map definition manifest pin mismatch')
        result['map_definitions'] = {'directory': str(directory), 'manifest_sha256': row['manifest_sha256']}
    if 'map_static_spr' in bindings:
        row = bindings['map_static_spr']
        source_root = inside(resources, row['source_root'])
        declarations = inside(resources, row['declaration_path'])
        registry = source_root / 'results/all989_actual_current_M_SP2_registry.json'
        declaration_manifest = inside(resources, row['declaration_manifest'])
        if sha256_file(registry) != pin(row['registry_sha256']):
            raise ValueError('Map SP2 registry pin mismatch')
        if sha256_file(declaration_manifest) != pin(row['declaration_manifest_sha256']):
            raise ValueError('Map SPR declaration manifest pin mismatch')
        for path_key, pin_key in (('text_identity_path', 'text_identity_sha256'),
                                  ('reference_graph_path', 'reference_graph_sha256')):
            if sha256_file(inside(resources, row[path_key])) != pin(row[pin_key]):
                raise ValueError('Required map SPR source evidence pin mismatch: ' + path_key)
        result['map_static_spr'] = {'source_root': str(source_root),
                                   'registry_sha256': row['registry_sha256'],
                                   'declaration_path': str(declarations),
                                   'declaration_manifest_sha256': row['declaration_manifest_sha256']}
    if 'ui_icons' in bindings:
        row = bindings['ui_icons']
        path = inside(resources, row['path'])
        if sha256_file(path) != pin(row['sha256']):
            raise ValueError('UI selection pin mismatch')
        selection = read_json(path)
        if selection.get('schema') != 'source523-original-ui-icon-selection-v1':
            raise ValueError('Unknown original UI selection schema')
        for pack in selection['packs']:
            root = inside(path.parent, pack['root'])
            if sha256_file(root / 'original_ui.json') != pin(pack['manifest_sha256']):
                raise ValueError('UI original root is not available with its exact pin')
        result['ui_icons'] = {'path': str(path), 'sha256': row['sha256']}
    if 'source_bank' in bindings:
        row = bindings['source_bank']
        manifest = inside(resources, row['manifest_path'])
        if sha256_file(manifest) != pin(row['manifest_sha256']):
            raise ValueError('Source bank manifest pin mismatch')
        result['source_bank'] = {'schema': 1, 'enabled': True, 'source_snapshot': 'patch523',
                                 'tables_zip': result['tables_zip'], 'manifest_path': str(manifest),
                                 'manifest_sha256': row['manifest_sha256']}
        if 'overlay_whitelist_path' in row:
            overlay = inside(resources, row['overlay_whitelist_path'])
            if sha256_file(overlay) != pin(row['overlay_whitelist_sha256']):
                raise ValueError('Source bank overlay pin mismatch')
            result['source_bank'].update(overlay_whitelist_path=str(overlay),
                                        overlay_whitelist_sha256=row['overlay_whitelist_sha256'])
    return result


def preserve_user_files(previous, stage, old):
    managed = old.get('files', {})
    for base, folders, files in os.walk(previous, followlinks=False):
        for folder in folders:
            source_dir = Path(base) / folder
            no_links(source_dir)
            # Preserve empty directories as well as files, including Godot's
            # local project settings/cache directory.
            (stage / source_dir.relative_to(previous)).mkdir(parents=True, exist_ok=True)
        for filename in files:
            source = Path(base) / filename
            no_links(source)
            name = source.relative_to(previous).as_posix()
            if name == STATE:
                continue
            if name in managed and matches(source, managed[name]):
                continue
            # Locally changed managed files become user files, never garbage.
            target = stage / name
            if target.exists():
                if file_record(source) != file_record(target):
                    raise ValueError('User/modified file conflicts with new runtime: ' + name)
            else:
                copy_file(source, target)


def clean_owned(root, state, filename):
    """Delete only unchanged, receipt-owned old runtime copies; no glob/rmtree."""
    preserved = []
    for name, record in state.get('files', {}).items():
        # A preexisting, never-overwritten world-map cfg can point at an older
        # version's original relation. Retain those source paths as well as the
        # new stable copy, including receipts written by older installers.
        if filename == RESOURCE_STATE and (name in state.get('retained_files', [])
                or name.startswith(('source-ui/', 'ui/'))
                or PurePosixPath(name).name == 'all331_current_file_identity_and_pixel_anchor_contracts523.json'):
            continue
        path = inside(root, name)
        if matches(path, record):
            path.unlink()
        elif path.exists():
            preserved.append(name)
    metadata = root / filename
    if metadata.is_file() and read_json(metadata) == state:
        metadata.unlink()
    for name in sorted(state.get('directories', []), key=lambda x: (-x.count('/'), x)):
        path = inside(root, name)
        try:
            path.rmdir()
        except OSError:
            pass
    try:
        root.rmdir()
    except OSError:
        log('Preserved source, user or modified files in ' + str(root))
    return preserved


def managed_directories(files):
    return sorted({parent.as_posix() for name in files
                   for parent in relative(name).parents if str(parent) != '.'})


def publish(root, stage, state, work):
    journal_path = work / 'switch.json'
    if journal_path.exists():
        raise ValueError('Unfinished switch journal; rerun to recover before installing')
    old = owned_state(root) if root.exists() else {}
    if root.exists():
        if not root.is_dir() or not old and any(root.iterdir()):
            raise ValueError('Existing folder is not owned by this installer. No files changed.')
        preserve_user_files(root, stage, old)
    json_write(stage / STATE, state)
    backup = root.with_name('.' + root.name + '.previous-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
    journal = {'schema': 1, 'root': str(root), 'stage': str(stage), 'backup': str(backup),
               'had_previous': root.exists(), 'old_state': old, 'new_state': state}
    json_write(journal_path, journal)
    try:
        if root.exists():
            os.replace(root, backup)
        os.replace(stage, root)
    except BaseException:
        if not root.exists() and backup.exists():
            os.replace(backup, root)
        raise
    # New state is the commit point. Cleanup failures never undo this version.
    if backup.exists():
        clean_owned(backup, old, STATE)
    journal_path.unlink()
    return old


def recover(work, root):
    path = work / 'switch.json'
    if not path.exists():
        return
    journal = read_json(path)
    stage = Path(journal['stage'])
    backup = Path(journal['backup'])
    if (journal.get('root') != str(root) or stage.parent != root.parent
            or not stage.name.startswith('.' + root.name + '.next-')
            or backup.parent != root.parent or not backup.name.startswith('.' + root.name + '.previous-')):
        raise ValueError('Invalid switch journal; preserved for review')
    for candidate in (root, stage, backup):
        no_links(candidate)
    if root.exists() and owned_state(root) == journal['new_state']:
        verify_owned(root, journal['new_state'])
        if backup.exists():
            clean_owned(backup, journal['old_state'], STATE)
    elif not root.exists() and backup.exists():
        os.replace(backup, root)
        log('Recovered previous runtime after interrupted switch.')
    elif not root.exists() and not journal['had_previous'] and stage.exists():
        if owned_state(stage) != journal['new_state']:
            raise ValueError('Incomplete staged installation; no switch or cleanup performed')
        verify_owned(stage, journal['new_state'])
        os.replace(stage, root)
    elif not root.exists() or owned_state(root) != journal['old_state']:
        raise ValueError('Uncertain interrupted switch; no files deleted')
    path.unlink()


def verify_owned(root, state):
    for name, record in state['files'].items():
        if not matches(inside(root, name), record):
            raise ValueError('New runtime integrity is uncertain; previous version retained: ' + name)


@contextmanager
def install_lock(path):
    no_links(path)
    with path.open('a') as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('Another installation is running') from None
        yield


def install(args):
    candidate = args.project.expanduser()
    if candidate.is_symlink():
        raise ValueError('The project itself cannot be a symlink')
    # Termux deliberately supplies storage/downloads as an Android storage
    # symlink. Resolve the selected parent once, then reject links below it.
    root = candidate.parent.resolve() / candidate.name
    no_links(root)
    if not root.parent.is_dir():
        raise ValueError('Android Download is unavailable. Run termux-setup-storage once.')
    # Kept in private Termux HOME for executable Git and credential-free cache.
    candidate_cache = args.cache.expanduser()
    if candidate_cache.is_symlink():
        raise ValueError('Installer cache itself cannot be a symlink')
    cache = candidate_cache.parent.resolve() / candidate_cache.name
    no_links(cache)
    cache.mkdir(parents=True, exist_ok=True)
    cache = cache.resolve()
    key = hashlib.sha256(str(root).encode()).hexdigest()[:16]
    work = cache / key
    work.mkdir(exist_ok=True)
    resources = root.with_name('.' + root.name + '.resources')
    no_links(resources)
    resources.mkdir(exist_ok=True)
    with install_lock(work / 'install.lock'):
        recover(work, root)
        plan, plan_digest = fetch_plan(args, work)
        if plan.get('schema') != 1 or not isinstance(plan.get('packs'), list) or not plan['packs']:
            raise ValueError('Unknown/empty private handoff schema')
        if any(p.get('activate') is False for p in plan['packs']):
            raise ValueError('Pending packs cannot be active dependencies')
        for message in plan.get('blockers', []):
            log('HANDOFF PENDING: ' + str(message))
        if root.exists() and not owned_state(root) and any(root.iterdir()):
            raise ValueError('Existing folder has no ownership receipt from this installer; no automatic takeover')
        transport = DriveTransport(work / 'bundles', token_file=args.token_file,
                                   remote=None if args.token_file else args.remote,
                                   workers=args.workers, progress=log)
        # Bulk ZIPs only: future unknown inputs are never substituted with old packs.
        downloaded = transport.download_many([row for pack in plan['packs'] for row in pack['files']])
        resource_root, resource_state = prepare_resources(plan, downloaded, resources, work)
        code_root, commit, code_inventory = packed_code(work)
        stage = Path(tempfile.mkdtemp(prefix='.' + root.name + '.next-', dir=root.parent))
        files = {}
        log('Preparing new runtime locally; the current game remains in place.')
        for name, expected in code_inventory.items():
            source = inside(code_root, name)
            size = source.stat().st_size
            digest = hashlib.sha1(('blob %d\0' % size).encode())
            with source.open('rb') as handle:
                for block in iter(lambda: handle.read(1024 * 1024), b''):
                    digest.update(block)
            if digest.hexdigest() != expected['blob_sha1']:
                raise ValueError('Git runtime blob verification failed: ' + name)
            target = inside(stage, name)
            copy_file(source, target)
            files[name] = file_record(target)
        bridge = Path(__file__).with_name('private_source_bootstrap.gd')
        copy_file(bridge, inside(stage, GENERATED[1]))
        project = stage / 'project.godot'
        text = project.read_text(encoding='utf-8')
        if '[autoload]' in text:
            if 'TwilightPrivateSources=' in text:
                raise ValueError('Existing bootstrap autoload conflicts with installer')
            text = text.replace('[autoload]', '[autoload]\nTwilightPrivateSources="*res://%s"' % GENERATED[1], 1)
        else:
            text += '\n[autoload]\nTwilightPrivateSources="*res://%s"\n' % GENERATED[1]
        project.write_text(text, encoding='utf-8')
        json_write(stage / GENERATED[0], descriptor(plan, resource_root,
                    persistent_contracts=resources / 'pinned-contracts', code_root=stage))
        for name in ('project.godot', *GENERATED):
            files[name] = file_record(inside(stage, name))
        state = {'schema': 1, 'code_sha': commit, 'plan_sha256': plan_digest, 'files': files,
                 'resource_version': resource_root.name, 'directories': managed_directories(files)}
        previous = publish(root, stage, state, work)
        # Only the immediately previous receipt-owned expanded runtime resource
        # version is eligible. Source archives, unowned folders and modified
        # files are never removed; cached completed ZIPs remain reusable.
        old_version = previous.get('resource_version')
        if old_version and old_version != resource_root.name and re.fullmatch('[0-9a-f]{64}', old_version):
            old_root = resources / old_version
            if old_root.is_dir() and not old_root.is_symlink():
                prior_resources = owned_state(old_root, RESOURCE_STATE)
                if prior_resources.get('identity') == old_version:
                    clean_owned(old_root, prior_resources, RESOURCE_STATE)
        log('INSTALL/UPDATE READY: ' + commit)
        log('Godot Android Editor project: ' + str(root / 'project.godot'))
        log('Paths are prepared by the startup bridge; no per-resource folder selection is required.')
        if plan.get('blockers') or not plan.get('complete', False):
            log('PARTIAL INPUTS: pending UI/sprite/feature-code handoffs above remain unavailable.')
        log('UNVERIFIED: no game run, render, tests or CI were executed by this installer.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path.home() / 'storage/downloads/TWILIGHT_Play')
    parser.add_argument('--cache', type=Path, default=Path.home() / '.cache/twilight-private-install')
    plan_source = parser.add_mutually_exclusive_group()
    plan_source.add_argument('--plan', type=Path, help='Existing private owner handoff JSON')
    plan_source.add_argument('--plan-id', help='Authenticated private Drive installation handoff ID')
    plan_source.add_argument('--plan-inline', help='Owner handoff JSON compressed with zlib and URL-safe base64, supplied in the same command')
    parser.add_argument('--plan-sha256', help='Optional immutable handoff pin; omit to follow owner updates')
    parser.add_argument('--remote', default='twilight-drive', help='Already authorized rclone Drive remote')
    parser.add_argument('--token-file', type=Path, help='Explicit private OAuth token file for HTTP Range resume')
    parser.add_argument('--workers', type=int, choices=(1, 2, 3), default=2, help='Concurrent bundles, not individual images')
    args = parser.parse_args()
    try:
        install(args)
    except (OSError, ValueError, KeyError, RuntimeError, zlib.error, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        log('INSTALL STOPPED: ' + str(error))
        log('The previous runtime, source archives and personal data are preserved. Rerun the same command to reuse verified bundles.')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
