#!/usr/bin/env python3
"""Install/update TWILIGHT using packed Git code and authenticated private ZIPs.

No per-runtime-file HTTP downloads, reset/clean, Drive writes, or game execution.
The private, owner-maintained plan is kept outside the public repository.
"""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import json
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


def read_json(path):
    no_links(path)
    if path.stat().st_size > 32 * 1024 * 1024:
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
        state = {'schema': 1, 'identity': identity, 'files': inventory,
                 'directories': managed_directories(inventory)}
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


def descriptor(plan, resources):
    bindings = plan['bindings']
    result = {'schema': 1}
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
        log('Preserved non-managed/modified files in ' + str(root))
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
        json_write(stage / GENERATED[0], descriptor(plan, resource_root))
        project = stage / 'project.godot'
        text = project.read_text(encoding='utf-8')
        if '[autoload]' in text:
            if 'TwilightPrivateSources=' in text:
                raise ValueError('Existing bootstrap autoload conflicts with installer')
            text = text.replace('[autoload]', '[autoload]\nTwilightPrivateSources="*res://%s"' % GENERATED[1], 1)
        else:
            text += '\n[autoload]\nTwilightPrivateSources="*res://%s"\n' % GENERATED[1]
        project.write_text(text, encoding='utf-8')
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
    parser.add_argument('--plan', type=Path, help='Existing private owner handoff JSON')
    parser.add_argument('--plan-id', help='Authenticated private Drive installation handoff ID')
    parser.add_argument('--plan-sha256', help='Optional immutable handoff pin; omit to follow owner updates')
    parser.add_argument('--remote', default='twilight-drive', help='Already authorized rclone Drive remote')
    parser.add_argument('--token-file', type=Path, help='Explicit private OAuth token file for HTTP Range resume')
    parser.add_argument('--workers', type=int, choices=(1, 2, 3), default=2, help='Concurrent bundles, not individual images')
    args = parser.parse_args()
    try:
        install(args)
    except (OSError, ValueError, KeyError, RuntimeError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        log('INSTALL STOPPED: ' + str(error))
        log('The previous runtime, source archives and personal data are preserved. Rerun the same command to reuse verified bundles.')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
