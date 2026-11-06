"""Explicit adoption of one authenticated manual distribution, never Drive I/O.

Only the pinned private bootstrap index supplies archive names. Resource bytes
stay in place. Existing general-installer adoption/publish rules are untouched.
"""
import hashlib
import os
from pathlib import Path
import stat
import tempfile
import zipfile
import zlib

ROOT_NAME = 'TWILIGHT_Play_Source523_Manual'
RESOURCE_DIR = 'source523_resources'
BOOTSTRAP = 'pack-receipts/bootstrap.json'
SCHEMA = 'twilight-source523-manual-bootstrap-v1'
PLAN_SHA = 'b50b032f051568f9038dc1f82f0af7a4aa0bdc83bed195dece4ff93822b35a43'
STATE = '.twilight_manual_code_state.json'
RESOURCE_PREFIXES = ('maps/', 'map-sprites/', 'map-declarations/', 'map-definitions/',
    'map-image-relations/', 'source523-original-image-pack-final/', 'private-source-bank/',
    'private-sprite-delta-contract/', 'source-ui/', 'ui/', 'tables/', 'pack-receipts/')


def _resource_path(a, value):
    name = a.relative(value).as_posix()
    prefix = ROOT_NAME + '/' + RESOURCE_DIR + '/'
    if name.startswith(prefix):
        name = name[len(prefix):]
    elif name.startswith(RESOURCE_DIR + '/'):
        name = name[len(RESOURCE_DIR) + 1:]
    a.relative(name)
    if not name.startswith(RESOURCE_PREFIXES):
        raise ValueError('Manual archive contains an undeclared resource namespace')
    return name


def _file_digest(path):
    digest = hashlib.sha256()
    crc = 0
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
            crc = zlib.crc32(block, crc)
    return digest.hexdigest(), crc & 0xffffffff


def _manual_inputs(args, a, root):
    resources = a.inside(root, RESOURCE_DIR)
    if not resources.is_dir():
        raise ValueError('The selected manual source523_resources directory is absent; no folder search or creation')
    bootstrap = a.inside(resources, BOOTSTRAP)
    if not args.manual_bootstrap_sha256 or a.sha256_file(bootstrap) != a.pin(args.manual_bootstrap_sha256):
        raise ValueError('Manual bootstrap receipt pin mismatch or missing explicit pin')
    index = a.read_json(bootstrap, maximum=2 * 1024 * 1024)
    if (index.get('schema') != SCHEMA or index.get('root_name') != ROOT_NAME
            or index.get('complete') is not True or not isinstance(index.get('archives'), list)
            or not 1 <= len(index['archives']) <= 128):
        raise ValueError('Manual bootstrap index is incomplete or unsupported')
    own = index.get('files')
    if not isinstance(own, dict) or not own or len(own) > 16:
        raise ValueError('Manual bootstrap requires its bounded owned file receipts')
    if not {'.gdignore', 'manual-install-plan.json', 'ui/source523-original-ui-icon-selection.json'} <= set(own):
        raise ValueError('Manual bootstrap lacks its required original selection/plan/import boundary')
    components = index.get('components')
    if (not isinstance(components, dict) or set(components) != {'maps', 'images', 'sprite', 'ui'}
            or any(not isinstance(row, dict) or type(row.get('files')) is not int
                   or type(row.get('bytes')) is not int or row['files'] < 1 or row['bytes'] < 1
                   for row in components.values())
            or index.get('resource_files') != sum(row['files'] for row in components.values())
            or index.get('resource_bytes') != sum(row['bytes'] for row in components.values())):
        raise ValueError('Manual bootstrap lacks the complete producer inventory totals')
    for name, record in own.items():
        if not a.matches(a.inside(resources, name), record):
            raise ValueError('Manual bootstrap component file differs: ' + name)
    plan_path = a.inside(resources, 'manual-install-plan.json')
    if a.sha256_file(plan_path) != PLAN_SHA:
        raise ValueError('Manual source plan differs from its fixed official v30 contract')
    plan = a.read_json(plan_path)
    archives = args.manual_archives.expanduser().resolve() if args.manual_archives else root.parent
    a.no_links(archives)
    expected = {}
    names = set()
    for row in index['archives']:
        if not isinstance(row, dict) or row.get('component') not in components:
            raise ValueError('Manual archive has no declared producer component')
        name = row.get('name')
        if (not isinstance(name, str) or len(a.relative(name).parts) != 1
                or not name.endswith('.zip') or name in names):
            raise ValueError('Manual index requires unique exact local ZIP basenames')
        names.add(name)
        if type(row.get('bytes')) is not int or row['bytes'] <= 0:
            raise ValueError('Manual archive requires its exact positive byte length')
        a.pin(row.get('sha256'))
        archive = a.inside(archives, name)
        if not a.matches(archive, row):
            raise ValueError('Required downloaded manual ZIP absent or changed: ' + name)
        # Central-directory inspection only: do not decompress or re-extract.
        with zipfile.ZipFile(archive) as source:
            for info in source.infolist():
                mode = info.external_attr >> 16
                if (info.flag_bits & 1 or stat.S_ISLNK(mode)
                        or mode and stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR)):
                    raise ValueError('Manual ZIP contains an unsafe entry')
                if info.is_dir():
                    a.relative(info.filename.rstrip('/'))
                    continue
                relative = _resource_path(a, info.filename)
                record = {'bytes': info.file_size, 'crc32': info.CRC}
                if relative in expected:
                    raise ValueError('Manual components overlap a file: ' + relative)
                if relative in own or relative == BOOTSTRAP:
                    raise ValueError('A producer ZIP overlaps the bootstrap component')
                expected[relative] = record
    if {row['component'] for row in index['archives']} != set(components):
        raise ValueError('Manual archive list omits a required producer component')
    if len(expected) > 200000:
        raise ValueError('Manual resource inventory exceeds the declared distribution bound')
    if (index.get('resource_files') != len(expected)
            or index.get('resource_bytes') != sum(record['bytes'] for record in expected.values())):
        raise ValueError('Manual archive set does not match the complete producer inventory totals')
    actual = set()
    total = 0
    for base, folders, files in os.walk(resources, followlinks=False):
        for folder in folders:
            a.no_links(Path(base) / folder)
        for name in files:
            path = Path(base) / name
            a.no_links(path)
            if not path.is_file():
                raise ValueError('Manual resource is not a regular file')
            relative = path.relative_to(resources).as_posix()
            actual.add(relative)
            if relative in own or relative == BOOTSTRAP:
                continue
            wanted = expected.get(relative)
            if wanted is None or path.stat().st_size != wanted['bytes']:
                raise ValueError('Unreceipted or changed manual resource: ' + relative)
            _, crc = _file_digest(path)
            if crc != wanted['crc32']:
                raise ValueError('Extracted resource CRC differs from its authenticated ZIP: ' + relative)
            total += wanted['bytes']
    if set(expected) - actual:
        raise ValueError('Manual ZIP extraction is incomplete: ' + sorted(set(expected) - actual)[0])
    a.log('Manual original resources verified in place: %d files, %d bytes. No Drive calls, extraction or resource copy.' % (len(expected), total))
    # The original manifest/CSB/config pins must pass before any Git download.
    # This prepares only an in-memory descriptor; no user cfg is written here.
    a.descriptor(plan, resources, code_root=None)
    return plan, resources


def _relative_descriptor(value, root):
    """Only paths below the fixed project become portable; no source JSON edit."""
    if isinstance(value, dict):
        return {key: _relative_descriptor(item, root) for key, item in value.items()}
    if isinstance(value, list):
        return [_relative_descriptor(item, root) for item in value]
    if isinstance(value, str) and value.startswith(str(root) + os.sep):
        return Path(value).relative_to(root).as_posix()
    return value


def _code_name(a, value):
    name = a.relative(value).as_posix()
    if name.startswith(RESOURCE_DIR + '/') or name in (RESOURCE_DIR, STATE):
        raise ValueError('Manual code transaction cannot own resource or state paths')
    if name not in ('project.godot', 'Main.tscn', *a.GENERATED) and name.split('/')[0] not in a.RUNTIME_ROOTS:
        raise ValueError('Manual code transaction contains an unexpected path')
    return name


def _recover_code(a, root, work):
    journal = work / 'manual-code-switch.json'
    if not journal.exists():
        return
    value = a.read_json(journal)
    stage = Path(value['stage'])
    if (value.get('schema') != 1 or value.get('root') != str(root)
            or stage.parent != root.parent or not stage.name.startswith('.' + root.name + '.manual-code-')):
        raise ValueError('Unknown manual-code journal; all files preserved')
    a.no_links(stage)
    state_path = a.inside(root, STATE)
    committed = state_path.exists() and a.read_json(state_path) == value['new_state']
    if not committed:
        for name, record in value['new_state']['files'].items():
            _code_name(a, name)
            target = a.inside(root, name)
            previous = value['previous_files'].get(name)
            backup = a.inside(stage / 'previous', name)
            if previous and a.matches(target, previous):
                continue
            if previous:
                if not a.matches(backup, previous) or target.exists() and not a.matches(target, record):
                    raise ValueError('Manual code recovery conflicts with a user change; all remaining files preserved')
                target.parent.mkdir(parents=True, exist_ok=True)
                os.replace(backup, target)
            elif target.exists():
                if not a.matches(target, record):
                    raise ValueError('Manual code recovery found a modified new file; preserved')
                target.unlink()
        a.log('Recovered interrupted manual code transaction; original resources were untouched.')
    # Only unchanged, journal-owned code copies are eligible for cleanup.
    for group, records in (('payload', value['new_state']['files']), ('previous', value['previous_files'])):
        base = stage / group
        for name, record in records.items():
            _code_name(a, name)
            path = a.inside(base, name)
            if a.matches(path, record):
                path.unlink()
        for name in sorted(a.managed_directories(records), key=lambda value: len(a.relative(value).parts), reverse=True):
            path = a.inside(base, name)
            if path.is_dir():
                try:
                    path.rmdir()
                except OSError:
                    pass
        try:
            base.rmdir()
        except OSError:
            pass
    try:
        stage.rmdir()
    except OSError:
        pass
    journal.unlink()


def install_manual(args, a):
    if args.plan or args.plan_id or args.plan_inline or args.token_file or args.diagnose_bundle:
        raise ValueError('Manual mode uses only its local pinned bootstrap index, never a Drive plan/token/diagnostic')
    candidate = args.project.expanduser()
    if candidate.name != ROOT_NAME or candidate.is_symlink():
        raise ValueError('Manual mode requires the explicitly selected TWILIGHT_Play_Source523_Manual folder')
    root = candidate.parent.resolve() / candidate.name
    a.no_links(root)
    if not root.is_dir():
        raise ValueError('Selected extracted manual folder is missing; no automatic search or creation')
    plan, resources = _manual_inputs(args, a, root)
    cache = args.cache.expanduser()
    if cache.is_symlink():
        raise ValueError('Manual code cache cannot be a symlink')
    cache = cache.parent.resolve() / cache.name
    a.no_links(cache)
    work = cache / ('manual-' + hashlib.sha256(str(root).encode()).hexdigest()[:16])
    work.mkdir(parents=True, exist_ok=True)
    with a.install_lock(work / 'install.lock'):
        _recover_code(a, root, work)
        state_path = a.inside(root, STATE)
        old = a.read_json(state_path) if state_path.exists() else {}
        if old and (old.get('schema') != 1 or old.get('kind') != 'twilight-manual-code' or old.get('root') != str(root)):
            raise ValueError('Manual code ownership differs; no takeover')
        if old and not isinstance(old.get('files'), dict):
            raise ValueError('Manual code receipt has no valid file inventory')
        if not old and any(path.name != RESOURCE_DIR for path in root.iterdir()):
            raise ValueError('Unmanaged files exist beside manual resources; no automatic adoption or overwrite')
        source, commit, inventory = a.packed_code(work)
        a.preflight_required_code(plan, source)
        selected = a.descriptor(plan, resources, code_root=source)
        required = [(selected.get('source_bank', {}), 'ready_for_fresh_install', 'Sprite bank'),
                    (selected.get('world_map', {}), 'ready_for_fresh_install', 'world map'),
                    (selected.get('native_item_input', {}).get('code_contract', {}), 'ready', 'native item owner'),
                    (selected.get('ui_icons', {}).get('native_scene_code_contract', {}), 'ready', 'original icon owner')]
        for contract, field, label in required:
            if contract.get(field) is not True:
                raise ValueError('Selected manual source consumer is pending in actual main: ' + label)
        # Current source consumers use this one pinned archive in place.
        # Manual mode does not populate old fixed-path compatibility ZIPs.
        selected['legacy_table_copies'] = False
        code_bytes = sum(a.inside(source, name).stat().st_size for name in inventory)
        if min(a.shutil.disk_usage(root.parent).free, a.shutil.disk_usage(work).free) < 2 * code_bytes + 32 * 1024 * 1024:
            raise ValueError('Insufficient space for code-only staging/rollback; no resources copied or removed')
        stage = Path(tempfile.mkdtemp(prefix='.' + root.name + '.manual-code-', dir=root.parent))
        payload = stage / 'payload'
        payload.mkdir()
        files = {}
        for name, expected in inventory.items():
            _code_name(a, name)
            original = a.inside(source, name)
            digest = hashlib.sha1(('blob %d\0' % original.stat().st_size).encode())
            with original.open('rb') as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(block)
            if digest.hexdigest() != expected['blob_sha1']:
                raise ValueError('Minimal Git code blob differs: ' + name)
            a.copy_file(original, a.inside(payload, name))
            files[name] = a.file_record(a.inside(payload, name))
        a.copy_file(Path(a.__file__).with_name('private_source_bootstrap.gd'), a.inside(payload, a.GENERATED[1]))
        project = payload / 'project.godot'
        text = project.read_text(encoding='utf-8')
        if 'TwilightPrivateSources=' in text:
            raise ValueError('Manual bootstrap autoload conflicts with the selected code')
        autoload = 'TwilightPrivateSources="*res://%s"' % a.GENERATED[1]
        text = text.replace('[autoload]', '[autoload]\n' + autoload, 1) if '[autoload]' in text else text + '\n[autoload]\n' + autoload + '\n'
        project.write_text(text, encoding='utf-8')
        a.json_write(payload / a.GENERATED[0], _relative_descriptor(selected, root))
        for name in ('project.godot', *a.GENERATED):
            files[name] = a.file_record(a.inside(payload, name))
        for name, record in files.items():
            target = a.inside(root, name)
            previous = old.get('files', {}).get(name)
            if target.exists() and (not previous or not a.matches(target, previous)):
                raise ValueError('User/unmanaged code conflicts with the selected update: ' + name)
        new = {'schema': 1, 'kind': 'twilight-manual-code', 'root': str(root),
            'code_sha': commit, 'bootstrap_sha256': args.manual_bootstrap_sha256,
            'plan_sha256': PLAN_SHA, 'files': files}
        previous_files = {name: old['files'][name] for name in files if a.inside(root, name).exists()}
        journal = {'schema': 1, 'root': str(root), 'stage': str(stage), 'old_state': old,
                   'previous_files': previous_files, 'new_state': new}
        a.json_write(work / 'manual-code-switch.json', journal)
        for name in files:
            target = a.inside(root, name)
            if target.exists():
                if name not in previous_files or not a.matches(target, previous_files[name]):
                    raise ValueError('Code changed during manual publication; preserved for journal recovery')
                previous = a.inside(stage / 'previous', name)
                previous.parent.mkdir(parents=True, exist_ok=True)
                os.replace(target, previous)
            target.parent.mkdir(parents=True, exist_ok=True)
            os.replace(a.inside(payload, name), target)
        a.json_write(state_path, new)
        _recover_code(a, root, work)
    a.log('MANUAL CODE READY: %s. Resources remain in place; no Drive/resource download or extraction was performed.' % commit)
    a.log('UNVERIFIED: no game, render, tests, compilation or CI was executed.')
