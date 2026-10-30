#!/usr/bin/env python3
"""Update a ZIP-installed TWILIGHT Godot project without requiring Git metadata.

Downloads only changed gameplay files from a pinned GitHub main commit. It never
deletes untracked game files or Godot user:// save files. Replaced old files are
preserved in a timestamped backup directory. No destructive git operations.
"""
import argparse
import hashlib
import json
import os
import stat
import re
import shutil
from concurrent.futures import ThreadPoolExecutor, wait, FIRST_COMPLETED
from pathlib import Path, PurePosixPath
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone

REPOSITORY = 'zoog136-hash/-'
API = f'https://api.github.com/repos/{REPOSITORY}'
AGENT = 'TWILIGHT-Termux-Zip-Updater/1.0'
STATE_FILE = '.twilight_update_state.json'


def safe_path(path):
    if not isinstance(path, str) or not path or '\\' in path:
        raise ValueError('Unsafe file path')
    p = PurePosixPath(path)
    if p.is_absolute() or any(part in ('..', '.', '') for part in path.split('/')):
        raise ValueError('Unsafe file path: ' + path)
    if p.parts[0] in ('.git', '.godot') or p.name.startswith('.twilight_update'):
        raise ValueError('Protected destination: ' + path)
    return p


def ensure_not_symlink(root, relative):
    current = root
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError('Symlink in destination: ' + str(relative))


def request(url):
    accept = 'application/vnd.github+json' if url.startswith(API) else 'application/octet-stream'
    return urllib.request.Request(url, headers={'User-Agent': AGENT, 'Accept': accept})


def fetch_json(url):
    last = None
    for trial in range(3):
        try:
            with urllib.request.urlopen(request(url), timeout=40) as handle:
                return json.load(handle)
        except (OSError, ValueError) as ex:
            last = ex
            time.sleep(trial + 1)
    raise RuntimeError('GitHub metadata request failed: ' + str(last))


def sha1_of_blob(path, size):
    digest = hashlib.sha1()
    digest.update(f'blob {size}\0'.encode('ascii'))
    with path.open('rb') as src:
        for block in iter(lambda: src.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


# The phone opens project.godot in Godot, not a development/CI checkout.
# Download gameplay code/data/art, never original map archives, reports, source
# material, QA outputs, or authoring scripts. A ZIP already on the device is
# intentionally NOT cleaned up merely because this allowlist narrows.
RUNTIME_ROOTS = frozenset((
    'addons', 'assets', 'data', 'external_map_packs', 'scenes', 'scripts',
))
RUNTIME_FILES = frozenset(('project.godot', 'Main.tscn'))
RUNTIME_SUFFIXES = frozenset((
    '.gd', '.gdshader', '.gdshaderinc', '.gdextension', '.tscn', '.tres',
    '.res', '.uid', '.cfg', '.json', '.bin', '.nav', '.l1jpng',
    '.png', '.jpg', '.jpeg', '.webp', '.svg', '.ttf', '.otf',
    '.ogg', '.wav', '.mp3', '.flac', '.glb',
))
# Map source PNGs alone exceed half a gigabyte and are NOT loaded by gameplay.
# These four directories hold the actual runtime map packs.
RUNTIME_MAP_PACKS = frozenset((
    'native_png_v5', 'aden_faith_png_v1', 'domination_png_v1', 'oman_png_v1',
))
# Match the already audited Android export exclusions for offline map drafting.
OFFLINE_DIRS = (
    'assets/maps/aden_city_region',
    'assets/maps/aden_modular_district_01',
    'assets/maps/aden_modular_pilot',
    'assets/maps/aden_rebuild_preview',
    'assets/maps/aden_world_draft',
    'assets/original_sheets',
)
OFFLINE_FILES = frozenset((
    'scripts/maps/aden_modular_preview_renderer.gd',
    'data/map_remake/private/aden/effective_layouts_build.json',
    'data/skills/research_inventory.json',
    'data/resource_delivery_ledger.json',
    'data/animation_authoring_sources.json',
    'data/v19_extraction_manifest.json',
    'data/visuals/pr80_original_asset_hashes.json',
    'data/maps/aden_faith_png_archive.json',
    'data/maps/native_png_archive.json',
    'scenes/SkillVFXLab.tscn',
))


def is_runtime_tree(path):
    """Whether a repository directory can contain mobile gameplay files."""
    relative = safe_path(path)
    parts = relative.parts
    if parts[0] not in RUNTIME_ROOTS:
        return False
    if any(path == prefix or path.startswith(prefix + '/') for prefix in OFFLINE_DIRS):
        return False
    if len(parts) > 1 and parts[0] == 'external_map_packs' and parts[1] not in RUNTIME_MAP_PACKS:
        return False
    if len(parts) > 1 and parts[0] == 'data' and parts[1].startswith('pr122_'):
        return False
    if (len(parts) >= 6 and parts[:4] == ('assets', 'actors', 'eight_direction',
                                          'native_locomotion_staging')
            and parts[4].startswith('transform_') and parts[5] == 'draft001'):
        return False
    return True


def is_runtime_path(path):
    """Allow only playable resources; no documentation, backups or test data."""
    relative = safe_path(path)
    if path in RUNTIME_FILES:
        return True
    if path == 'external_map_packs/.gdignore':
        return True  # Keep Godot from importing the manually streamed map packs.
    if not is_runtime_tree(path) or path in OFFLINE_FILES:
        return False
    if relative.name.endswith(('.bak', '.tmp', '.backup')):
        return False
    return relative.suffix.lower() in RUNTIME_SUFFIXES


def get_inventory():
    """Read a complete Git tree even after GitHub's recursive response limit.

    A recursive request for the entire repository can return HTTP 200 with
    `truncated=true` when its JSON result is too large. Never trust that
    partial inventory: a missing row might otherwise be treated as deletion.
    Read the root's direct children and shard by their *immutable tree SHAs*.
    If a subtree is itself truncated, subdivide it again.
    """
    commit = fetch_json(API + '/commits/main')
    sha = commit['sha']
    tree_sha = commit['commit']['tree']['sha']
    if not isinstance(sha, str) or len(sha) != 40 or not isinstance(tree_sha, str) or len(tree_sha) != 40:
        raise RuntimeError('Invalid pinned GitHub commit/tree response')
    rows = {}

    def validated_tree(tree_id, recursive):
        url = API + '/git/trees/' + tree_id
        if recursive:
            url += '?recursive=1'
        data = fetch_json(url)
        if (not isinstance(data, dict) or data.get('sha') != tree_id
                or not isinstance(data.get('tree'), list)
                or not isinstance(data.get('truncated'), bool)):
            raise RuntimeError('Incomplete GitHub tree metadata; no files updated')
        return data

    def add_blob(path, entry):
        relative = safe_path(path)
        if not is_runtime_path(path):
            return
        size = entry.get('size')
        blob_sha = entry.get('sha')
        mode = entry.get('mode')
        if (mode not in ('100644', '100755') or not isinstance(size, int)
                or size < 0 or not isinstance(blob_sha, str) or len(blob_sha) != 40):
            raise RuntimeError('Unsupported or incomplete GitHub blob: ' + path)
        if path in rows:
            raise RuntimeError('Duplicate GitHub path: ' + path)
        rows[str(relative)] = {'size': size, 'sha': blob_sha, 'mode': mode}

    def walk(tree_id, prefix='', depth=0, ancestors=()):
        if depth > 32 or tree_id in ancestors:
            raise RuntimeError('Unexpected cyclic/deep GitHub tree; no files updated')
        # Root direct listing is intentionally small. Avoid repeatedly fetching
        # the known-truncated whole-repository recursive response.
        recursive = validated_tree(tree_id, True) if prefix else None
        if recursive is not None and not recursive['truncated']:
            for entry in recursive['tree']:
                relative = entry.get('path')
                safe_path(relative)
                path = prefix + relative
                if entry.get('type') == 'blob':
                    add_blob(path, entry)
                elif entry.get('type') == 'tree' and entry.get('mode') == '040000':
                    continue
                else:
                    raise RuntimeError('Unsupported GitHub tree entry: ' + path)
            return

        # A truncated recursive response is discarded altogether. An immutable
        # nonrecursive tree has every immediate child and can be split safely.
        direct = validated_tree(tree_id, False)
        if direct['truncated']:
            raise RuntimeError('Incomplete direct GitHub tree; no files updated')
        for entry in direct['tree']:
            relative = entry.get('path')
            safe_path(relative)
            path = prefix + relative
            if entry.get('type') == 'blob':
                add_blob(path, entry)
            elif entry.get('type') == 'tree' and entry.get('mode') == '040000':
                if not is_runtime_tree(path):
                    continue
                child_sha = entry.get('sha')
                if not isinstance(child_sha, str) or len(child_sha) != 40:
                    raise RuntimeError('Invalid child GitHub tree: ' + path)
                walk(child_sha, path + '/', depth + 1, ancestors + (tree_id,))
            else:
                raise RuntimeError('Unsupported GitHub tree entry: ' + path)

    walk(tree_sha)
    if not rows or not {'project.godot', 'Main.tscn'}.issubset(rows):
        raise RuntimeError('Missing required Godot project files')
    print('GitHub gameplay inventory:', len(rows), 'files,',\
          sum(row['size'] for row in rows.values()), 'bytes', flush=True)
    return sha, rows

def download_verified(commit_sha, relative, row, dest):
    safe_path(relative)
    url = ('https://raw.githubusercontent.com/' + REPOSITORY + '/' + commit_sha + '/' +
           '/'.join(urllib.parse.quote(seg, safe='') for seg in relative.split('/')))
    dest.parent.mkdir(parents=True, exist_ok=True)
    last = None
    for trial in range(3):
        try:
            digest = hashlib.sha1(f"blob {row['size']}\0".encode())
            n = 0
            with urllib.request.urlopen(request(url), timeout=180) as response, dest.open('wb') as output:
                while True:
                    block = response.read(1024 * 1024)
                    if not block:
                        break
                    n += len(block)
                    if n > row['size']:
                        raise ValueError('File exceeds pinned GitHub length')
                    digest.update(block)
                    output.write(block)
            if n != row['size'] or digest.hexdigest() != row['sha']:
                raise ValueError('Git blob SHA mismatch: ' + relative)
            return
        except (OSError, ValueError) as ex:
            last = ex
            dest.unlink(missing_ok=True)
            time.sleep(trial + 1)
    raise RuntimeError('Download failed before applying updates: ' + relative + ' ' + str(last))


def load_old_state(root):
    path = root / STATE_FILE
    if not path.exists():
        return {}
    try:
        state = json.loads(path.read_text(encoding='utf-8'))
        tracked = state.get('tracked_files')
        if not isinstance(tracked, list):
            return {}
        for item in tracked:
            safe_path(item)
        return {'tracked_files': tracked}
    except (ValueError, OSError) as ex:
        raise RuntimeError('Invalid updater state; refusing to delete previous files') from ex


def update(root, assume_yes=False, install_fresh=False, workers=6):
    # Fresh installs may create ONLY an absent or empty destination. Never
    # overwrite a partly installed game, user files, or an existing Git checkout.
    if not isinstance(workers, int) or not 1 <= workers <= 12:
        raise ValueError('Concurrent downloads must be between 1 and 12.')
    candidate = root.expanduser()
    if install_fresh:
        if candidate.is_symlink():
            raise RuntimeError('Fresh install destination cannot be a symlink.')
        if candidate.exists():
            # After an interrupted install, only our pinned-commit stage
            # directory is allowed. A real user file or game file is protected.
            def is_resume_stage(child):
                return (child.is_dir() and not child.is_symlink() and
                        re.fullmatch(r'\.twilight_update_stage_[0-9a-f]{40}', child.name))
            if not candidate.is_dir() or any(
                    not is_resume_stage(child) for child in candidate.iterdir()):
                raise RuntimeError('Fresh install requires an EMPTY TWILIGHT_Play folder '
                                   'or verified resumable download cache. '
                                   'Existing files were not modified.')
        else:
            if not candidate.parent.is_dir():
                raise RuntimeError('Downloads folder not accessible; run termux-setup-storage.')
            candidate.mkdir()
    root = candidate.resolve()
    if not install_fresh and (
            not (root / 'project.godot').is_file() or
            not (root / 'Main.tscn').is_file()):
        raise RuntimeError('TWILIGHT Godot project not found. '
                           'For a deleted folder, use --install-fresh.')
    if (root / '.git').exists():
        raise RuntimeError('This folder has Git metadata. ZIP updater refuses Git checkouts.')
    commit_sha, inventory = get_inventory()
    old_state = load_old_state(root)
    changed = []
    print('GitHub main:', commit_sha[:12], 'tracked files:', len(inventory), flush=True)
    for idx, (name, row) in enumerate(inventory.items(), 1):
        relative = safe_path(name)
        ensure_not_symlink(root, relative)
        existing = root / relative
        if existing.exists() and not existing.is_file():
            raise RuntimeError('Folder conflicts with update file: ' + name)
        if (not existing.exists() or existing.stat().st_size != row['size'] or
                sha1_of_blob(existing, row['size']) != row['sha']):
            changed.append(name)
        if idx % 3000 == 0:
            print('Compared:', idx, '/', len(inventory), flush=True)
    # Previous updater versions managed documentation too. Leave those older
    # local non-runtime files alone rather than treating this scope change as
    # a request to delete or back up thousands of documents.
    removed = sorted(name for name in
                     set(old_state.get('tracked_files', [])) - set(inventory)
                     if is_runtime_path(name))
    for name in removed:
        ensure_not_symlink(root, safe_path(name))
    print('Changes to download:', len(changed), 'Retired managed files:', len(removed), flush=True)
    if install_fresh:
        needed = sum(inventory[name]['size'] for name in changed)
        free_bytes = __import__('shutil').disk_usage(root).free
        print('FRESH INSTALL:', len(changed), 'game files;',
              '%.2f GiB' % (needed / 1024**3), 'to download', flush=True)
        if needed > free_bytes:
            raise RuntimeError('Not enough free space for fresh game install '
                               '(%.2f GiB needed, %.2f GiB free).' %
                               (needed / 1024**3, free_bytes / 1024**3))
    if not changed and not removed:
        print('Already up to date.')
        return
    if not assume_yes and input('Proceed with verified update? Type YES: ').strip() != 'YES':
        print('Cancelled without changes.')
        return
    # Keep verified downloads across network failure, Ctrl+C or a lost session.
    # The SHA in the directory name ties the cache to one immutable Git commit.
    stage = root / ('.twilight_update_stage_' + commit_sha)
    if stage.is_symlink() or (stage.exists() and not stage.is_dir()):
        raise RuntimeError('Unsafe persisted download stage; no project files updated.')
    stage.mkdir(exist_ok=True)
    pending = []
    reused = 0
    reused_bytes = 0
    total_bytes = sum(inventory[name]['size'] for name in changed)
    for name in changed:
        relative = safe_path(name)
        ensure_not_symlink(stage, relative)
        cached = stage / relative
        if cached.exists():
            if not cached.is_file() or cached.is_symlink():
                raise RuntimeError('Unsafe cached download: ' + name)
            row = inventory[name]
            if (cached.stat().st_size == row['size'] and
                    sha1_of_blob(cached, row['size']) == row['sha']):
                reused += 1
                reused_bytes += row['size']
                continue
            cached.unlink()  # Only an invalid copy inside our private stage.
        pending.append(name)
    if reused:
        print('Resumed verified downloads:', reused, 'files,',
              '%.1f MiB' % (reused_bytes / 1024**2), flush=True)
    print('Downloading with', workers, 'parallel connections:',
          len(pending), 'files, %.1f MiB' %
          ((total_bytes - reused_bytes) / 1024**2), flush=True)
    completed, completed_bytes = reused, reused_bytes
    next_progress = 25
    # Bound the futures to two batches so thousands of tiny images do not
    # allocate thousands of Future objects on an Android device.
    if pending:
        with ThreadPoolExecutor(max_workers=workers) as executor:
            iterator = iter(pending)
            futures = {}
            for _ in range(min(workers * 2, len(pending))):
                name = next(iterator)
                future = executor.submit(download_verified, commit_sha, name,
                                         inventory[name], stage / name)
                futures[future] = name
            try:
                while futures:
                    done, _ = wait(tuple(futures), return_when=FIRST_COMPLETED)
                    for future in done:
                        name = futures.pop(future)
                        future.result()  # Any failed verified download stops apply.
                        completed += 1
                        completed_bytes += inventory[name]['size']
                        if completed >= next_progress or completed == len(changed):
                            print('Verified:', completed, '/', len(changed),
                                  'files; %.1f / %.1f MiB' %
                                  (completed_bytes / 1024**2,
                                   total_bytes / 1024**2), flush=True)
                            next_progress = completed + 25
                        next_name = next(iterator, None)
                        if next_name is not None:
                            new_future = executor.submit(
                                download_verified, commit_sha, next_name,
                                inventory[next_name], stage / next_name)
                            futures[new_future] = next_name
            except BaseException:
                for future in futures:
                    future.cancel()
                print('Downloads paused. Verified files remain for next run.',
                      flush=True)
                raise
    # No project file is modified until ALL staged downloads are verified.

    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = root / ('.twilight_update_backup_' + stamp)
    if backup.exists():
        raise RuntimeError('Backup folder already exists')
    if not install_fresh:
        backup.mkdir()
    applied = []
    try:
        for name in changed + removed:
            target = root / name
            prior = backup / name
            had_old = target.exists()
            if had_old:
                prior.parent.mkdir(parents=True, exist_ok=True)
                os.replace(target, prior)
            applied.append((name, had_old))
            if name in inventory:
                target.parent.mkdir(parents=True, exist_ok=True)
                os.replace(stage / name, target)
                if inventory[name].get('mode') == '100755':
                    target.chmod(target.stat().st_mode | 0o111)
        state_tmp = root / (STATE_FILE + '.tmp')
        state_tmp.write_text(json.dumps({'sha': commit_sha, 'tracked_files': sorted(inventory)}, ensure_ascii=False) + '\n', encoding='utf-8')
        os.replace(state_tmp, root / STATE_FILE)
    except BaseException:
        for name, had_old in reversed(applied):
            target = root / name
            if target.exists():
                target.unlink()
            prior = backup / name
            if had_old and prior.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                os.replace(prior, target)
        raise
    # The stage was only our pinned verified downloads; after successful
    # atomic application all gameplay files have moved to the destination.
    shutil.rmtree(stage)
    print('INSTALL OK:' if install_fresh else 'UPDATE OK:', commit_sha[:12])
    if not install_fresh:
        print('Original changed files saved in:', backup)
    print('Close Godot and re-import TWILIGHT_Play/project.godot.')



# Curated offline-only categories. We scan the EXTRACTED project rather than
# relying on updater state: users may have installed a full ZIP before updating,
# and a recent scoped update may have replaced the older tracked-files list.
# Keep the game, save data, Godot import cache and update rollback backups.
CLEANUP_DIRECTORIES = (
    'docs', 'tests', 'tools', 'samples', '.github', 'legacy',
    'external_map_packs/source_pngs', 'external_map_packs/oman_v2',
    'assets/original_sheets',
) + OFFLINE_DIRS
CLEANUP_FILES = OFFLINE_FILES | frozenset((
    'external_map_packs/TWILIGHT-map-remake-private-20261015-v2.zip',
    'external_map_packs/MAP_ASSET_DELIVERY.json',
    'external_map_packs/README.md',
    'external_map_packs/.gitattributes',
    'README.md', 'README_KO.md', 'AGENTS.md',
    'TWILIGHT_PROJECT_RULES.md', 'TWILIGHT_VERSION_HISTORY.md',
    'export_presets.cfg',
))
PROTECTED_PARTS = frozenset(('.git', '.godot', 'user', 'user_data'))


def _cleanup_scopes(root):
    """Fixed offline-only roots, plus narrowly named authoring manifests."""
    scopes = set(CLEANUP_DIRECTORIES) | set(CLEANUP_FILES)
    data = root / 'data'
    if data.is_dir() and not data.is_symlink():
        for path in data.glob('pr122_*'):
            scopes.add(path.relative_to(root).as_posix())
    drafts = root / 'assets/actors/eight_direction/native_locomotion_staging'
    if drafts.is_dir() and not drafts.is_symlink():
        for path in drafts.glob('transform_*/draft001'):
            scopes.add(path.relative_to(root).as_posix())
    return sorted(scopes)


def _protected_cleanup_path(name):
    parts = safe_path(name).parts
    return any(part in PROTECTED_PARTS or
               part.startswith('.twilight_update') for part in parts)


def list_unused_files(root):
    """Return pinned file snapshots, never following symlinks or runtime paths."""
    found = {}
    for name in _cleanup_scopes(root):
        if _protected_cleanup_path(name) or is_runtime_path(name):
            continue
        source = root / safe_path(name)
        if source.is_symlink():
            continue
        if source.is_file():
            entries = [source]
        elif source.is_dir():
            entries = []
            for base, folders, files in os.walk(source, followlinks=False):
                # Never traverse links, protected subtrees or updater backups.
                folders[:] = [folder for folder in folders
                              if folder not in PROTECTED_PARTS
                              and not folder.startswith('.twilight_update')
                              and not (Path(base) / folder).is_symlink()]
                entries.extend(Path(base) / file for file in files)
        else:
            continue
        for path in entries:
            relative = path.relative_to(root).as_posix()
            if relative in found or _protected_cleanup_path(relative):
                continue
            if is_runtime_path(relative):
                continue
            ensure_not_symlink(root, safe_path(relative))
            info = path.lstat()
            if not stat.S_ISREG(info.st_mode):
                continue
            found[relative] = (info.st_size, info.st_dev, info.st_ino,
                               info.st_mtime_ns)
    return found


def cleanup_unused(root, delete=False):
    """Preview or explicitly delete known offline-only files; never via update()."""
    root = root.expanduser().resolve()
    if not (root / 'project.godot').is_file() or not (root / 'Main.tscn').is_file():
        raise RuntimeError('TWILIGHT Godot project not found. Supply TWILIGHT_Play.')
    if (root / '.git').exists():
        raise RuntimeError('Refusing to clean a Git checkout.')
    snapshots = list_unused_files(root)
    total = sum(row[0] for row in snapshots.values())
    print('UNUSED FILE PREVIEW:', len(snapshots), 'files,',
          '%.2f GiB' % (total / 1024**3), '(%d bytes)' % total, flush=True)
    sizes = {}
    for name, row in snapshots.items():
        bucket = name.split('/')[0]
        if bucket in ('assets', 'data', 'external_map_packs'):
            bucket = '/'.join(name.split('/')[:2])
        count, size = sizes.get(bucket, (0, 0))
        sizes[bucket] = (count + 1, size + row[0])
    for name, (count, size) in sorted(sizes.items(),
                                       key=lambda item: -item[1][1]):
        print('  %-39s %6d files %8.1f MiB' %
              (name, count, size / 1024**2), flush=True)
    print('Largest candidates:', flush=True)
    for name, row in sorted(snapshots.items(),
                            key=lambda item: -item[1][0])[:12]:
        print('  %.1f MiB  %s' % (row[0] / 1024**2, name), flush=True)
    print('PROTECTED: game resources, .godot, user saves, update backups,'
          ' symlinks and other folders.', flush=True)
    if not delete:
        print('Preview only. No files deleted.', flush=True)
        return (len(snapshots), total)
    if not snapshots:
        print('Nothing to remove.', flush=True)
        return (0, 0)
    print('WARNING: This permanently deletes files in the OFFLINE folders'
          ' above, including any personal files placed there.', flush=True)
    if input('Type DELETE UNUSED to confirm: ').strip() != 'DELETE UNUSED':
        print('Cancelled; no files deleted.', flush=True)
        return (0, 0)
    # Fail closed if *any* candidate changed after the preview, so no partial
    # cleanup occurs because files were modified during confirmation.
    for name, recorded in snapshots.items():
        ensure_not_symlink(root, safe_path(name))
        info = (root / name).lstat()
        if (not stat.S_ISREG(info.st_mode) or
                (info.st_size, info.st_dev, info.st_ino, info.st_mtime_ns)
                != recorded):
            raise RuntimeError('File changed since preview; no cleanup done: ' + name)
    removed = 0
    freed = 0
    for name, recorded in sorted(snapshots.items()):
        path = root / name
        ensure_not_symlink(root, safe_path(name))
        info = path.lstat()
        if (not stat.S_ISREG(info.st_mode) or
                (info.st_size, info.st_dev, info.st_ino, info.st_mtime_ns)
                != recorded):
            raise RuntimeError('File changed during cleanup: ' + name)
        path.unlink()
        removed += 1
        freed += recorded[0]
    print('CLEANUP OK:', removed, 'files, %.2f GiB freed' %
          (freed / 1024**3), flush=True)
    print('Leave .twilight_update_backup_* in place until the game is verified.')
    return (removed, freed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('project', type=Path, help='Existing ZIP-extracted Godot project directory')
    parser.add_argument('--yes', action='store_true', help='Skip the YES confirmation after verifying changes')
    cleanup = parser.add_mutually_exclusive_group()
    cleanup.add_argument('--cleanup-preview', action='store_true',
                         help='List unused report/authoring files and possible space saved; no deletion')
    cleanup.add_argument('--cleanup-unused', action='store_true',
                         help='Preview and delete offline-only files only after typing DELETE UNUSED')
    cleanup.add_argument('--install-fresh', action='store_true',
                         help='Restore game files into a deleted or empty TWILIGHT_Play folder')
    parser.add_argument('--workers', type=int, default=6, metavar='N',
                        help='Parallel verified downloads (1-12; default 6)')
    args = parser.parse_args()
    try:
        if args.cleanup_preview or args.cleanup_unused:
            cleanup_unused(args.project, delete=args.cleanup_unused)
        else:
            update(args.project, args.yes, install_fresh=args.install_fresh, workers=args.workers)
    except (OSError, ValueError, RuntimeError) as ex:
        print('UPDATE STOPPED:', ex, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
