#!/usr/bin/env python3
"""Install/update TWILIGHT using packed Git code and authenticated private ZIPs.

No per-runtime-file HTTP downloads, reset/clean, Drive writes, or game execution.
The private, owner-maintained plan is kept outside the public repository.
"""
import argparse
import base64
import copy
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import bisect
import io
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

from private_drive_transport import DriveTransport, DownloadError, sha256_file, _DriveRedirects, rclone_read, diagnose_rclone_bundle

REPO = 'https://github.com/zoog136-hash/-.git'
STATE = '.twilight_private_install_state.json'
RESOURCE_STATE = '.twilight_resource_state.json'
TABLES_SOURCE_BYTES = 25031173
TABLES_SOURCE_SHA256 = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
GENERATED = ('twilight_private_install.json', 'scripts/install/private_source_bootstrap.gd')
RUNTIME_ROOTS = {'addons', 'assets', 'data', 'external_map_packs', 'scenes', 'scripts', 'shaders'}
RUNTIME_FILES = {'project.godot', 'Main.tscn', 'external_map_packs/.gdignore'}
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
    # Status and failures must remain visible when the calling terminal has
    # redirected stdout (curl progress and the interactive prompt use stderr).
    print(message, file=sys.stderr, flush=True)


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
    # Private original packs are separate installer inputs. A filename suffix
    # is not permission to hydrate every historical image/animation family.
    # Git assets are selected below only through explicit source dependencies.
    if path.parts[0] == 'assets':
        return False
    if path.parts[0] == 'data':
        # Model/report files are not all runtime inputs. Exact source literals
        # and bounded declared namespaces add required metadata below.
        return False
    if any(name == x or name.startswith(x + '/') for x in OFFLINE_DIRS):
        return False
    if name.startswith('data/pr122_'):
        return False
    if path.parts[0] == 'external_map_packs':
        # New maps arrive in pinned private bundles, not the historical Git
        # PNG/map archives. Explicit code references are checked separately.
        return False
    code_metadata = {
        'scripts': {'.gd', '.uid', '.gdshader', '.gdshaderinc'},
        'addons': {'.gd', '.uid', '.gdextension', '.json', '.cfg', '.gdshader', '.gdshaderinc'},
        'scenes': {'.tscn', '.uid'},
        'data': {'.json', '.bin', '.nav', '.cfg'},
        'shaders': {'.gdshader', '.gdshaderinc'},
    }
    return path.suffix.lower() in code_metadata.get(path.parts[0], set()) and not name.endswith(('.bak', '.tmp', '.backup'))


def prefetch_runtime_blobs(repo, entries):
    """Request only selected object IDs together, never all asset trees."""
    # --missing=print inspects promisor metadata without materializing missing
    # image blobs. Reuse existing code objects on updates instead of requesting
    # every selected SHA again with a new no-negotiation fetch.
    objects = run(['git', 'rev-list', '--objects', '--all', '--missing=print'],
                  cwd=repo, capture=True)
    missing = {line[1:] for line in objects.splitlines() if line.startswith('?')}
    wants = sorted({entry['blob_sha1'] for entry in entries.values()} & missing)
    if wants:
        run(['git', '-c', 'fetch.negotiationAlgorithm=noop', 'fetch',
             '--no-tags', '--no-write-fetch-head', '--recurse-submodules=no',
             '--filter=blob:none', 'origin', '--stdin'], cwd=repo,
            input_text='\n'.join(wants) + '\n')


def original_runtime_dependencies(repo, tree, inventory):
    """Static, fail-closed boundary; not evidence that the game was run.

    Existing code/data remains intact. Historical visual packs are never
    reintroduced through a data catalog or an optional load. Required legacy
    preloads must be removed by their code owner before this target can run.
    """
    inspect_suffixes = {'.gd', '.tscn', '.tres', '.godot', '.gdshader', '.gdshaderinc', '.json'}
    source = {name: row for name, row in inventory.items()
              if PurePosixPath(name).suffix in inspect_suffixes}
    prefetch_runtime_blobs(repo, source)
    examined = set()
    blockers = []
    omitted = set()
    while source:
        dependencies = {}
        process = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=repo,
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=subprocess.DEVNULL)
        try:
            for name, row in sorted(source.items()):
                process.stdin.write((row['blob_sha1'] + '\n').encode('ascii'))
                process.stdin.flush()
                header = process.stdout.readline().decode('ascii').split()
                if (len(header) != 3 or header[0] != row['blob_sha1']
                        or header[1] != 'blob' or not header[2].isdigit()):
                    raise ValueError('Missing selected runtime source object: ' + name)
                size = int(header[2])
                if size > 16 * 1024 * 1024:
                    raise ValueError('Oversized runtime dependency source: ' + name)
                data = process.stdout.read(size)
                if len(data) != size or process.stdout.read(1) != b'\n':
                    raise ValueError('Truncated runtime dependency source: ' + name)
                text = data.decode('utf-8')
                examined.add(name)
                required = set(re.findall(r'preload\s*\(\s*[\"\']res://([^\"\']+)[\"\']', text))
                if PurePosixPath(name).suffix in {'.tscn', '.tres', '.godot'}:
                    required.update(re.findall(r'res://([^\"\'\s)]+)', text))
                for reference in set(re.findall(r'res://([^\"\'\s)]+)', text)):
                    if reference not in tree:
                        # Preserve explicit dynamically indexed model families
                        # without pulling every report below data/. Actual
                        # names still come from this pinned Git tree.
                        prefix = re.split(r'[%{]', reference, maxsplit=1)[0]
                        namespace = prefix.rstrip('/') + '/'
                        if (prefix.startswith('data/') and prefix != 'data/'
                                and ('%' in reference or '{' in reference
                                     or any(path.startswith(namespace) for path in tree))):
                            suffix = PurePosixPath(reference).suffix.lower()
                            for path, entry in tree.items():
                                if (path.startswith(prefix if ('%' in reference or '{' in reference) else namespace)
                                        and PurePosixPath(path).suffix.lower() in {'.json', '.bin', '.nav', '.cfg'}
                                        and (not suffix or PurePosixPath(path).suffix.lower() == suffix)
                                        and path not in inventory):
                                    dependencies[path] = entry
                        continue  # Dynamic paths are not invented or expanded.
                    relative(reference)
                    if (reference.split('/', 1)[0] not in RUNTIME_ROOTS
                            and reference not in RUNTIME_FILES):
                        if reference in required:
                            blockers.append(name + ' -> non-runtime dependency ' + reference)
                        continue
                    suffix = PurePosixPath(reference).suffix.lower()
                    historical = (reference.startswith('external_map_packs/') or
                                  reference.startswith('assets/') and suffix not in
                                  {'.ttf', '.otf', '.gdshader', '.gdshaderinc'} or
                                  suffix in {'.png', '.jpg', '.jpeg', '.webp', '.svg',
                                             '.ogg', '.wav', '.mp3', '.flac'})
                    if historical:
                        omitted.add(reference)
                        if reference in required:
                            blockers.append(name + ' -> ' + reference)
                        continue
                    if reference not in inventory:
                        dependencies[reference] = tree[reference]
        finally:
            process.stdin.close()
            if process.poll() is None:
                process.terminate()
            process.wait()
            process.stdout.close()
        # Do not fetch any legacy image/audio merely to make a preload parse.
        if blockers:
            log('Original-only code dependency blockers (no legacy visual pack downloaded):')
            for blocker in sorted(set(blockers))[:32]:
                log('  ' + blocker)
            raise ValueError('Current main still requires %d legacy visual preloads/resources; owner code integration is required, not a larger download or fallback pack.' % len(set(blockers)))
        if not dependencies:
            break
        prefetch_runtime_blobs(repo, dependencies)
        inventory.update(dependencies)
        source = {name: row for name, row in dependencies.items()
                  if name not in examined and PurePosixPath(name).suffix in inspect_suffixes}
    log('Original-only Git selection: %d files; %d explicit historical visual references omitted. Dynamic catalog asset trees are not expanded.' % (len(inventory), len(omitted)))
    return inventory


def packed_code(cache):
    """Git checkout fetches missing sparse blobs together in a pack, not raw URLs."""
    # Preserve the old oversized/failed checkout. Never reset, clean or prune
    # it automatically. This version has an explicit private ownership receipt.
    repo = cache / 'github-runtime-minimal-v1'
    owner_path = cache / 'github-runtime-minimal-v1.owner.json'
    log('Minimal Git code cache: ' + str(repo))
    log('Git cache filesystem free bytes: %d' % shutil.disk_usage(cache).free)
    legacy_repo = cache / 'github-runtime'
    if legacy_repo.exists():
        log('Previous Git cache preserved without cleanup: ' + str(legacy_repo))
    owner = {'schema': 1, 'role': 'twilight-installer-code-cache',
             'origin': REPO, 'directory': str(repo.resolve())}
    no_links(owner_path)
    no_links(repo)
    if owner_path.exists():
        if read_json(owner_path) != owner:
            raise ValueError('Unexpected minimal code-cache owner; nothing changed')
    elif repo.exists():
        raise ValueError('Existing minimal code cache has no ownership receipt; no takeover')
    else:
        json_write(owner_path, owner)
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
    tree = {}
    for entry in output.split(b'\0'):
        if not entry:
            continue
        header, raw_name = entry.split(b'\t', 1)
        mode, kind, digest = header.decode('ascii').split()
        name = raw_name.decode('utf-8')
        if kind != 'blob' or mode not in ('100644', '100755'):
            if not runtime_path(name):
                continue
            raise ValueError('Unsupported runtime tree entry: ' + name)
        tree[name] = {'blob_sha1': digest}
        if runtime_path(name):
            inventory[name] = tree[name]
    if not {'project.godot', 'Main.tscn'}.issubset(inventory):
        raise ValueError('Incomplete Godot runtime tree')
    inventory = original_runtime_dependencies(repo, tree, inventory)
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
            # Presence in listremotes is not proof of completed OAuth setup.
            # This exact plan read is the access preflight, before Git/resource
            # downloads. Do not list unrelated private files or auto-reconnect.
            log('Checking access to the selected private plan; a configured remote name alone does not confirm authentication.')
            command = ['rclone', 'backend', 'copyid', args.remote + ':', args.plan_id,
                       str(temporary), '--retries', '1', '--low-level-retries', '1',
                       '--stats', '0']
            result, summary = rclone_read(command)
            if result.returncode:
                raise DownloadError('Private plan read failed. ' + summary)
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


class ArchiveStage:
    """Ownership of files created during one new, unpublished extraction.

    Metadata members are explicit stage-relative JSON/JSONL.GZ paths supplied by the
    private handoff. Original/raw namespaces can never be metadata replacements.
    This object cannot adopt a populated or already published resource version.
    """
    def __init__(self, root, *, metadata_members=()):
        no_links(root)
        self.root = Path(os.path.abspath(root))
        if not self.root.is_dir() or any(self.root.iterdir()):
            raise ValueError('Archive ownership requires an empty NEW staging directory')
        self._files = {}
        self._metadata = set()
        cases = set()
        for name in metadata_members:
            self._metadata_name(name)
            if name.casefold() in cases:
                raise ValueError('Duplicate/case-aliased staging metadata declaration')
            cases.add(name.casefold())
            self._metadata.add(name)

    @staticmethod
    def _metadata_name(name):
        member = relative(name)
        if (not (name.casefold().endswith('.json') or name.casefold().endswith('.jsonl.gz'))
                or any(part.casefold() in ('original', 'originals', 'raw',
                                           'raw_originals', 'selected_originals',
                                           'source', 'sources', 'actor', 'actors')
                       for part in member.parts[:-1])):
            raise ValueError('Only explicitly declared non-original JSON/JSONL.GZ metadata can be replaced')

    def _key(self, target, *, allow_root=False):
        no_links(target)
        if (self.root / RESOURCE_STATE).exists():
            raise ValueError('An extraction overlay cannot modify a published resource version')
        try:
            name = Path(os.path.abspath(target)).relative_to(self.root).as_posix()
        except ValueError:
            raise ValueError('Archive overlay target lies outside its NEW staging directory') from None
        if allow_root and name == '.':
            return ''
        relative(name)
        return name

    def authorize_metadata(self, expected):
        """Classify exact owned path -> SHA256 pairs after a pinned checkpoint.

        The caller derives these paths and pins from the exact owner manifest;
        naming a JSON file alone never adopts an unknown existing file.
        """
        if not isinstance(expected, dict) or not expected:
            raise ValueError('Metadata authorization needs exact staged member pins')
        names = []
        for name, digest in expected.items():
            self._metadata_name(name)
            target = inside(self.root, name)
            key = self._key(target)
            previous = self._files.get(key)
            if (not previous or previous['sha256'] != pin(digest)
                    or not matches(target, previous)):
                raise ValueError('Metadata authorization lacks matching staged ownership: ' + name)
            if any(old.casefold() == key.casefold() and old != key for old in self._metadata):
                raise ValueError('Case-aliased staging metadata authorization')
            names.append(key)
        self._metadata.update(names)

    def _metadata_before(self, target, expected_sha256):
        name = self._key(target)
        if name not in self._metadata:
            raise ValueError('Archive replacement is not declared staging metadata: ' + name)
        previous = self._files.get(name)
        if (not previous or previous['sha256'] != pin(expected_sha256)
                or not matches(target, previous)):
            raise ValueError('Archive replacement does not match its staged ownership/checkpoint: ' + name)

    def _created(self, target, record):
        self._files[self._key(target)] = dict(record)

    def checkpoint(self, expected):
        """Verify an explicit stage-relative metadata path -> SHA256 mapping."""
        if not isinstance(expected, dict) or not expected:
            raise ValueError('A metadata checkpoint needs explicit member pins')
        for name, digest in expected.items():
            self._metadata_before(inside(self.root, name), digest)


class PinnedArchiveDelta:
    """An exact member inventory over an owned, unpublished base extraction.

    Existing members still use ArchiveStage's metadata-only replacement rules.
    Actor/original/raw members may be added only at absent paths. The final
    independent ZIP contains just the target manifest, after all other members.
    """
    def __init__(self, staged, root, inventory_path, *, inventory_sha256,
                 inventory_bytes, base_manifest_sha256, target_manifest_sha256,
                 manifest_path, part_count, member_count):
        if not isinstance(staged, ArchiveStage):
            raise ValueError('A delta needs NEW staging ownership')
        staged._key(root, allow_root=True)
        self.staged = staged
        self.root = Path(os.path.abspath(root))
        self.manifest_path = str(relative(manifest_path))
        self.base_pin = pin(base_manifest_sha256)
        self.target_pin = pin(target_manifest_sha256)
        if (type(inventory_bytes) is not int or not 0 < inventory_bytes <= 64 * 1024 * 1024
                or type(part_count) is not int or not 1 <= part_count <= 128
                or type(member_count) is not int or not 1 <= member_count <= 250000):
            raise ValueError('Invalid bounded delta inventory/part/member declaration')
        no_links(inventory_path)
        if not matches(inventory_path, {'bytes': inventory_bytes,
                                        'sha256': pin(inventory_sha256)}):
            raise ValueError('Delta member inventory size/SHA256 mismatch')
        document = read_json(inventory_path, maximum=64 * 1024 * 1024)
        if (not isinstance(document, dict) or document.get('schema') != 1
                or document.get('base_manifest_sha256') != self.base_pin
                or document.get('target_manifest_sha256') != self.target_pin
                or not isinstance(document.get('entries'), list)
                or len(document['entries']) != member_count):
            raise ValueError('Delta inventory does not bind the declared base and target')
        base_target = inside(self.root, self.manifest_path)
        base_record = staged._files.get(staged._key(base_target))
        if (not base_record or base_record['sha256'] != self.base_pin
                or not matches(base_target, base_record)):
            raise ValueError('Delta base manifest is not the exact owned staged checkpoint')
        self.members = {}
        self.old_records = {}
        cases = set()
        parent = relative(self.manifest_path).parent
        for row in document['entries']:
            if (not isinstance(row, dict)
                    or set(row) != {'relative_path', 'bytes', 'sha256', 'replaces_base_path'}
                    or type(row.get('bytes')) is not int or row['bytes'] < 0
                    or type(row.get('replaces_base_path')) is not bool):
                raise ValueError('Invalid delta member proof')
            name = str(relative(row['relative_path']))
            if parent != PurePosixPath('.') and parent not in relative(name).parents:
                raise ValueError('Delta member lies outside its declared manifest root')
            if name.casefold() in cases:
                raise ValueError('Duplicate/case-aliased delta member proof')
            cases.add(name.casefold())
            record = {'bytes': row['bytes'], 'sha256': pin(row['sha256'])}
            target = inside(self.root, name)
            key = staged._key(target)
            if row['replaces_base_path']:
                previous = staged._files.get(key)
                if not previous:
                    raise ValueError('Delta replacement has no exact owned base member: ' + name)
                staged._metadata_before(target, previous['sha256'])
                self.old_records[name] = dict(previous)
            elif target.exists() or key in staged._files:
                raise ValueError('Delta addition collides with a retained base member: ' + name)
            self.members[name] = record
        manifest = self.members.get(self.manifest_path)
        if (not manifest or manifest['sha256'] != self.target_pin
                or self.manifest_path not in self.old_records):
            raise ValueError('Delta inventory lacks its exact replacing target manifest')
        self.part_count = part_count
        self.completed = set()
        self.sequence = 0
        self.pending = None
        self.finished = False

    def _before_member(self, name, target):
        key = self.staged._key(target)
        if name in self.old_records:
            previous = self.old_records[name]
            self.staged._metadata_before(target, previous['sha256'])
            if self.staged._files.get(key) != previous or target.stat().st_nlink != 1:
                raise ValueError('Delta base metadata ownership changed or is hardlinked: ' + name)
        elif target.exists() or key in self.staged._files:
            raise ValueError('Delta addition is no longer an absent NEW staged path: ' + name)

    def extract_kwargs(self, archive, sequence):
        """Prepare one independently pinned ZIP, in declared one-based order."""
        if (self.finished or self.pending is not None or type(sequence) is not int
                or sequence != self.sequence + 1 or sequence > self.part_count):
            raise ValueError('Delta ZIP order is invalid or its previous extraction is incomplete')
        names = set()
        cases = set()
        directories = set()
        with zipfile.ZipFile(archive) as zf:
            entries = zf.infolist()
            if len(entries) > 250000:
                raise ValueError('Delta ZIP member limit exceeded')
            for info in entries:
                name = str(relative(info.filename.rstrip('/')))
                if name.casefold() in cases:
                    raise ValueError('Duplicate/case-aliased delta ZIP member')
                cases.add(name.casefold())
                if info.is_dir():
                    directories.add(name)
                    continue
                if name not in self.members or name in self.completed:
                    raise ValueError('Unlisted or repeated delta ZIP member: ' + name)
                if info.file_size != self.members[name]['bytes']:
                    raise ValueError('Delta ZIP central-directory size differs from its member proof')
                names.add(name)
        if not names:
            raise ValueError('An independent delta ZIP cannot be empty')
        ancestors = {parent.as_posix() for name in names for parent in relative(name).parents
                     if parent != PurePosixPath('.')}
        if not directories.issubset(ancestors):
            raise ValueError('Delta ZIP has an unrelated directory entry')
        if sequence == self.part_count:
            if (names != {self.manifest_path}
                    or self.completed != set(self.members) - {self.manifest_path}):
                raise ValueError('The final delta ZIP must commit only its manifest after every payload')
        elif self.manifest_path in names:
            raise ValueError('Delta target manifest arrived before its final commit ZIP')
        replacements = []
        for name in sorted(names):
            self._before_member(name, inside(self.root, name))
            if name in self.old_records:
                replacements.append({'path': name,
                                     'expected_old_sha256': self.old_records[name]['sha256'],
                                     'expected_new_sha256': self.members[name]['sha256']})
        proofs = {name: dict(self.members[name]) for name in names}
        self.pending = {'archive': Path(os.path.abspath(archive)), 'names': names,
                        'proofs': proofs, 'replacements': replacements, 'sequence': sequence}
        return {'member_proofs': proofs, 'replace_members': replacements, 'delta_stage': self}

    def _begin(self, archive, root, staged, proofs, replacements):
        request = self.pending
        if (request is None or staged is not self.staged
                or Path(os.path.abspath(root)) != self.root
                or Path(os.path.abspath(archive)) != request['archive']
                or proofs != request['proofs'] or replacements != request['replacements']):
            raise ValueError('Delta extraction does not match its pending exact-member request')

    def _completed(self, inventory):
        if self.pending is None or set(inventory) != self.pending['names']:
            raise ValueError('Delta extraction omitted or added a proved member')
        for name, record in inventory.items():
            target = inside(self.root, name)
            if (record != self.members[name]
                    or self.staged._files.get(self.staged._key(target)) != record):
                raise ValueError('Delta extraction did not establish its exact staged member ownership')
        self.completed.update(inventory)
        self.sequence = self.pending['sequence']
        self.pending = None

    def finish(self):
        """Require every proved member and the final target manifest commit."""
        if (self.finished or self.pending is not None or self.sequence != self.part_count
                or self.completed != set(self.members)):
            raise ValueError('Delta is incomplete; prior bank and source archives remain intact')
        target = inside(self.root, self.manifest_path)
        self.staged._metadata_before(target, self.target_pin)
        if not matches(target, self.members[self.manifest_path]):
            raise ValueError('Delta target manifest changed before checkpoint acceptance')
        self.finished = True
        return {'member_count': len(self.completed), 'manifest_sha256': self.target_pin}


def safe_extract(archive, root, include_prefixes=None, *, staged=None, replace_members=None,
                 member_proofs=None, delta_stage=None):
    """Extract verified ZIPs; only pinned, owned staging metadata can change.

    ``replace_members`` is an explicit private-plan list of dictionaries with
    ``path`` (archive-relative), ``expected_old_sha256``, and optional
    ``expected_new_sha256``. Both the old hash and ArchiveStage ownership must
    match. With no replacement list, overlaps still require identical bytes.
    ``member_proofs`` additionally requires an exact archive-relative file set
    and each member's SHA256/bytes. It never relaxes metadata replacement rules.
    """
    inventory = {}
    case_names = {}
    if staged is not None:
        if not isinstance(staged, ArchiveStage):
            raise ValueError('Invalid new extraction ownership object')
        staged._key(root, allow_root=True)
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
    proofs = None
    if member_proofs is not None:
        if (not isinstance(member_proofs, dict) or not member_proofs
                or len(member_proofs) > 250000 or staged is None):
            raise ValueError('Member proofs need an exact bounded file map and NEW staging ownership')
        proofs = {}
        for name, record in member_proofs.items():
            relative(name)
            if (not selected(name) or not isinstance(record, dict)
                    or set(record) != {'bytes', 'sha256'}
                    or type(record.get('bytes')) is not int or record['bytes'] < 0):
                raise ValueError('Invalid or filtered-out archive member proof')
            proofs[name] = {'bytes': record['bytes'], 'sha256': pin(record['sha256'])}
    replacements = {}
    if replace_members is not None:
        if not isinstance(replace_members, list) or staged is None:
            raise ValueError('Archive replacements need an explicit list and NEW staging ownership')
        for item in replace_members:
            if (not isinstance(item, dict)
                    or set(item) - {'path', 'expected_old_sha256', 'expected_new_sha256'}):
                raise ValueError('Invalid archive metadata replacement declaration')
            name = str(relative(item.get('path')))
            if name in replacements or not selected(name):
                raise ValueError('Duplicate or filtered-out archive replacement member')
            old_pin = pin(item.get('expected_old_sha256'))
            new_pin = pin(item['expected_new_sha256']) if 'expected_new_sha256' in item else None
            staged._metadata_before(inside(root, name), old_pin)
            replacements[name] = {'old': old_pin, 'new': new_pin}
    if delta_stage is not None:
        if not isinstance(delta_stage, PinnedArchiveDelta) or proofs is None:
            raise ValueError('Invalid exact-member delta ownership token')
        delta_stage._begin(archive, root, staged, proofs, replace_members)
    replaced = set()
    with zipfile.ZipFile(archive) as zf:
        entries = zf.infolist()
        if len(entries) > 250000:
            raise ValueError('ZIP member limit exceeded')
        if proofs is not None:
            files = [info.filename for info in entries if not info.is_dir() and selected(info.filename)]
            if len(files) != len(set(files)) or set(files) != set(proofs):
                raise ValueError('ZIP file set does not match its exact member proofs')
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
                if name in replacements:
                    raise ValueError('An archive metadata replacement must be a file')
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            # The complete ZIP pin still binds every compressed payload. A
            # listed replacement additionally binds the old staged source.
            fd, temp_name = tempfile.mkstemp(prefix='.extract-', dir=target.parent)
            os.close(fd)
            temporary = Path(temp_name)
            try:
                with zf.open(info) as source, temporary.open('wb') as dest:
                    shutil.copyfileobj(source, dest, 1024 * 1024)
                if temporary.stat().st_size != info.file_size:
                    raise ValueError('Truncated ZIP entry: ' + name)
                record = file_record(temporary)
                if proofs is not None and record != proofs[name]:
                    raise ValueError('Archive member differs from its exact size/SHA256 proof: ' + name)
                if delta_stage is not None:
                    delta_stage._before_member(name, target)
                if name in replacements:
                    request = replacements[name]
                    if request['new'] is not None and record['sha256'] != request['new']:
                        raise ValueError('Archive metadata replacement has the wrong new SHA256: ' + name)
                    # Recheck ownership and actual old bytes after extraction,
                    # immediately before the one-file atomic publication.
                    staged._metadata_before(target, request['old'])
                    os.replace(temporary, target)
                    staged._created(target, record)
                    replaced.add(name)
                elif target.exists():
                    if not matches(target, record):
                        raise ValueError('Conflicting archive member: ' + name)
                else:
                    os.replace(temporary, target)
                    if staged is not None:
                        staged._created(target, record)
                inventory[name] = record
            finally:
                temporary.unlink(missing_ok=True)
    if replaced != set(replacements):
        raise ValueError('A declared archive metadata replacement was absent from the selected ZIP')
    if delta_stage is not None:
        delta_stage._completed(inventory)
    return inventory


class JoinedZipParts(io.RawIOBase):
    """Seekable view of verified transport chunks; never writes a second ZIP."""
    def __init__(self, parts):
        super().__init__()
        self.parts = parts
        self.ends = []
        total = 0
        for path, length in parts:
            total += length
            self.ends.append(total)
        self.length = total
        self.position = 0
        self.active = None
        self.active_index = None

    def readable(self):
        return True

    def seekable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=os.SEEK_SET):
        if self.closed:
            raise ValueError('Joined ZIP view is closed')
        if whence not in (os.SEEK_SET, os.SEEK_CUR, os.SEEK_END):
            raise ValueError('Invalid joined ZIP seek mode')
        position = offset + (self.position if whence == os.SEEK_CUR else
                             self.length if whence == os.SEEK_END else 0)
        if position < 0 or position > self.length:
            raise ValueError('Joined ZIP seek is outside the verified archive')
        self.position = position
        return position

    def read(self, size=-1):
        if self.closed:
            raise ValueError('Joined ZIP view is closed')
        size = min(self.length - self.position, size if size >= 0 else self.length)
        # ZIP central-directory reads are bounded too; extracted members are
        # streamed by safe_extract rather than loaded into this buffer.
        if size > 64 * 1024 * 1024:
            raise ValueError('Oversized joined ZIP metadata read')
        chunks = []
        while size:
            index = bisect.bisect_right(self.ends, self.position)
            path, length = self.parts[index]
            start = self.ends[index] - length
            if self.active_index != index:
                if self.active is not None:
                    self.active.close()
                no_links(path)
                self.active = path.open('rb')
                self.active_index = index
            self.active.seek(self.position - start)
            data = self.active.read(min(size, self.ends[index] - self.position))
            if not data:
                raise ValueError('Verified joined ZIP chunk was truncated')
            chunks.append(data)
            self.position += len(data)
            size -= len(data)
        return b''.join(chunks)

    def close(self):
        if self.active is not None:
            self.active.close()
            self.active = None
        super().close()


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
    digest = hashlib.sha256()
    count = 0
    parts = []
    for row in rows:
        path = downloaded[row['sha256']]
        no_links(path)
        if path.stat().st_size != row['bytes']:
            raise ValueError('Joined ZIP transport chunk length changed')
        parts.append((path, row['bytes']))
        with path.open('rb') as source:
            for block in iter(lambda: source.read(1024 * 1024), b''):
                digest.update(block)
                count += len(block)
    if count != pack['bytes'] or digest.hexdigest() != pack['sha256']:
        raise ValueError('Joined ZIP failed its complete size/SHA256')
    log('Reading verified ZIP directly from retained transport chunks; no duplicate joined file: %d bytes.' % count)
    return [JoinedZipParts(parts)]


def needed_transport_files(packs, cache):
    rows = []
    for pack in packs:
        if pack['format'] == 'joined-zip':
            complete = cache / (pin(pack['sha256']) + '.zip')
            no_links(complete)
            if complete.exists():
                if not matches(complete, pack):
                    raise ValueError('Existing assembled source archive changed; preserved without reuse')
                log('Reusing complete verified archive; transport chunks are not requested again.')
                continue
        rows.extend(pack['files'])
    return rows


def require_download_space(plan, work, resources):
    """Conservative compressed-download floor, not an extraction guarantee."""
    rows = {}
    for row in needed_transport_files(plan['packs'], work):
        digest = pin(row['sha256'])
        if isinstance(row['bytes'], bool) or not isinstance(row['bytes'], int) or row['bytes'] < 0:
            raise ValueError('Invalid transport byte length')
        if digest in rows and rows[digest]['bytes'] != row['bytes']:
            raise ValueError('Conflicting transport sizes for one SHA256')
        rows[digest] = row
    remaining = 0
    for digest, row in rows.items():
        complete = work / 'bundles' / (digest + '.bundle')
        no_links(complete)
        if complete.exists():
            if not matches(complete, row):
                raise ValueError('Changed completed archive preserved without reuse: ' + digest)
        else:
            # Keep partials intact; do not assume rclone can resume their bytes
            # or that its local temporary destination needs no extra space.
            remaining += row['bytes']
    known_expansion = 0
    supplied = plan.get('space_requirements', {})
    if supplied:
        if (not isinstance(supplied, dict) or supplied.get('schema') != 1
                or not isinstance(supplied.get('entries'), list)
                or len(supplied['entries']) > len(plan['packs'])):
            raise ValueError('Invalid source expansion metadata')
        packs = {pack['id']: pack for pack in plan['packs']}
        seen = set()
        for entry in supplied['entries']:
            if not isinstance(entry, dict) or entry.get('pack_id') not in packs or entry['pack_id'] in seen:
                raise ValueError('Unknown or duplicate expansion metadata pack')
            seen.add(entry['pack_id'])
            pack_digest = hashlib.sha256(json.dumps(packs[entry['pack_id']], sort_keys=True,
                                                   separators=(',', ':')).encode()).hexdigest()
            if pack_digest != pin(entry.get('pack_contract_sha256')):
                raise ValueError('Expansion metadata does not match the exact selected archive/paths')
            count = entry.get('extracted_bytes')
            if isinstance(count, bool) or not isinstance(count, int) or count < 0:
                raise ValueError('Invalid selected expansion byte count')
            known_expansion += count
        identity = hashlib.sha256(json.dumps({'packs': plan['packs'], 'bindings': plan['bindings']},
                                           sort_keys=True).encode()).hexdigest()
        destination = resources / identity
        no_links(destination)
        if destination.exists():
            prior = owned_state(destination, RESOURCE_STATE)
            if prior.get('identity') != identity:
                raise ValueError('Existing resource version has no matching ownership; preserved')
            # prepare_resources still verifies every member before reuse and
            # refuses changes; it never silently re-extracts over this version.
            known_expansion = 0
    free = min(shutil.disk_usage(work).free, shutil.disk_usage(resources).free)
    floor = remaining + known_expansion
    log('Compressed originals still needed: %d bytes; declared selected expansion: %d bytes; minimum observed free: %d bytes.' % (remaining, known_expansion, free))
    log('Cache and Download may share physical storage. This conservative floor excludes undeclared expansion, Git objects, code checkout/staging, allocation overhead and preserved previous versions; it is not a total-space guarantee.')
    if floor > free:
        raise ValueError('Insufficient space for the declared source floor: need at least %d new bytes, free %d. No download or automatic cache deletion started.' % (floor, free))


def pinned_member(root, name, digest):
    """Resolve the owner's exact member by identity, never a guessed ZIP prefix."""
    if len(relative(name).parts) != 1:
        raise ValueError('A member search requires one explicit basename')
    found = [path for path in root.rglob(name)
             if path.is_file() and sha256_file(path) == pin(digest)]
    if len(found) != 1:
        raise ValueError('The declared member pin must resolve to exactly one staged file')
    no_links(found[0])
    return found[0]


def bank_checkpoint(root, request, staged, previous=None):
    manifest = pinned_member(root, request['manifest_name'], request['manifest_sha256'])
    document = read_json(manifest, maximum=64 * 1024 * 1024)
    proof = document.get('source_action_domain_proofs')
    if (not isinstance(proof, dict) or proof.get('source_proof_key_field') != 'source_proof_key'):
        raise ValueError('The pinned source bank lacks its declared domain metadata contract')
    proof_path = inside(manifest.parent, proof['path'])
    metadata = {manifest.relative_to(staged.root).as_posix(): request['manifest_sha256'],
                proof_path.relative_to(staged.root).as_posix(): pin(proof['sha256'])}
    template_name = request.get('template_name')
    if template_name:
        if len(relative(template_name).parts) != 1:
            raise ValueError('A bank template requires its declared basename')
        # A producer may update the template only in its last delta. Retain
        # the exact earlier owned template authorization until that update;
        # final descriptor preparation still requires the final manifest pin.
        for name, digest in (previous or {}).get('metadata', {}).items():
            if PurePosixPath(name).name == template_name:
                metadata[name] = digest
        for path in root.rglob(template_name):
            template = read_json(path, maximum=2 * 1024 * 1024)
            if (template.get('schema') == 1 and template.get('source_snapshot') == 'patch523'
                    and template.get('manifest_sha256') == request['manifest_sha256']):
                metadata[path.relative_to(staged.root).as_posix()] = sha256_file(path)
    staged.authorize_metadata(metadata)
    staged.checkpoint(metadata)
    return {'pin': request['manifest_sha256'], 'metadata': metadata}


def metadata_replacements(archive, root, checkpoint, staged):
    # The full archive is already pinned. Only names derived from a prior
    # pinned manifest (or its exact settings template) may change in this stage.
    with zipfile.ZipFile(archive) as source:
        names = set(source.namelist())
    replacements = []
    for name, digest in checkpoint['metadata'].items():
        path = inside(staged.root, name)
        try:
            member = path.relative_to(root).as_posix()
        except ValueError:
            continue
        if member in names:
            replacements.append({'path': member, 'expected_old_sha256': digest})
    return replacements


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
    staged_archives = ArchiveStage(stage)
    checkpoint = None
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
                delta = None
                if pack.get('pinned_delta'):
                    spec = pack['pinned_delta']
                    if not checkpoint or checkpoint['pin'] != pin(spec['base_manifest_sha256']):
                        raise ValueError('Pinned delta base checkpoint is absent')
                    delta = PinnedArchiveDelta(staged_archives, root, inside(stage, spec['inventory_path']),
                        inventory_sha256=spec['inventory_sha256'], inventory_bytes=spec['inventory_bytes'],
                        base_manifest_sha256=spec['base_manifest_sha256'], target_manifest_sha256=spec['target_manifest_sha256'],
                        manifest_path=spec['manifest_path'], part_count=spec['part_count'], member_count=spec['member_count'])
                if pack.get('overlay_from_checkpoint'):
                    if not checkpoint or checkpoint['pin'] != pin(pack['overlay_from_checkpoint']):
                        raise ValueError('An ordered delta requires its exact prior bank checkpoint')
                for sequence, archive in enumerate(archives, 1):
                    replacements = (metadata_replacements(archive, root, checkpoint, staged_archives)
                                    if pack.get('overlay_from_checkpoint') else None)
                    kwargs = delta.extract_kwargs(archive, sequence) if delta else {'replace_members': replacements}
                    try:
                        extracted = safe_extract(archive, root, pack.get('include_prefixes'),
                                                 staged=staged_archives, **kwargs)
                    finally:
                        if isinstance(archive, JoinedZipParts):
                            archive.close()
                    payload.update(extracted)
                    if replacements:
                        for member in replacements:
                            name = pack['install_root'] + '/' + member['path']
                            checkpoint['metadata'][name] = extracted[member['path']]['sha256']
                if delta:
                    delta.finish()
            else:
                raise ValueError('Unsupported pack format')
            for name, record in payload.items():
                inventory[pack['install_root'] + '/' + name] = record
            if pack.get('bank_checkpoint'):
                checkpoint = bank_checkpoint(root, pack['bank_checkpoint'], staged_archives, checkpoint)
        retained = []
        if 'world_map' in plan['bindings']:
            retained.append(plan['bindings']['world_map']['contract_path'])
            retained.extend(x['path'] for x in plan['bindings']['world_map'].get('source_manifests', []))
        if 'tables' in plan['bindings']:
            # A preserved bank cfg may still reference this version's original
            # table ZIP. Keep that exact path alongside the retained bank.
            retained.append(plan['bindings']['tables']['path'])
        # UI roots remain usable by an explicit existing source-ui selection.
        # New formal defaults never authorize retiring those original paths.
        retained.extend(name for name in inventory if name.startswith(('source-ui/', 'ui/')))
        for pack in plan['packs']:
            if pack.get('retain_extracted') is True:
                retained.extend(name for name in inventory if name.startswith(pack['install_root'] + '/'))
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


def combined_ui_code_contract(code_root, required_components=()):
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
    supported = {'default_primary_stats', 'native_main_buttons', 'auto_message'}
    if (not isinstance(required_components, (list, tuple))
            or any(not isinstance(component, str) or component not in supported
                   for component in required_components)):
        raise ValueError('Unknown combined UI owner component contract')
    if 'default_primary_stats' in required_components:
        requirements['scripts/ui/original_ui/source_main_primary_stats.gd'] = [
            ('snapshot', ['hud.get("character_state")', 'TYPE_INT', 'melee_damage', 'ac']),
            ('build', ['_active_source(pack)', 'snapshot(hud)', '"button_actions_connected":false']),
            ('_active_source', ['pack.scene(MEMBER)', 'SOURCE_OFFSETS',
                                'source_primary_stats_nodes_not_in_active_pack_scope']),
            ('refresh', ['set_bound_text(MD_TEXT', 'set_bound_text(AC_TEXT'])]
        requirements['scripts/ui/original_ui/source_main_hud.gd'].extend([
            ('update_player', ['refresh_primary_stats()']), ('refresh_primary_stats',
             ['PrimaryStats.snapshot', 'PrimaryStats.refresh', 'PrimaryStats.build', 'scene.configure_project'])])
    if 'native_main_buttons' in required_components:
        requirements['scripts/ui/original_ui/source_main_hud.gd'].extend([
            ('configure', ['ButtonRouter.new()']), ('_input', ['_native_buttons.route(event,point,candidates)',
             'InputEventScreenTouch', 'InputEventScreenDrag', 'set_input_as_handled']),
            ('_collect_native_buttons', ['source_asset_scene', 'original_ui_source',
             'UI/CommonUi/Common_Slot.csb', 'UI/MainFloating/Slot_Skill.csb']),
            ('_source_input_captured', ['hud.get("pointer_transfer")', 'pointer.get("pointer")!=-2'])])
        requirements['scripts/ui/original_ui/source_button_router.gd'] = [
            ('route', ['handle_native_touch', 'event.index']), ('cancel', ['cancel_native_touch'])]
    if 'auto_message' in required_components:
        requirements['scripts/ui/original_ui/source_main_auto_message_bindings.gd'] = [
            (None, ['UI/Main/Hud_AutoMessage.csb', '14564', '76', '124']),
            ('configure', ['manifest.get("files",{}).get(MEMBER', 'weakref(hud)', 'returnsnapshot()']),
            ('snapshot', ['hud.get_parent()', 'world.get("player")', 'player.get("auto_enabled")',
             'notenabledisbool', 'source_auto_message_actual_auto_boolean_required']),
            ('build', ['ROOT:{"visible":state.auto_enabled}', 'TEXT:{"role":"static_source_text"}',
             '"playback_policy_declared":false', '"playback_requested":false', '"general_message_connected":false']),
            ('refresh', ['scene.set_bound_visible(ROOT,state.auto_enabled)'])]
        requirements['scripts/ui/original_ui/source_main_hud.gd'].extend([
            ('configure', ['has(AutoMessage.MEMBER)']), ('_process', ['_refresh_auto_message()']),
            ('refresh_combat', ['_refresh_auto_message()']), ('_refresh_auto_message',
             ['AutoMessage.new()', 'candidate.configure(_pack,hud)', '_auto_message.snapshot()',
              '_auto_message.refresh(_auto_message_scene)',
              '_mount_main_project(AutoMessage.MAIN_PROJECT,_auto_message.build())']),
            ('_mount_main_project', ['scope.assign(contract.source_node_offsets)',
             'scene.configure_project(_pack,MAIN,offset,contract.bindings,scope)'])])
    evidence, _ = source_contract_evidence(code_root, requirements)
    evidence['required_components'] = list(required_components)
    return evidence


def native_icon_scene_code_contract(code_root):
    # Independent optional scene-consumer evidence. These source boundaries
    # cannot supply per-icon original registration or playback declarations.
    requirements = {
        'scripts/ui/renewal_hud.gd': [('bind_original_icon_scene_provider',
            ['_original_icon_scene_provider=provider', 'refresh_source_icons'])],
        'scripts/ui/original_ui/source_main_hud.gd': [('_native_icon_context',
            ['Scene.external_scene_slot_contract', 'source_slot_contract']),
            ('_inventory_original_image', ['_native_icon_context', 'InventoryImages.resolve_owned']),
            ('_quickslot_original_image', ['_native_icon_context', 'QuickslotImages.resolve'])],
        'scripts/ui/original_ui/source_main_inventory_images.gd': [('resolve_owned',
            ['unsupported_csb', 'source_native_icon_scenes.gd', 'request(hud,info,native_context)'])],
        'scripts/ui/original_ui/source_main_quickslot_images.gd': [('resolve',
            ['unsupported_csb', 'source_native_icon_scenes.gd', 'request(hud,info,context)'])],
        'scripts/ui/original_ui/source_native_icon_scenes.gd': [('request',
            ['_original_icon_scene_provider', 'provider.call', 'source_slot_contract',
             'asset_type_id', '101', 'canonical.path', 'source_scene_descriptor'])],
        'scripts/ui/original_ui/source_asset_scene.gd': [('prepare',
            ['authored_sprite_anchor', 'original_registration_confirmed',
             'original_repeat_declared', 'original_policy_confirmed',
             'player.configure(pack,member,false', 'player.play', 'player.stop'])],
        'scripts/ui/original_ui/sprite_scene.gd': [('external_scene_slot_contract',
            ['externally_bound_texture_nodes', 'authored_sprite_anchor']),
            ('set_bound_source_visual_result', ['source_scene_descriptor',
             'set_bound_source_scene_result', 'set_bound_source_asset_result']),
            ('set_bound_source_scene_result', ['source_asset_scene.gd', 'prepare(descriptor)',
             '_detach_source_scene(node)', 'node.add_child(player)']), ('bound_source_scene', []),
            ('clear_bound_source_scene', ['_detach_source_scene(node)']),
            ('_detach_source_scene', ['player.stop()', 'PROCESS_MODE_DISABLED', 'remove_child', 'queue_free']),
            ('reuse_bound_source_scene_from', ['bound_source_scene', 'registration', 'playback',
             'source_asset_scene_bindings', 'old_node.remove_child(player)', 'node.add_child(player)'])],
        'scripts/ui/original_ui/source_main_inventory_slots.gd': [('_slot_binding', ['source_scene_descriptor'])],
        'scripts/ui/original_ui/source_main_quickslot_bindings.gd': [('build_group', ['source_scene_descriptor'])],
        'scripts/ui/original_ui/source_main_inventory_view.gd': [('_stage',
            ['set_bound_source_visual_result', 'source_scene_assigned', '_hits.get(reference',
             'reuse_bound_source_scene_from', 'parent.add_child(next)'])],
        'scripts/ui/original_ui/source_main_quickslot_view.gd': [('_stage',
            ['set_bound_source_visual_result', 'source_scene_assigned', 'old_entry.erase("auto")',
             'reuse_bound_source_scene_from', 'parent.add_child(next)'])],
    }
    evidence, _ = source_contract_evidence(code_root, requirements)
    evidence['scope'] = 'Existing scene-consumer source boundaries only; independent of static HUD/world readiness'
    evidence['owner_registration_inputs_verified'] = False
    evidence['runtime_verified'] = False
    return evidence


def additional_source_code_contracts(code_root, specifications, scope):
    """Read bounded owner API evidence, independently of activation readiness.

    The private handoff supplies public script/function markers. They are data,
    never expressions to evaluate, registration callbacks or runtime inputs.
    """
    if not isinstance(specifications, dict) or not 1 <= len(specifications) <= 16:
        raise ValueError('Additional source evidence requires bounded named contracts')
    result = {}
    for component, sources in specifications.items():
        if (not isinstance(component, str) or not re.fullmatch(r'[a-z][a-z0-9_]{0,47}', component)
                or not isinstance(sources, dict) or not 1 <= len(sources) <= 32):
            raise ValueError('Invalid additional source owner contract')
        requirements = {}
        for path, functions in sources.items():
            relative(path)
            if (not path.startswith('scripts/') or not path.endswith('.gd')
                    or not isinstance(functions, list) or not 1 <= len(functions) <= 32):
                raise ValueError('Source evidence can read only declared project script boundaries')
            requests = []
            for request in functions:
                if not isinstance(request, list) or len(request) != 2:
                    raise ValueError('Invalid source function evidence declaration')
                function, markers = request
                if (function is not None and (not isinstance(function, str)
                        or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]{0,127}', function))):
                    raise ValueError('Invalid source evidence function name')
                if (not isinstance(markers, list) or len(markers) > 32
                        or any(not isinstance(marker, str) or not 1 <= len(marker) <= 512 for marker in markers)):
                    raise ValueError('Invalid source evidence marker list')
                requests.append((function, [re.sub(r'\s+', '', marker) for marker in markers]))
            requirements[path] = requests
        evidence, _ = source_contract_evidence(code_root, requirements)
        evidence.update(scope=scope,
                        owner_inputs_verified=False, runtime_verified=False)
        result[component] = evidence
    return result


def v30_owner_boundary_requirements(ui, specifications):
    """Adapt only the shipped v30's exact obsolete owner marker declarations.

    The original plan/pin stays unchanged. Unknown declarations fail closed via
    the normal reader. These replacement boundaries follow the public owner
    refactor: configured CharacterView instance and inventory/crafting editor.
    No game code is patched or executed here.
    """
    if not isinstance(ui, dict) or any(ui.get(key) != value for key, value in {
            'pack_id': 'current523-main-game-original-ui-combined-v30',
            'root': 'source-ui/current523-main-game-original-ui-v30',
            'manifest_sha256': 'db62defeb1d1170f990689dac2e6be6c1c9015d13a9f4cfa5db710c834fc4ae3',
    }.items()):
        return specifications, []
    adapted = copy.deepcopy(specifications)
    applied = []
    hud = 'scripts/ui/original_ui/source_main_hud.gd'
    view = 'scripts/ui/original_ui/source_main_character_view.gd'
    stats = 'scripts/ui/original_ui/source_main_character_stats_bindings.gd'
    character = adapted.get('character_stats', {}) if isinstance(adapted, dict) else {}
    if (character.get(hud) == [['try_open_character_stats', ['CharacterView', 'open_stats']]]
            and character.get(view) == [['configure', []], ['open_stats', []], ['refresh', []]]
            and character.get(stats) == [['build', []], ['refresh', []]]):
        character[hud] = [
            [None, ['const CharacterView=preload("res://scripts/ui/original_ui/source_main_character_view.gd")']],
            ['configure', ['pack.manifest.get("scenes",{}).has(CharacterView.ALL)',
                'var candidate=CharacterView.new()', '_character_result=candidate.configure(pack,hud)',
                'if _character_result.get("ok",false):', '_character_view=candidate']],
            ['try_open_character_stats', ['if _character_view==null or not is_instance_valid(_coordinates):return _fail("source_character_original_view_not_available")',
                '_cancel_native_buttons()', '_character_result=_character_view.open_stats(_coordinates)',
                'return _character_result.duplicate(true)']]]
        character[view] = [
            [None, ['const PROJECT=12856', 'const STATS_PROJECT=1384',
                'const ALL="UI/FloatingUi/CharacterInfo_All.csb"',
                'const ALL_SHA="d19edfa099c5770cf43f08bd73f9370185ac7dbccdb67b89bf39d77330527be7"',
                'const PARENT_SHA="b689e91a9fc15eda9c35bed5b1073588a33a416a57890c293c531fe5c69ccbc8"']],
            ['configure', ['pack.manifest.get("files",{}).get(PARENT,{}).get("sha256")!=PARENT_SHA',
                'pack.manifest.get("files",{}).get(ALL,{}).get("sha256")!=ALL_SHA', '_hud=weakref(hud)']],
            ['open_stats', ['hud.get("lineage_side_ui")', 'side.get("stats_page")',
                'if not current_page is Control or not current_page.visible:return _fail(',
                '_owner_actions_supported(hud)', 'Stats.build(_pack,hud)',
                'next.project_player([PROJECT,STATS_PROJECT])']],
            ['_owner_actions_supported', ['hud.get("character_state")',
                'typeof(state.get("stat_points"))!=TYPE_INT', 'if state.stat_points!=0:return _fail(']],
            ['refresh', []]]
        character[stats] = [
            [None, ['const MEMBER="UI/FloatingUi/CharacterInfo_StatInfo.csb"',
                'const SHA256="75e7ad019977077a5e447bba55a5b6f7d15794ad0bca8807143dc275abba620c"']],
            ['build', ['_active_source(pack)', 'snapshot(owner)']], ['refresh', []],
            ['snapshot', ['owner.get("character_state")', 'typeof(state.get(field))!=TYPE_INT']],
            ['_active_source', ['pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256',
                'source_character_stats_original_text_role_mismatch']]]
        applied.append('character_stats')
    search_path = 'scripts/ui/original_ui/source_main_inventory_search.gd'
    search = adapted.get('inventory_search', {}) if isinstance(adapted, dict) else {}
    old_search = [
        ['configure', ['bag.has_method("_on_search_changed")', 'bag.get("search_line")isLineEdit',
            'source_inventory_search_original_identity_required']],
        ['open', ['"role":"source_text_field","editor":editor', 'next.project_player([1572,728])',
            'field.attach_editor()', 'field.unsupported_input.connect(_unsupported_input)']],
        ['apply_query', ['editor!=bag.get("search_line")', 'editor.call("apply_ime")',
            'bag.call("_on_search_changed",editor.text)']],
        ['close', ['_field.release_editor()']]]
    if search.get(search_path) == old_search:
        requests = copy.deepcopy(old_search)
        requests[0][1].extend(['[[PARENT,PARENT_SHA],[INVENTORY,INVENTORY_SHA],[MEMBER,SHA256]]',
            'pack.manifest.get("files",{}).get(pair[0],{}).get("sha256","")!=pair[1]',
            'pack.manifest.get("scenes",{}).has(MEMBER)', '_pack=pack', '_bag=weakref(bag)',
            '_crafting=false;_editor_property="search_line";_member=MEMBER;_member_sha=SHA256'])
        requests[1][1].remove('next.project_player([1572,728])')
        requests[1][1].extend(['var bag: Object=_bag.get_ref() if _bag!=null else null',
            'if not is_instance_valid(parent) or bag==null:return _fail("source_inventory_search_actual_parent_and_owner_required")',
            'var editor: Variant=bag.get(_editor_property)',
            'if not editor is LineEdit or not is_instance_valid(editor):return _fail("source_inventory_search_existing_editor_unavailable")',
            'else:result=next.configure_nodes(_pack,PARENT,[1572]',
            'var project_path: Array[int]=[628] if _crafting else [1572,728]',
            'next.project_player(project_path)',
            'if not result.get("ok",false):next.free();return result',
            'if not nested.get("ok",false):next.free();return nested'])
        requests[2][1].remove('editor!=bag.get("search_line")')
        requests[2][1].extend(['var editor: Control=input_control()',
            'if bag==null or not is_instance_valid(editor) or editor!=bag.get(_editor_property):return _fail("source_inventory_search_actual_query_owner_required")',
            'hud.get("active_section")!="crafting"', 'not workspace.is_ancestor_of(bag)',
            'not bag.is_visible_in_tree()', 'source_craft_search_current_owner_changed',
            'if not is_open():return _fail("source_inventory_search_original_input_became_unavailable")',
            'if _crafting:bag.call("_rebuild_listing")'])
        requests.extend([
            [None, ['const PARENT="UI/FloatingUiScene.csb"',
                'const PARENT_SHA="b689e91a9fc15eda9c35bed5b1073588a33a416a57890c293c531fe5c69ccbc8"',
                'const INVENTORY="UI/FloatingUi/Inventory_All.csb"',
                'const INVENTORY_SHA="c2c021fbc49f0699f2002a3f1cb73f523c3dd629bd1df567192dcb7f4da22293"',
                'const MEMBER="UI/FloatingUi/Inventory_Popup_Keypad.csb"',
                'const SHA256="3892e910ad1c6b3e04714f26402ed171a98a08fe3e7e97362cd4fe07a79478d5"']],
            ['configure_crafting', ['script.resource_path!="res://scripts/ui/renewal_crafting.gd"',
                'owner.get("name_filter") is LineEdit', 'source_craft_search_existing_editor_not_editable',
                '[["UI/ProductionScene.csb","cae6672733b914c0143fe376574e73012b0cd628113002693f0639c877f47328"],["UI/Production/Production_All.csb","328546745405eac58203853570d76e07d9cc95477ac4ecd701d786651e3786ec"],["UI/Production/Production_Popup_Keypad.csb","e4203840af58b4feebc832c4059c1a819f5348085ee3f5b6ecf5a3eb05f82aa8"]]',
                'pack.manifest.get("files",{}).get(pair[0],{}).get("sha256")!=pair[1]',
                'source_craft_search_original_identity_required', '_pack=pack;_bag=weakref(owner)',
                '_crafting=true;_editor_property="name_filter"',
                '_member="UI/Production/Production_Popup_Keypad.csb"',
                '_member_sha="e4203840af58b4feebc832c4059c1a819f5348085ee3f5b6ecf5a3eb05f82aa8"']]])
        search[search_path] = requests
        applied.append('inventory_search')
    return adapted, applied


def additional_ui_code_contracts(code_root, specifications, ui=None):
    requirements, adapted = v30_owner_boundary_requirements(ui, specifications)
    result = additional_source_code_contracts(code_root, requirements,
        'Owner script boundaries only; independent of main/world activation')
    for component in adapted:
        result[component]['compatibility_contract'] = 'official-v30-configured-owner-boundaries-v1'
    if 'inventory_search' in adapted and result['inventory_search']['ready']:
        source = inside(code_root, 'scripts/ui/original_ui/source_main_inventory_search.gd').read_text(encoding='utf-8')
        body = gd_function(source, 'apply_query')
        sequence = ['editor!=bag.get(_editor_property)', 'editor.call("apply_ime")',
                    'ifnotis_open():return_fail(', 'if_crafting:bag.call("_rebuild_listing")',
                    'else:bag.call("_on_search_changed",editor.text)']
        positions = [body.find(marker) for marker in sequence]
        if any(position < 0 for position in positions) or positions != sorted(positions):
            result['inventory_search']['blockers'].append('Inventory query must validate owner, commit IME, recheck open state, then call the existing owner')
            result['inventory_search']['ready'] = False
    return result


def ui_identity_order_contract(code_root):
    name = 'scripts/ui/original_ui/sprite_scene.gd'
    evidence, sources = source_contract_evidence(code_root, {name: [('configure', [])]})
    body = gd_function(sources.get(name, ''), 'configure')
    validate = body.find('_validate(')
    commit = body.find('source_tree=tree')
    assigned = [body.find('source_pack=pack'), body.find('source_member=member')]
    rejection = body[validate:commit] if 0 <= validate < commit else ''
    if (validate < 0 or any(index < 0 or index >= validate for index in assigned)
            or not all(marker in rejection for marker in ('source_pack=null', 'source_member=""', 'unsupported_source_scene'))):
        evidence['blockers'].append('UI source identity must be staged before validation and cleared on rejection before tree commit')
    evidence['ready'] = not evidence['blockers']
    return evidence


def preflight_required_code(plan, code_root):
    if not plan.get('enforce_selected_source_contracts'):
        return
    bank = plan['bindings']['source_bank']
    ui = plan['bindings']['main_ui']
    contracts = [source_bank_code_contract(code_root, bank['required_manifest_bytes']),
                 combined_ui_code_contract(code_root, ui.get('code_components', [])),
                 ui_identity_order_contract(code_root)]
    contracts.extend(additional_ui_code_contracts(code_root, ui['feature_code_requirements'], ui).values())
    blockers = [message for contract in contracts for message in contract['blockers']]
    if blockers:
        raise ValueError('Selected official resources require compatible actual main code: ' + '; '.join(blockers))


def source_bank_code_contract(code_root, manifest_bytes=None):
    requirements = {
        'scripts/resources/current523_source_bank.gd': [('options',
            ['--current523-source-bank-config=', 'FileAccess.file_exists(SETTINGS)',
             'value.get("source_snapshot")!="patch523"']),
            ('source_tables', ['options(context)', '_load_tables']),
            ('select_card', ['options(context)', '_load_tables'])],
        'scripts/resources/reference_sp2_bank.gd': [('load_bank',
            ['_root=manifest_path.get_base_dir()', '_json(manifest_path,expected_sha',
             'current523_reference_sp2_action_bank', 'source_dummy_exclusion_policy',
             '_install_source_exclusions()', 'source_actor_admission']),
            ('_source_reference_instances', ['SOURCE_REFERENCE_INSTANCE_POLICY'])],
        'scripts/animation/original_source_preview.gd': [('configure',
            ['CURRENT523_BANK.select_card(key,context)', '_configure_selected_roles(selected,"idle")']),
            ('_configure_selected_roles', ['_configure_reference_bank']),
            ('_configure_reference_bank', ['REFERENCE_BANK.new()', 'bank.load_bank', '_configure_source_nodes'])],
        'scripts/player.gd': [('set_transform_visual', ['original_source_preview.configure']),
            ('_update_visual', ['original_source_preview.advance_source'])],
        'scripts/monster.gd': [('setup', ['current_view.configure_admitted(source_record,admission)'])],
        'scripts/monsters/current523_source_bank_view.gd': [('configure_admitted',
            ['SELECTION.select', 'current523_active_actor_registry_required_for_view',
             '_configure_selected_roles'])],
        'scripts/resources/current523_source_effect_selection.gd': [('_bank',
            ['source_action_domains', 'current523_effect_original_action_domain_required']),
            ('_action', ['all_effective_original_SPR_actions_not_only_compiled_entries'])],
        'scripts/monsters/current523_source_bank_selection.gd': [('source_only_request',
            ['source_m_current523_final']), ('select', ['definition_selection_only',
            'runtime_actor_registry_required', 'current523_complete_original_npc_definition_differs'])],
    }
    large_manifest = manifest_bytes is not None and manifest_bytes > 16 * 1024 * 1024
    if large_manifest:
        requirements['scripts/resources/reference_sp2_bank.gd'].extend([
            ('load_bank', ['_json(manifest_path,expected_sha,true)']),
            ('_json', ['manifest_json:bool=false', 'MAX_MANIFEST_JSONifmanifest_jsonelseMAX_JSON', 'digest(bytes)!=expected'])])
        checks = [('_bank', ['file.get_length()>BANK.MAX_MANIFEST_JSON',
                            'BANK.valid_sha(expected)', 'FileAccess.get_sha256(path)!=expected'])]
        requirements['scripts/resources/current523_source_effect_selection.gd'].extend(checks)
        requirements['scripts/resources/current523_source_awakening_selection.gd'] = checks
    evidence, sources = source_contract_evidence(code_root, requirements)
    if manifest_bytes is not None:
        evidence['manifest_bytes'] = manifest_bytes
        source = sources.get('scripts/resources/reference_sp2_bank.gd', '')
        def capacity_for(name):
            match = re.search(r'(?m)^const\s+' + name + r'\s*=\s*(\d+)(\s*\*\s*1024\s*\*\s*1024)?\s*$', source)
            return int(match.group(1)) * (1024 * 1024 if match.group(2) else 1) if match else None
        action_capacity = capacity_for('MAX_JSON')
        capacity = capacity_for('MAX_MANIFEST_JSON') if large_manifest else action_capacity
        evidence['loader_json_capacity'] = capacity
        evidence['individual_action_json_capacity'] = action_capacity
        evidence['all_three_manifest_readers_required'] = large_manifest
        if large_manifest and (capacity != 32 * 1024 * 1024 or action_capacity != 16 * 1024 * 1024):
            evidence['blockers'].append('Required split 32MiB manifest / 16MiB action limits are not present')
        if capacity is None or manifest_bytes > capacity:
            evidence['blockers'].append('Pinned manifest exceeds actual manifest reader capacity or it is undeclared')
        evidence['ready'] = not evidence['blockers']
    evidence['scope'] = 'Published source-bank consumer boundaries; runtime admission/restoration remain unverified'
    return evidence


def native_item_code_contract(code_root):
    requirements = {
        'scripts/resources/current523_definition_rows.gd': [('_open', ['TWILIGHT_PATCH523_CONTENT']),
            ('identity', ['twilight.current523.original-definitions.v1']),
            (None, ['SOURCE_BYTES', '25031173',
                    'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'])],
        'scripts/resources/current523_item_data.gd': [('describe',
            ['SOURCE.identity()', 'SOURCE.row("ItemClass",item_id)', 'twilight.current523.item-data.v1'])],
        'scripts/loot/current523_native_item_projection.gd': [('record',
            ['source_definition_archive', 'current523_original_typed_game_dto_v1']),
            ('register', ['current_original_native_projection'])],
        'scripts/loot/patch523_monster_drops.gd': [('data',
            ['CURRENT_SOURCE.identity()', 'current523_original_reference_rows']),
            ('_current_item_reference', ['reader.get_script_method_list()',
             'method.get("name")=="describe"', 'reader.call("describe",item_id,false)']),
            ('_current_raw_definition', ['CURRENT_DTO.record(definition)']),
            ('register_catalog', ['CURRENT_DTO.register']), ('pack_identity',
            ['schema', '4', 'current523_original_definition_projection',
             'source_definition_archive', 'current523_original_typed_game_dto_v1', 'full_native_effects_complete'])],
        'scripts/crafting/patch523_craft_catalog.gd': [('available', ['owner.call("data")']),
            ('register', ['owner.call("register_catalog",document,catalog)'])],
        'scripts/equipment523/native_catalog.gd': [('validate_identity',
            ['current523_original_definition_projection', 'source_definition_archive',
             'current523_original_typed_game_dto_v1'])],
        'scripts/world.gd': [('_load_data',
            ['LOOT_DROP.PATCH523_DROPS.register_catalog(LOOT_DROP.PATCH523_DROPS.data(),catalog_db)',
             'PATCH523_CRAFT_CATALOG.register(catalog_db,PATCH523_CRAFT_CATALOG.available())']),
            ('_prepare_patch523_item_save_backup', []), ('_load_game', [])],
    }
    evidence, _ = source_contract_evidence(code_root, requirements)
    evidence['scope'] = 'Current original definition ZIP and schema4 projection code only; runtime registration/effects unverified'
    evidence['legacy_bin_required_when_ready'] = False
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


def world_map_input_contract(result, resources, bindings, main_ui, verified_world_images=None):
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
            if image.get('from_verified_extraction') is True:
                # No guessed raw/decoded SHA: bind the actual original member
                # recorded while extracting the fully pinned official ZIPs.
                member = inside(root, image['path'])
                name = member.relative_to(resources).as_posix()
                if verified_world_images is None:
                    state = owned_state(resources, RESOURCE_STATE)
                    record = state.get('files', {}).get(name)
                else:
                    # Manual mode has no normal-installer resource marker.
                    # Expected SHA/size came from the selected member inside
                    # its SHA-authenticated ZIP, then matched the extracted file.
                    record = verified_world_images.get(name)
                    if record:
                        if (record.get('verification') != 'manual-pinned-zip-member-sha256-v1'
                                or record.get('member_path') != name
                                or type(record.get('crc32')) is not int
                                or not 0 <= record['crc32'] <= 0xffffffff):
                            raise ValueError('Invalid manual World extraction evidence')
                        pin(record.get('archive_sha256'))
                        pin(record.get('sha256'))
                if not record or not matches(member, record):
                    evidence['blockers'].append('Offered World original is not in verified extraction: ' + str(image['world_id']))
                else:
                    require('world_image:' + str(image['world_id']), member, record['sha256'], record['bytes'])
                covered.add((str(image['land_id']), image['world_id']))
                continue
            require('world_image:' + str(image['world_id']), inside(root, image['path']),
                    image['sha256'], image['bytes'])
            covered.add((str(image['land_id']), image['world_id']))
        offers = {(land, offer['world_id']) for land, offer in bindings['world_map']['offered_worlds'].items()}
        if not offers or covered != offers:
            evidence['blockers'].append('Exact offered World image inputs are not supplied')
    evidence['ready'] = not evidence['blockers']
    return evidence


def descriptor(plan, resources, persistent_contracts=None, code_root=None, verified_world_images=None):
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
        if bindings['tables'].get('native_item_input'):
            code = native_item_code_contract(code_root)
            result['native_item_input'] = {'tables_zip': result['tables_zip'], 'code_contract': code,
                                           'runtime_registration_verified': False}
            if code_root is not None:
                for blocker in code['blockers']:
                    log('NATIVE ITEM CODE PENDING: ' + blocker)
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
        if row.get('expected_composition') or row.get('code_components'):
            result['main_ui']['owner_code_contract'] = combined_ui_code_contract(code_root, row.get('code_components', []))
            if code_root is not None:
                for blocker in result['main_ui']['owner_code_contract']['blockers']:
                    log('COMBINED UI CODE PENDING: ' + blocker)
        if 'feature_code_requirements' in row:
            features = additional_ui_code_contracts(code_root, row['feature_code_requirements'], row)
            result['main_ui']['feature_code_contracts'] = features
            if code_root is not None:
                for component, evidence in features.items():
                    for blocker in evidence['blockers']:
                        log('UI FEATURE CODE PENDING [' + component + ']: ' + blocker)
        if row.get('require_source_identity_order'):
            result['main_ui']['identity_order_contract'] = ui_identity_order_contract(code_root)
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
        inputs = world_map_input_contract(result, resources, bindings, main_ui_document, verified_world_images)
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
        result['ui_icons']['native_scene_code_contract'] = native_icon_scene_code_contract(code_root)
        if code_root is not None:
            for blocker in result['ui_icons']['native_scene_code_contract']['blockers']:
                log('NATIVE ICON SCENE CODE PENDING: ' + blocker)
    if 'source_bank' in bindings:
        row = bindings['source_bank']
        search = inside(resources, row['search_root']) if 'search_root' in row else None
        manifest = (pinned_member(search, row['manifest_name'], row['manifest_sha256'])
                    if search is not None else inside(resources, row['manifest_path']))
        if sha256_file(manifest) != pin(row['manifest_sha256']):
            raise ValueError('Source bank manifest pin mismatch')
        inputs = {'manifest': {'path': str(manifest), 'sha256': row['manifest_sha256']}}
        if search is not None and not row.get('configuration_contract'):
            templates = []
            if len(relative(row['template_name']).parts) != 1:
                raise ValueError('A bank template requires its declared basename')
            for path in search.rglob(row['template_name']):
                document = read_json(path, maximum=2 * 1024 * 1024)
                if (document.get('schema') == 1 and document.get('source_snapshot') == 'patch523'
                        and document.get('manifest_sha256') == row['manifest_sha256']
                        and isinstance(document.get('enabled'), bool)
                        and all(isinstance(document.get(key), str) and document[key]
                                for key in ('tables_zip', 'manifest_path'))):
                    templates.append(path)
            if len(templates) != 1:
                raise ValueError('The final bank needs exactly one original settings template for its pin')
            inputs['template'] = {'path': str(templates[0]), 'sha256': sha256_file(templates[0])}
            document = read_json(manifest, maximum=64 * 1024 * 1024)
            proof = document.get('source_action_domain_proofs', {})
            if proof.get('source_proof_key_field') != 'source_proof_key':
                raise ValueError('The final bank lacks its exact original domain metadata')
            proof_path = inside(manifest.parent, proof['path'])
            if sha256_file(proof_path) != pin(proof['sha256']):
                raise ValueError('The final bank domain metadata pin does not match')
            inputs['domain_metadata'] = {'path': str(proof_path), 'sha256': proof['sha256']}
        if row.get('configuration_contract'):
            supplied = row['configuration_contract']
            path = inside(resources, supplied['path'])
            if sha256_file(path) != pin(supplied['sha256']):
                raise ValueError('Source bank configuration contract pin mismatch')
            contract = read_json(path)
            if (contract.get('target_manifest_sha256') != row['manifest_sha256']
                    or contract.get('tables', {}).get('sha256') != TABLES_SOURCE_SHA256
                    or contract.get('configuration', {}).get('loader_settings') != 'user://current523_source_bank.json'):
                raise ValueError('Source bank settings differ from supplied official contract')
            inputs['configuration_contract'] = {'path': str(path), 'sha256': supplied['sha256']}
        code = source_bank_code_contract(code_root, manifest.stat().st_size)
        enabled = row.get('enabled') is True
        result['source_bank'] = {'schema': 1, 'enabled': enabled, 'source_snapshot': 'patch523',
                                 'tables_zip': result['tables_zip'], 'manifest_path': str(manifest),
                                 'manifest_sha256': row['manifest_sha256'], 'code_contract': code,
                                 'input_files': inputs, 'ready_for_fresh_install': enabled and code['ready']}
        if 'overlay_whitelist_path' in row:
            overlay = inside(resources, row['overlay_whitelist_path'])
            if sha256_file(overlay) != pin(row['overlay_whitelist_sha256']):
                raise ValueError('Source bank overlay pin mismatch')
            result['source_bank'].update(overlay_whitelist_path=str(overlay),
                                        overlay_whitelist_sha256=row['overlay_whitelist_sha256'])
        if 'caller_code_requirements' in row:
            callers = additional_source_code_contracts(code_root, row['caller_code_requirements'],
                'Merged Sprite caller boundaries only; no bank distribution, admission or playback proof')
            result['source_bank']['caller_code_contracts'] = callers
            if code_root is not None:
                for component, evidence in callers.items():
                    for blocker in evidence['blockers']:
                        log('SOURCE BANK CALLER CODE PENDING [' + component + ']: ' + blocker)
        if code_root is not None:
            for blocker in code['blockers']:
                log('SOURCE BANK CODE PENDING: ' + blocker)
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
                or record.get('bytes') == TABLES_SOURCE_BYTES and record.get('sha256') == TABLES_SOURCE_SHA256
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
        if plan.get('mandatory_source_blockers'):
            raise ValueError('Required source compatibility is unresolved: ' + '; '.join(plan['mandatory_source_blockers']))
        if any(p.get('activate') is False for p in plan['packs']):
            raise ValueError('Pending packs cannot be active dependencies')
        for message in plan.get('blockers', []):
            log('HANDOFF PENDING: ' + str(message))
        if root.exists() and not owned_state(root) and any(root.iterdir()):
            raise ValueError('Existing folder has no ownership receipt from this installer; no automatic takeover')
        if not root.exists():
            # Explicit --project selects this new folder. An interrupted first
            # install may leave it empty; it never adopts an unowned nonempty
            # directory or places a success receipt before publication.
            root.mkdir()
            log('Created empty selected project folder: ' + str(root))
        require_download_space(plan, work, resources)
        code_root, commit, code_inventory = packed_code(work)
        preflight_required_code(plan, code_root)
        transport = DriveTransport(work / 'bundles', token_file=args.token_file,
                                   remote=None if args.token_file else args.remote,
                                   workers=args.workers, progress=log)
        # Bulk ZIPs only: future unknown inputs are never substituted with old packs.
        downloaded = transport.download_many(needed_transport_files(plan['packs'], work))
        resource_root, resource_state = prepare_resources(plan, downloaded, resources, work)
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
            log('PARTIAL READINESS: source-consumer or feature-code handoffs above remain pending; received inputs are not gameplay evidence.')
        log('UNVERIFIED: no game run, render, tests or CI were executed by this installer.')


def diagnose_bundle(args):
    # Deliberately bypass install(): no Git, recovery, cache marker, bundle,
    # extraction, activation or cleanup. Only the already-held pinned plan is read.
    if not args.plan or not args.plan_sha256 or args.token_file:
        raise ValueError('Diagnostic requires --plan and --plan-sha256 with the existing rclone remote; no plan download or credentials change.')
    if sha256_file(args.plan) != pin(args.plan_sha256):
        raise ValueError('Diagnostic local plan SHA256 mismatch')
    plan = read_json(args.plan)
    digest = pin(args.diagnose_bundle)
    rows = [row for pack in plan['packs'] for row in pack['files'] if row.get('sha256') == digest]
    if not rows or any({key: row.get(key) for key in ('file_id', 'bytes', 'sha256')} !=
                       {key: rows[0].get(key) for key in ('file_id', 'bytes', 'sha256')} for row in rows):
        raise ValueError('Diagnostic bundle is absent or ambiguous in the pinned local plan')
    candidate = args.project.expanduser()
    if candidate.is_symlink():
        raise ValueError('Diagnostic project cannot itself be a symlink')
    root = candidate.parent.resolve() / candidate.name
    no_links(root)
    candidate_cache = args.cache.expanduser()
    if candidate_cache.is_symlink():
        raise ValueError('Diagnostic cache cannot itself be a symlink')
    cache = candidate_cache.parent.resolve() / candidate_cache.name
    no_links(cache)
    key = hashlib.sha256(str(root).encode()).hexdigest()[:16]
    destination = cache / key / 'bundles' / (digest + '.partial')
    no_links(destination)
    log(diagnose_rclone_bundle(rows[0], args.remote, destination))
    log('DIAGNOSTIC ONLY: metadata/path dry-run completed; media download and installation remain unverified. No bundle or marker was written; no retry attempted.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path)
    parser.add_argument('--cache', type=Path, default=Path.home() / '.cache/twilight-private-install')
    plan_source = parser.add_mutually_exclusive_group()
    plan_source.add_argument('--plan', type=Path, help='Existing private owner handoff JSON')
    plan_source.add_argument('--plan-id', help='Authenticated private Drive installation handoff ID')
    plan_source.add_argument('--plan-inline', help='Owner handoff JSON compressed with zlib and URL-safe base64, supplied in the same command')
    parser.add_argument('--plan-sha256', help='Optional immutable handoff pin; omit to follow owner updates')
    parser.add_argument('--remote', default='twilight-drive', help='Already authorized rclone Drive remote')
    parser.add_argument('--token-file', type=Path, help='Explicit private OAuth token file for HTTP Range resume')
    parser.add_argument('--workers', type=int, choices=(1, 2, 3), default=2, help='Concurrent bundles, not individual images')
    parser.add_argument('--diagnose-bundle', type=pin, help='Full SHA256 from the pinned local plan: one metadata/path copyid dry-run, no installation or media download')
    parser.add_argument('--manual-resources', action='store_true', help='Verify the existing manual distribution and add minimal GitHub code only; never invoke Drive')
    parser.add_argument('--manual-bootstrap-sha256', type=pin, help='Exact private manual bootstrap receipt pin')
    parser.add_argument('--manual-archives', type=Path, help='Directory holding the exact manual ZIP names; defaults to the selected project parent')
    args = parser.parse_args()
    if not args.manual_resources and (args.manual_bootstrap_sha256 or args.manual_archives):
        parser.error('Manual input options require the explicit --manual-resources mode')
    if args.project is None:
        args.project = Path.home() / 'storage/downloads' / ('TWILIGHT_Play_Source523_Manual' if args.manual_resources else 'TWILIGHT_Play')
    log('Manual resource adoption selected; no rclone or source-resource download.' if args.manual_resources else
        'Read-only bundle diagnostic selected; installation will not start.' if args.diagnose_bundle else
        'Installer Python entry reached. Reading the selected private plan before code/resource downloads.')
    try:
        if args.manual_resources:
            from manual_resource_install import install_manual
            install_manual(args, sys.modules[__name__])
        elif args.diagnose_bundle:
            diagnose_bundle(args)
        else:
            install(args)
    except (OSError, ValueError, KeyError, RuntimeError, zlib.error, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        log(('MANUAL INSTALL STOPPED: ' if args.manual_resources else 'DIAGNOSTIC STOPPED: ' if args.diagnose_bundle else 'INSTALL STOPPED: ') + str(error))
        if args.manual_resources:
            log('No Drive calls, source-media download or resource extraction were started. Existing originals, caches, settings and user files are preserved; no automatic fallback.')
        elif args.diagnose_bundle:
            log('No installation, media download or automatic retry was started. Existing cache and user data are preserved.')
        elif isinstance(error, DownloadError) and (
                'category=QUOTA_REPORTED;' in str(error) or str(error).startswith('Drive HTTP 429:')):
            # Match our fixed classifier field, never infer quota from HTTP403
            # alone or from an arbitrary file name/provider error fragment.
            log('PROVIDER LIMIT: do not rerun immediately or reset authentication. Wait for provider availability; honor any actual Retry-After and request-rate backoff. The reset time is not known.')
            log('Verified bundles, marked partials and user data are preserved. After the limit permits access, resume deliberately with the same plan/project/cache; no automatic retry or limit bypass is performed.')
        elif isinstance(error, DownloadError) and (
                'category=FILE_ACCESS_REPORTED;' in str(error) or str(error).startswith('Drive HTTP 403:')):
            log('PROVIDER ACCESS STOP: do not repeat immediately or reset authentication. HTTP403 alone does not identify quota. Review the reported reason and existing access; no alternate account or permission change was attempted.')
            log('Verified bundles, marked partials and user data are preserved. Resume with the same plan/project/cache only after the reported restriction is resolved.')
        else:
            log('The previous runtime, source archives and personal data are preserved. Rerun the same command to reuse verified bundles.')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
