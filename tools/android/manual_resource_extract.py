"""Extract only a pinned local manual distribution, then use its existing guards.

No Drive, glob selection, extractall, replacement, resource copy or deletion.
An exclusive output file is also its resumable partial: authenticated ZIP bytes
must match the entire existing prefix before this owner may append to it.
"""
from contextlib import ExitStack
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import unicodedata
import zipfile
import zlib

from manual_resource_install import ROOT_NAME, RESOURCE_DIR, BOOTSTRAP, SCHEMA, PLAN_SHA, _resource_path

EXTRACT_SCHEMA = 'twilight-owned-manual-extraction-v1'
INSTALLER_COMMIT = '768dd49388c99b8c9e87df9a07d1adbffd6f6fa6'
CHUNK = 1024 * 1024


def _alias(value):
    parts = value.split('/')
    if any(part.endswith((' ', '.')) for part in parts):
        raise ValueError('Ambiguous shared-storage path; all files preserved')
    return '/'.join(unicodedata.normalize('NFC', part).casefold() for part in parts)


def _stamp(value):
    return [value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns, value.st_ctime_ns]


def _regular(a, path):
    a.no_links(path)
    value = path.stat()
    if not stat.S_ISREG(value.st_mode):
        raise ValueError('Expected an exact regular downloaded ZIP/file: ' + path.name)
    return value


def _archive(a, stack, path, expected):
    before = _regular(a, path)
    if type(expected.get('bytes')) is not int or before.st_size != expected['bytes']:
        raise ValueError('Downloaded ZIP length differs: ' + path.name)
    a.pin(expected.get('sha256'))
    handle = stack.enter_context(os.fdopen(os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0)), 'rb'))
    if _stamp(os.fstat(handle.fileno())) != _stamp(before):
        raise ValueError('Downloaded ZIP identity changed before hashing')
    digest = hashlib.sha256()
    for block in iter(lambda: handle.read(CHUNK), b''):
        digest.update(block)
    if digest.hexdigest() != expected['sha256'] or _stamp(os.fstat(handle.fileno())) != _stamp(before):
        raise ValueError('Downloaded ZIP changed or SHA differs: ' + path.name)
    handle.seek(0)
    archive = stack.enter_context(zipfile.ZipFile(handle))
    return {'zip': archive, 'handle': handle, 'path': path, 'stamp': _stamp(before)}


def _unchanged(a, archive):
    if (_stamp(_regular(a, archive['path'])) != archive['stamp']
            or _stamp(os.fstat(archive['handle'].fileno())) != archive['stamp']):
        raise ValueError('Authenticated ZIP changed during extraction; stopped without fallback')


def _entries(a, archive):
    result = []
    prefix = ROOT_NAME + '/' + RESOURCE_DIR + '/'
    for info in archive['zip'].infolist():
        mode = info.external_attr >> 16
        directory = info.is_dir()
        raw = info.filename[:-1] if directory else info.filename
        if info.orig_filename != info.filename or directory and info.file_size:
            raise ValueError('Ambiguous ZIP member or nonempty directory entry')
        a.relative(raw)
        _alias(raw)
        if (info.flag_bits & (1 | 64 | 8192) or info.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
                or stat.S_ISLNK(mode) or mode and stat.S_IFMT(mode) not in
                (0, stat.S_IFDIR if directory else stat.S_IFREG)):
            raise ValueError('Unsupported/encrypted/non-regular ZIP member; no extraction started')
        if directory and raw in (ROOT_NAME, ROOT_NAME + '/' + RESOURCE_DIR):
            continue
        if not raw.startswith(prefix):
            raise ValueError('ZIP member is outside the exact manual resource root')
        name = raw[len(prefix):]
        a.relative(name)
        if directory:
            _resource_path(a, name + '/directory-boundary')
        elif name not in ('.gdignore', 'manual-install-plan.json'):
            _resource_path(a, name)
        result.append((name, info))
    return result


def _inventory(a, bootstrap, index, components):
    files, aliases, directories = {}, {}, set()
    declared_directories = set()
    for archive, entries, component in components:
        count, size = 0, 0
        for name, info in entries:
            parts = name.split('/')
            paths = ['/'.join(parts[:n]) for n in range(1, len(parts) + 1)]
            for part in paths:
                key = _alias(part)
                if key in aliases and aliases[key] != part:
                    raise ValueError('Case/Unicode alias across manual ZIP paths; no extraction started')
                aliases[key] = part
            if info.is_dir():
                if name in declared_directories or name in files:
                    raise ValueError('Duplicate/conflicting manual ZIP directory')
                declared_directories.add(name)
                directories.add(name)
                directories.update(paths[:-1])
                continue
            if name in files or name in directories:
                raise ValueError('Duplicate/conflicting file across manual ZIPs; no extraction started')
            if any(parent in files for parent in paths[:-1]):
                raise ValueError('Manual ZIP file/directory collision; no extraction started')
            directories.update(paths[:-1])
            files[name] = (archive, info)
            count += 1
            size += info.file_size
        if component:
            components_total = bootstrap.setdefault(component, [0, 0])
            components_total[0] += count
            components_total[1] += size
    for component, expected in index['components'].items():
        if bootstrap.get(component) != [expected['files'], expected['bytes']]:
            raise ValueError('ZIP inventory differs from pinned producer totals: ' + component)
    if set(files) & directories:
        raise ValueError('Manual ZIP file/directory collision; no extraction started')
    own = index['files']
    bootstrap_names = {name for name, (archive, _) in files.items() if archive is components[0][0]}
    if bootstrap_names != set(own) | {BOOTSTRAP}:
        raise ValueError('Bootstrap ZIP contains a different owned-file set')
    for name, expected in own.items():
        archive, info = files[name]
        if info.file_size != expected['bytes'] or info.file_size > 2 * 1024 * 1024:
            raise ValueError('Bootstrap owned file exceeds its pinned bound')
        data = archive['zip'].read(info)
        if hashlib.sha256(data).hexdigest() != expected['sha256']:
            raise ValueError('Bootstrap original/plan/selection SHA differs')
    if own.get('manual-install-plan.json', {}).get('sha256') != PLAN_SHA:
        raise ValueError('Bootstrap source plan differs from the supported original contract')
    if (len(files) - len(bootstrap_names) != index['resource_files']
            or sum(info.file_size for name, (_, info) in files.items() if name not in bootstrap_names)
            != index['resource_bytes']):
        raise ValueError('All manual archive inventory totals must match before extraction')
    return files, directories


def _existing(a, resources, files, directories):
    remaining, allocated = 0, 0
    for base, folders, names in os.walk(resources, followlinks=False):
        for name in folders + names:
            path = Path(base) / name
            a.no_links(path)
            relative = path.relative_to(resources).as_posix()
            value = path.stat()
            if stat.S_ISDIR(value.st_mode):
                if relative not in directories:
                    raise ValueError('Unowned directory in interrupted extraction; preserved')
            elif (relative not in files or not stat.S_ISREG(value.st_mode)
                    or value.st_size > files[relative][1].file_size):
                raise ValueError('Unowned/oversized file in interrupted extraction; preserved')
            else:
                allocated += value.st_size
    for name, (_, info) in files.items():
        target = a.inside(resources, name)
        remaining += info.file_size - (target.stat().st_size if target.exists() else 0)
    return remaining, allocated


def _write_member(a, resources, name, archive, info, root_identity):
    a.no_links(resources)
    if [resources.parent.stat().st_dev, resources.parent.stat().st_ino] != root_identity:
        raise ValueError('Owned extraction root identity changed; stopped')
    target = a.inside(resources, name)
    target.parent.mkdir(parents=True, exist_ok=True)
    a.no_links(target)
    # O_APPEND ensures that even an unexpected concurrent append cannot cause
    # this process to overwrite previously present bytes after prefix checking.
    flags = os.O_RDWR | os.O_APPEND | getattr(os, 'O_NOFOLLOW', 0)
    if target.exists():
        fd = os.open(target, flags)
    else:
        fd = os.open(target, flags | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'r+b') as destination:
        before = os.fstat(destination.fileno())
        if not stat.S_ISREG(before.st_mode) or before.st_size > info.file_size:
            raise ValueError('Owned extraction path changed; existing file preserved')
        crc = 0
        if before.st_size == info.file_size:
            for block in iter(lambda: destination.read(CHUNK), b''):
                crc = zlib.crc32(block, crc)
            if crc & 0xffffffff != info.CRC:
                raise ValueError('Completed owned file was modified; no overwrite: ' + name)
            if _stamp(os.fstat(destination.fileno())) != _stamp(before):
                raise ValueError('Completed owned file changed during verification; preserved')
            return
        with archive['zip'].open(info) as source:
            # An interruption leaves bytes at the final owned path. Compare the
            # entire prefix before appending; never truncate, replace or delete.
            remaining = before.st_size
            while remaining:
                existing = destination.read(min(CHUNK, remaining))
                expected = source.read(len(existing))
                if not existing or existing != expected:
                    raise ValueError('Interrupted file prefix differs; preserved: ' + name)
                crc = zlib.crc32(existing, crc)
                remaining -= len(existing)
            if _stamp(os.fstat(destination.fileno())) != _stamp(before):
                raise ValueError('Owned file changed during prefix verification; preserved')
            for block in iter(lambda: source.read(CHUNK), b''):
                destination.write(block)
                crc = zlib.crc32(block, crc)
            destination.flush()
            os.fsync(destination.fileno())
        if destination.tell() != info.file_size or crc & 0xffffffff != info.CRC:
            raise ValueError('Extracted original differs from its authenticated ZIP; stopped')
        a.no_links(target)
        final = os.fstat(destination.fileno())
        if (target.stat().st_ino != final.st_ino or final.st_size != info.file_size
                or [resources.parent.stat().st_dev, resources.parent.stat().st_ino] != root_identity):
            raise ValueError('Extraction destination identity changed; stopped')


def extract_manual(args, a):
    """Preflight all local archives before creating the new resource root."""
    if args.plan or args.plan_id or args.plan_inline or args.token_file or args.diagnose_bundle:
        raise ValueError('Local manual extraction never uses a Drive plan/token/diagnostic')
    candidate = args.project.expanduser()
    if candidate.name != ROOT_NAME or candidate.is_symlink():
        raise ValueError('Extraction requires the exact new manual folder name')
    root = candidate.parent.resolve() / candidate.name
    a.no_links(root)
    if not root.parent.is_dir():
        raise ValueError('Selected Android Download directory is unavailable; no folder search')
    for path in root.parent.iterdir():
        if unicodedata.normalize('NFC', path.name).casefold() == _alias(ROOT_NAME) and path.name != ROOT_NAME:
            raise ValueError('Selected manual root has a case/Unicode alias; no automatic adoption')
    archives = args.manual_archives.expanduser().resolve() if args.manual_archives else root.parent
    a.no_links(archives)
    if not args.manual_bootstrap_zip or not args.manual_bootstrap_zip_sha256 or not args.manual_bootstrap_sha256:
        raise ValueError('Extraction needs the exact Bootstrap ZIP path, ZIP SHA and separate index SHA')
    bootstrap_path = args.manual_bootstrap_zip.expanduser()
    if not bootstrap_path.is_absolute():
        bootstrap_path = archives / bootstrap_path
    if bootstrap_path.parent.resolve() != archives or len(a.relative(bootstrap_path.name).parts) != 1:
        raise ValueError('Bootstrap ZIP must be in the selected archive directory')
    cache = args.cache.expanduser()
    if cache.is_symlink():
        raise ValueError('Extraction receipt cache cannot be a symlink')
    cache = cache.parent.resolve() / cache.name
    a.no_links(cache)
    with ExitStack() as stack:
        # The index cannot select another ZIP until its own ZIP and bytes pass.
        first = _archive(a, stack, bootstrap_path, {'bytes': 58800,
            'sha256': args.manual_bootstrap_zip_sha256})
        a.log('Local ZIP SHA verified: 1/62 (Bootstrap). No resource files written yet.')
        entries = _entries(a, first)
        index_entries = [info for name, info in entries if name == BOOTSTRAP and not info.is_dir()]
        if len(index_entries) != 1 or index_entries[0].file_size > 2 * 1024 * 1024:
            raise ValueError('Bootstrap requires one bounded index')
        data = first['zip'].read(index_entries[0])
        if hashlib.sha256(data).hexdigest() != a.pin(args.manual_bootstrap_sha256):
            raise ValueError('Bootstrap index SHA differs; ZIP SHA is a separate pin')
        index = json.loads(data)
        if (index.get('schema') != SCHEMA or index.get('complete') is not True
                or index.get('root_name') != ROOT_NAME or index.get('resource_directory') != RESOURCE_DIR
                or index.get('installer_commit') != INSTALLER_COMMIT
                or not isinstance(index.get('archives'), list) or len(index['archives']) != 61
                or not isinstance(index.get('files'), dict) or len(index['files']) != 4
                or not isinstance(index.get('components'), dict)
                or set(index['components']) != {'ui', 'maps', 'images', 'sprite'}):
            raise ValueError('Pinned manual bootstrap composition is unsupported/incomplete')
        names = {_alias(bootstrap_path.name)}
        components = [(first, entries, None)]
        compressed = 58800
        for row in index['archives']:
            name = row.get('name')
            if (not isinstance(name, str) or len(a.relative(name).parts) != 1
                    or not name.endswith('.zip') or _alias(name) in names
                    or row.get('component') not in index['components']):
                raise ValueError('Pinned archive list has aliases, duplicates or unsupported names')
            names.add(_alias(name))
            path = a.inside(archives, name)
            if not path.exists():
                raise ValueError('Exact downloaded filename missing (do not use renamed (1) copies): ' + name)
            archive = _archive(a, stack, path, row)
            components.append((archive, _entries(a, archive), row['component']))
            compressed += row['bytes']
            a.log('Local ZIP SHA verified: %d/62 (%s). No resource files written yet.' % (len(components), name))
        files, directories = _inventory(a, {}, index, components)
        total = sum(info.file_size for _, info in files.values())
        # Refuse aliases already present in Download rather than relying on its
        # particular case-sensitive/case-insensitive filesystem implementation.
        for path in archives.iterdir():
            key = unicodedata.normalize('NFC', path.name).casefold()
            if key in names and path.name not in {x['name'] for x in index['archives']} | {bootstrap_path.name}:
                raise ValueError('A downloaded archive has a case/Unicode filename alias')
        for archive, _, _ in components:
            _unchanged(a, archive)
        a.log('All 62 local ZIPs authenticated before extraction: %d ZIP bytes; %d files / %d extracted bytes. Code/Git and filesystem space are additional.' % (compressed, len(files), total))
        work = cache / ('manual-extract-' + hashlib.sha256(str(root).encode()).hexdigest()[:16])
        a.no_links(work)
        work.mkdir(parents=True, exist_ok=True)
        with a.install_lock(work / 'extract.lock'):
            receipt = work / 'extraction-state.json'
            state = a.read_json(receipt) if receipt.exists() else None
            if root.exists():
                if (not root.is_dir() or not state or state.get('schema') != EXTRACT_SCHEMA
                        or state.get('root') != str(root) or state.get('index_sha256') != args.manual_bootstrap_sha256
                        or state.get('bootstrap_zip_sha256') != args.manual_bootstrap_zip_sha256
                        or state.get('root_identity') != [root.stat().st_dev, root.stat().st_ino]):
                    raise ValueError('Existing folder has no matching extraction ownership receipt; no takeover')
                if state.get('complete') is True:
                    a.log('Owned extraction already completed; existing manual resource/code guards will reverify it.')
                    return
                if any(path.name != RESOURCE_DIR for path in root.iterdir()):
                    raise ValueError('Unowned content beside interrupted resources; no automatic adoption')
                resources = a.inside(root, RESOURCE_DIR)
                remaining, _ = _existing(a, resources, files, directories)
            else:
                if state:
                    raise ValueError('Owned extraction root is absent; old receipt preserved, no recreation')
                remaining = total
            # Download ZIPs are already on disk. Add remaining extraction plus
            # conservative per-file allocation and code reserve, not 8GB copy.
            reserve = len(files) * 8192 + 512 * 1024 * 1024
            if a.shutil.disk_usage(root.parent).free < remaining + reserve:
                raise ValueError('Insufficient free space: extraction needs %d remaining bytes plus %d allocation/code reserve; ZIPs and existing files preserved' % (remaining, reserve))
            if not root.exists():
                root.mkdir(exist_ok=False)
                state = {'schema': EXTRACT_SCHEMA, 'root': str(root), 'index_sha256': args.manual_bootstrap_sha256,
                    'bootstrap_zip_sha256': args.manual_bootstrap_zip_sha256,
                    'root_identity': [root.stat().st_dev, root.stat().st_ino], 'complete': False}
                # Private Termux cache journal uses atomic replace; resource
                # publication never relies on shared-storage atomic rename.
                a.json_write(receipt, state)
            resources = a.inside(root, RESOURCE_DIR)
            resources.mkdir(exist_ok=True)
            _existing(a, resources, files, directories)
            for number, (archive, entries, _) in enumerate(components, 1):
                _unchanged(a, archive)
                progress_files, progress_bytes = 0, 0
                for name, info in entries:
                    if not info.is_dir():
                        _write_member(a, resources, name, archive, info, state['root_identity'])
                        progress_files += 1
                        progress_bytes += info.file_size
                        if progress_files >= 1024 or progress_bytes >= 128 * 1024 * 1024:
                            a.log('Local extraction in ZIP %d/62: next %d files / %d declared bytes verified in place.' % (number, progress_files, progress_bytes))
                            progress_files, progress_bytes = 0, 0
                _unchanged(a, archive)
                a.log('Local ZIP extraction verified: %d/62; downloaded ZIPs retained.' % number)
            state['complete'] = True
            a.json_write(receipt, state)
            a.log('All originals extracted once in place. Continuing existing manual original/owner guards and minimal GitHub code installation.')


def main():
    import argparse
    import install_private_sources as a
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path.home() / 'storage/downloads' / ROOT_NAME)
    parser.add_argument('--manual-archives', type=Path)
    parser.add_argument('--manual-bootstrap-zip', type=Path,
        default=Path('TWILIGHT_Source523_Manual_Bootstrap_20261106.zip'))
    parser.add_argument('--manual-bootstrap-zip-sha256', type=a.pin, required=True)
    parser.add_argument('--manual-bootstrap-sha256', type=a.pin, required=True)
    parser.add_argument('--cache', type=Path, default=Path.home() / '.cache/twilight-private-install')
    args = parser.parse_args()
    args.plan = args.plan_id = args.plan_inline = args.token_file = args.diagnose_bundle = None
    try:
        extract_manual(args, a)
        command = [sys.executable, str(Path(a.__file__)), '--manual-resources',
            '--project', str(args.project.expanduser()), '--manual-bootstrap-sha256', args.manual_bootstrap_sha256,
            '--cache', str(args.cache.expanduser())]
        if args.manual_archives:
            command += ['--manual-archives', str(args.manual_archives.expanduser())]
        # The separate published 768 entry point remains unchanged. Extraction
        # ownership stays outside the project; its original adoption/code/SHA
        # guards run normally and never receive a Drive plan or credentials.
        return subprocess.call(command, stdin=subprocess.DEVNULL)
    except (OSError, ValueError, KeyError, RuntimeError, zipfile.BadZipFile, zlib.error) as error:
        a.log('LOCAL EXTRACTION STOPPED: ' + str(error))
        a.log('ZIPs, originals, receipts and existing files were preserved. No automatic retry, deletion, overwrite, Drive call or fallback. Resume only the same owned extraction after addressing the stated cause.')
        return 1


if __name__ == '__main__':
    sys.exit(main())
