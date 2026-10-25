#!/usr/bin/env python3
"""Update a ZIP-installed TWILIGHT Godot project without requiring Git metadata.

Downloads only changed tracked files from a pinned GitHub main commit. It never
deletes untracked game files or Godot user:// save files. Replaced old files are
preserved in a timestamped backup directory. No destructive git operations.
"""
import argparse
import hashlib
import json
import os
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


# Only paths needed by Godot and its updater belong in a mobile install.
# In October the repository gained tens of thousands of documentation and
# generated test/evidence files. Keep older local copies of those untouched.
RUNTIME_ROOTS = frozenset(('addons', 'assets', 'data', 'external_map_packs',
                           'scenes', 'scripts', 'tools'))
RUNTIME_FILES = frozenset(('project.godot', 'Main.tscn', 'export_presets.cfg'))


def is_runtime_path(path):
    relative = safe_path(path)
    return relative.parts[0] in RUNTIME_ROOTS or str(relative) in RUNTIME_FILES


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
                if not is_runtime_path(path):
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
    print('GitHub inventory complete (sharded trees):', len(rows), flush=True)
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


def update(root, assume_yes=False):
    root = root.expanduser().resolve()
    if not (root / 'project.godot').is_file() or not (root / 'Main.tscn').is_file():
        raise RuntimeError('TWILIGHT Godot project not found. Provide TWILIGHT_Play directory.')
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
    if not changed and not removed:
        print('Already up to date.')
        return
    if not assume_yes and input('Proceed with verified update? Type YES: ').strip() != 'YES':
        print('Cancelled without changes.')
        return
    with tempfile.TemporaryDirectory(prefix='.twilight_update_stage_', dir=root) as tmp:
        stage = Path(tmp)
        for idx, name in enumerate(changed, 1):
            download_verified(commit_sha, name, inventory[name], stage / name)
            if idx % 25 == 0 or idx == len(changed):
                print('Downloaded and verified:', idx, '/', len(changed), flush=True)
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        backup = root / ('.twilight_update_backup_' + stamp)
        if backup.exists():
            raise RuntimeError('Backup folder already exists')
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
        print('UPDATE OK:', commit_sha[:12])
        print('Original changed files saved in:', backup)
        print('Close Godot and re-import TWILIGHT_Play/project.godot.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('project', type=Path, help='Existing ZIP-extracted Godot project directory')
    parser.add_argument('--yes', action='store_true', help='Skip the YES confirmation after verifying changes')
    args = parser.parse_args()
    try:
        update(args.project, args.yes)
    except (OSError, ValueError, RuntimeError) as ex:
        print('UPDATE STOPPED:', ex, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
