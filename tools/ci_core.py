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
    ('core_runtime_save_test', []),
    ('save_identical_payload_test', []),
    ('deferred_save_gate_test', ['--gate-only']),
    ('symbol_source523_test', []),
    ('symbol_source523_main_ui_test', []),
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
    snapshot = policy['maps']['aden_world']['gameplay_snapshot'].removeprefix('res://')
    if '..' in PurePosixPath(snapshot).parts or not snapshot.startswith('data/'):
        raise ValueError('unsafe current gameplay snapshot')
    gameplay = json.loads(read(snapshot))['gameplay']
    names = {name for region in gameplay['monster_spawn'] for name in region['monster_types']}
    profiles = json.loads(read('data/combat_animation_profiles.json'))['profiles']
    keys = {key for key in profiles if key.startswith('class:') or key in {'monster:'+n for n in names}}
    records = [profiles[key] for key in sorted(keys)]
    records += [row for row in json.loads(read('data/game_db_v17.json'))['몬스터'] if row['name'] in names]
    for path, field in [('data/monsters/reviewed_existing_visuals.json','bindings'),
                        ('data/visuals/runtime_manifest.json','monsters')]:
        if exists(path):
            records += [value for key,value in json.loads(read(path))[field].items() if key in names]
    paths = {m.group(1).removeprefix('res://') for m in REFERENCE.finditer(json.dumps(records, ensure_ascii=False))}
    return {'map_id':'aden_world', 'monster_names':sorted(names), 'profile_keys':sorted(keys),
            'paths':paths, 'basis':snapshot}

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
                required = PurePosixPath(path).suffix in {'.tscn', '.tres'} or re.search(r'preload\s*\(\s*$', text[:match.start()])
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
        # Source monster expansion can replace a current roster record after
        # the static name join. Its bound portrait is also used while the UI
        # is open and initial spawns drain. Keep these small portraits without
        # importing every inactive animation bank.
        live.update(p for p in selected if p.startswith('assets/monsters/reviewed_source/')
                    and p.endswith('/portrait.png'))
        while actor_queue:
            path = actor_queue.pop()
            if path in live or not path.startswith(ACTOR_PREFIXES) or not PurePosixPath(path).suffix or '%' in path:
                continue
            if not exists(path):
                raise FileNotFoundError('current actor resource '+path)
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
            marker = {'core_runtime_save_test':'CORE_RUNTIME_SAVE_RESULT',
                      'save_identical_payload_test':'SAVE_IDENTICAL_PAYLOAD_RESULT',
                      'deferred_save_gate_test':'DEFERRED_SAVE_GATE_RESULT',
                      'symbol_source523_test':'SYMBOL523_TEST',
                      'symbol_source523_main_ui_test':'SYMBOL523_MAIN_RESULT'}[name]
            run(command, target, logs/(name+'.txt'), env, 180, marker)
            print('CORE_CHECK_OK', name, flush=True)

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('::error title=Core gate::'+str(error).replace('%','%25').replace('\r','%0D').replace('\n','%0A'), flush=True)
        raise
