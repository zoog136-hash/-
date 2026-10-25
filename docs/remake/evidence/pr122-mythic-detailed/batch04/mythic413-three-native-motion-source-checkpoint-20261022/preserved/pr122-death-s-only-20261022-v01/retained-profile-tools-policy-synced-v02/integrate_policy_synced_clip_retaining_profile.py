"""Root-only proposal: add a missing 413 clip with the retained real profile.

No image generation/preview/network/CI. Default is read-only preflight. Explicit
--apply runs unchanged advance body except a named retained-profile compiler at
its one binder call, then unchanged checkpoint. Never adopts the same raw twice.
"""
from pathlib import Path
import argparse, ast, contextlib, copy, hashlib, json, math, os, re, subprocess, sys, tempfile

sys.dont_write_bytecode = True
ROOT = Path('/workspace/twilight')
HERE = Path(__file__).resolve().parent
KEY = 'transform:413'
BRANCH = 'feature/twilight-remaining106-20261016'
GODOT = Path('/workspace/scratch/godot472/Godot_v4.7.2-stable_linux.x86_64')
BASE = Path('docs/remake/evidence/pr122-mythic-detailed/batch04')
REG = Path('data/pr122_native_locomotion_staging.json')
MANIFEST = Path('docs/remake/evidence/pr122-mythic-detailed/batch01/source-manifest.json')

def require(value, message):
    if not value:
        raise ValueError(message)

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def finite(value):
    if isinstance(value, float):
        require(math.isfinite(value), 'Non-finite JSON float, including exponent overflow')
    elif isinstance(value, dict):
        require(all(isinstance(k,str) for k in value), 'JSON object member must be text')
        for child in value.values(): finite(child)
    elif isinstance(value, (list,tuple)):
        for child in value: finite(child)
    else:
        require(value is None or isinstance(value,(str,int,bool)), 'Not finite JSON metadata')
    return value

def strict_loads(data):
    def pairs(rows):
        result = {}
        for key, value in rows:
            require(key not in result, 'Duplicate JSON member')
            result[key] = value
        return result
    def bad(value):
        raise ValueError('Non-finite JSON number: '+value)
    return finite(json.loads(data, object_pairs_hook=pairs, parse_constant=bad))

def strict_json(path):
    return strict_loads(Path(path).read_bytes())

def encode(value):
    finite(value)
    return (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False)+'\n').encode()

def git(*args):
    result = subprocess.run(['git', *args], cwd=ROOT, capture_output=True)
    require(result.returncode == 0, 'Git read/guard failed: '+args[0])
    return result.stdout

def actual_file(path, external=False):
    path = Path(path).absolute()
    require(path.is_file() and not path.is_symlink(), 'Require existing regular file')
    require(path.resolve() == path, 'Require canonical file path, no symlink traversal')
    if external:
        require(not path.is_relative_to(ROOT), 'Author input must stay outside repository')
    return path

def repo_path(relative):
    relative = Path(relative)
    require(not relative.is_absolute() and '..' not in relative.parts and relative.parts, 'Safe repository relative path required')
    path = ROOT/relative
    for parent in (path,*path.parents):
        require(not parent.is_symlink(), 'Symlink output/parent forbidden')
        if parent == ROOT: break
    require(path.resolve().is_relative_to(ROOT.resolve()), 'Path escapes repository')
    return path

def require_absent(relative):
    path = repo_path(relative)
    require(not os.path.lexists(path), 'Output already physically exists: '+str(relative))
    require(not git('ls-files','--',Path(relative).as_posix()).strip(), 'Output already tracked, including sparse paths: '+str(relative))

def rewrite_path_writes(function, replacement):
    class Guard(ast.NodeTransformer):
        def __init__(self): self.count = 0
        def visit_Call(self,node):
            self.generic_visit(node)
            if isinstance(node.func,ast.Attribute) and node.func.attr == 'write_text':
                require(len(node.args) == 1 and not node.keywords,'Unexpected official write_text shape')
                self.count += 1
                return ast.copy_location(ast.Call(func=ast.Name(id=replacement,ctx=ast.Load()),args=[node.func.value,*node.args],keywords=[]),node)
            return node
    guard = Guard();function = guard.visit(function)
    return ast.fix_missing_locations(ast.Module(body=[function],type_ignores=[])),guard.count

def frame_contract(path):
    text = Path(path).read_text()
    textures = {key:value for value,key in re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]',text)}
    regions = {}
    for key,body in re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n(.*?)(?=\n\[)',text,re.S):
        texture = re.search(r'atlas = ExtResource\("([^"]+)"\)',body)[1]
        region = re.search(r'region = Rect2\(([^)]+)\)',body)[1]
        margin = re.search(r'margin = Rect2\(([^)]+)\)',body)[1]
        regions[key] = (textures[texture],region,margin,'filter_clip = true' in body)
    result = {}
    for frames,loop,name,speed in re.findall(r'\{"frames": \[(.*?)\], "loop": (true|false), "name": &"([^"]+)", "speed": ([\d.]+)\}',text,re.S):
        require(name not in result,'Duplicate animation name')
        poses = [(float(duration),regions[key]) for duration,key in re.findall(r'\{"duration": ([\d.]+), "texture": SubResource\("([^"]+)"\)\}',frames)]
        require(len(poses) == 6,'Exact existing six-pose contract required')
        result[name] = dict(loop=loop=='true',speed=float(speed),poses=poses)
    require(result,'Existing frame contract parse failed')
    return result

def run():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--request', type=Path, required=True)
    ap.add_argument('--generated', type=Path, required=True)
    ap.add_argument('--review', type=Path, required=True)
    ap.add_argument('--expected-head', required=True)
    ap.add_argument('--expected-review-sha256', required=True)
    ap.add_argument('--revision', required=True)
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    require(re.fullmatch(r'[0-9a-f]{40}', args.expected_head), 'Pin exact existing HEAD')
    require(re.fullmatch(r'r[0-9]{3,}', args.revision), 'Safe explicit revision')
    pins_path = actual_file(HERE/'canonical-input-pins.json')
    require(digest(pins_path) == '74e6307ffda56801cebf9e87f4e705dc8545d8d61d7414719708793e4dc8c5d3', 'Canonical proposal pins changed')
    pins = strict_json(pins_path)
    for name, sha in pins['tool_pins'].items():
        require(digest(ROOT/'tools'/name) == sha, 'Original tool changed: '+name)
    for name, sha in pins['scope_contract_pins'].items():
        require(digest(ROOT/name) == sha, 'User-scoped runtime contract changed: '+name)
    sys.path.insert(0, str(ROOT/'tools'))
    import advance_pr122_native_locomotion as advance
    import integrate_pr122_corrective_clip as corrective
    import recover_pr122_disjoint_action as recovery
    import pr122_native_production_approvals as approvals
    import pr122_transform_motion_scope as motion_scope
    from pr122_reviewed_runtime_layout import apply_reviewed_layout, declared_canonical_preflight_kwargs
    from pr122_reviewed_source_regions import apply_reviewed_regions
    require(git('branch','--show-current').decode().strip() == BRANCH, 'Exact existing PR122 branch required')
    require(git('rev-parse','HEAD').decode().strip() == args.expected_head, 'HEAD changed; preserve both worksets')
    require(not git('diff','--cached','--name-only').strip(), 'Preserve pre-existing index')
    require(not git('diff','--name-only').strip(), 'Preserve other tracked edits before root integration')
    require(recovery.next_revision(ROOT, KEY) == args.revision, 'Use next exclusive actor revision')
    candidate_folder = Path('assets/actors/eight_direction/native_locomotion_staging/thunder_female_413')/args.revision
    require_absent(candidate_folder)
    manifest, register = strict_json(ROOT/MANIFEST), strict_json(ROOT/REG)
    state = approvals.load_state(ROOT, manifest=manifest, register=register)
    require(state.completed_count == 2 and set(state.approved_keys) == {'transform:393','transform:267'}, 'Exact two approved actors must remain frozen')
    state.require_mutable(KEY, 'add a missing source for')
    before_actor = copy.deepcopy(register['actors'][KEY])
    before_tracks = {t['animation']: copy.deepcopy(t) for t in before_actor['tracks']}
    require(before_actor['native_track_count'] == len(before_tracks), 'Current actor track count differs')
    before_frame_contract = frame_contract(ROOT/before_actor['frames'][6:])
    require(before_frame_contract.keys() == before_tracks.keys(),'Current frames and track names differ')
    frozen_other_actors = {k:copy.deepcopy(v) for k,v in register['actors'].items() if k != KEY}
    canonical = pins['canonical_profile']
    canonical_profile = actual_file(ROOT/canonical['path']).read_bytes()
    require(digest(ROOT/canonical['path']) == canonical['sha256'], 'Original r010 profile changed')
    current_profile_path = actual_file(ROOT/before_actor['native_profile'].removeprefix('res://'))
    current_profile = current_profile_path.read_bytes()
    require(hashlib.sha256(current_profile).hexdigest() == before_actor['native_profile_sha256'], 'Current profile SHA differs')
    old_frames_line = ('frames_path = "'+before_actor['frames']+'"').encode()
    canonical_frames_line = ('frames_path = "'+canonical['frames_path']+'"').encode()
    require(current_profile.count(old_frames_line) == 1, 'Require unique current profile frames path')
    require(current_profile.replace(old_frames_line, canonical_frames_line) == canonical_profile, 'Existing actor physical/profile literals must match retained r010 exactly')
    require(before_actor['native_profile_basis'] == pins['canonical_profile_basis'], 'Existing profile basis changed; preserve and inspect')
    immutable = {REG.as_posix(): digest(ROOT/REG)}
    for path in ['data/catalog_v19.json','data/combat_animation_profiles.json',before_actor['frames'][6:],before_actor['native_profile'][6:],canonical['path']]:
        immutable[path] = digest(actual_file(ROOT/path))
    palette = 'data/pr122_palette_finish_20261019.json'
    if (ROOT/palette).exists() or git('ls-files','--',palette).strip():
        immutable[palette] = digest(actual_file(ROOT/palette))
    require(immutable['data/combat_animation_profiles.json'] == '22550e0dfc48a07bfb0b69793560ae1c0a9f5719e5aa786fc16e2ea4d2867910', 'Existing 1490/color profiles changed')
    for track in before_tracks.values():
        for path in [track['source'], track['texture'], str(Path(track['source']).with_suffix('.geometry.json'))]:
            immutable[path] = digest(actual_file(ROOT/path))
    request_path, raw, review_path = [actual_file(p, external=True) for p in (args.request,args.generated,args.review)]
    input_data = {str(p):p.read_bytes() for p in (request_path,raw,review_path)}
    request, review = strict_loads(input_data[str(request_path)]), strict_loads(input_data[str(review_path)])
    require(re.fullmatch(r'[0-9a-f]{64}',args.expected_review_sha256) and hashlib.sha256(input_data[str(review_path)]).hexdigest() == args.expected_review_sha256,'Caller-pinned independent review SHA differs')
    require(request.get('status') == 'REQUESTED_NOT_APPROVED' and not any(k.startswith('output_') for k in request), 'Require untouched source request')
    require(request.get('key') == KEY and request.get('role') in ('walk','run','idle','attack','hit','death') and request.get('direction') in ('S','SW','W','NW','N','NE','E','SE'), 'Only missing 413 dedicated native source')
    require(request.get('source_batch') == 'batch04' and re.fullmatch(r'[A-Za-z0-9_-]{1,48}', request.get('version','')), 'Explicit safe batch04 version')
    direction, role = request['direction'], request['role']
    slot = ':'.join([KEY,direction,role])
    selection_table = 'selected_locomotion_sheets' if role in ('walk','run') else 'selected_detailed_action_sheets'
    require(all(slot not in manifest.get(t, {}) for t in ('selected_locomotion_sheets','selected_detailed_action_sheets')), 'Selected clip exists: never remake')
    walk_required = motion_scope.requires_walk(ROOT, KEY)
    require(role != 'walk' or walk_required, 'User excludes new WALK production for Mythic and lower transformations')
    if role == 'run' and walk_required:
        require(':'.join([KEY,direction,'walk']) in manifest.get('selected_locomotion_sheets', {}), 'Run requires selected same-direction walk')
    require(review.get('source_visual_status') == 'PASS' and all(review.get(k) == request[k] for k in ('key','direction','role','version')), 'Exact source independent PASS required')
    require(review.get('request_sha256') == hashlib.sha256(input_data[str(request_path)]).hexdigest() and review.get('raw_sha256') == hashlib.sha256(input_data[str(raw)]).hexdigest() and review.get('raw_bytes') == len(input_data[str(raw)]), 'Review must bind exact snapshotted request/raw bytes')
    require(raw.suffix.lower() == '.png' and input_data[str(raw)][:8] == b'\x89PNG\r\n\x1a\n', 'Actual PNG required')
    require(not any(row.get('sha256') == review['raw_sha256'] for row in manifest.get('raw_images', [])), 'Already adopted raw: preserve and resume exact later stage')
    refs = request.get('references', [])
    require(refs and set(refs) == set(request.get('reference_sha256', {})), 'Reference SHA map required')
    for reference in refs:
        path = actual_file(reference)
        input_data.setdefault(str(path),path.read_bytes())
        require(hashlib.sha256(input_data[str(path)]).hexdigest() == request['reference_sha256'][reference], 'Reference changed')
    findings = {k:copy.deepcopy(review[k]) for k in ('visual_findings','visual_limitations') if k in review}
    require(findings.get('visual_findings') and all(isinstance(v,list) and all(isinstance(s,str) and s.strip() for s in v) for v in findings.values()), 'Nonempty text-only source findings required')
    require(len(encode(findings)) < 24000, 'Bounded source review required')
    canvas_review = request.get('source_canvas_review')
    require(isinstance(canvas_review,dict) and canvas_review.get('status') == 'REVIEWED_SOURCE_CANVAS_PROPOSAL' and canvas_review.get('source_sha256') == review['raw_sha256'], 'Exact reviewed source canvas required')
    canvas = canvas_review.get('canvas_size')
    require(type(canvas) is int and 64 <= canvas <= 2048 and canvas % 8 == 0 and str(canvas_review.get('review_basis','')).strip(), 'Valid physical source canvas required')
    input_pins = {p:hashlib.sha256(data).hexdigest() for p,data in input_data.items()}
    def check_inputs():
        for p,h in input_pins.items():
            require(digest(actual_file(p)) == h, 'Frozen author input changed: '+Path(p).name)
    check_inputs()
    txn = Path(tempfile.mkdtemp(prefix='twilight-413-frozen-input-'))
    frozen_raw = txn/'reviewed-source.png'
    with frozen_raw.open('xb') as handle: handle.write(input_data[str(raw)])
    frozen_raw.chmod(0o444)
    raw_sha = review['raw_sha256']
    require(digest(frozen_raw) == raw_sha, 'Frozen raw differs from independent review')
    canonical_kwargs = declared_canonical_preflight_kwargs(canvas_review, request.get('reviewed_runtime_layout'), raw_sha, direction, canvas)
    if canonical_kwargs:
        require(canvas_review['canonical_preflight']['packing_proof_sha256'] == request.get('authored_packing_proof_sha256'), 'Exact declared canonical packing pin required')
    geometry = advance.staging.importer.analyze(frozen_raw, rows_count=6, reference_rows=[0,3], directions_axis='phase_grid2', canvas_size=canvas, directions=[direction], **canonical_kwargs)
    region_review = request.get('source_region_review')
    if region_review is not None:
        geometry, _ = apply_reviewed_regions(frozen_raw, geometry, region_review)
    advance.staging.importer.require_complete_pose_regions(frozen_raw, geometry)
    require(geometry['distinct_pixel_frames'] == 6, 'Exactly six distinct source poses required')
    base_geometry = copy.deepcopy(geometry)
    finite(base_geometry)
    layout = request.get('reviewed_runtime_layout')
    if layout is not None:
        require(layout.get('source_sha256') == raw_sha, 'Runtime layout must bind exact original PNG')
        geometry, layout_proof = apply_reviewed_layout(frozen_raw, geometry, layout, source_region_review=region_review)
    finite(geometry)
    check_inputs()
    require(len(geometry['frames']) == 6, 'Exact six reviewed runtime poses required')
    name = advance.staging.ACTORS[KEY].rsplit('_',1)[0]
    source_rel = BASE/f'{name}-{direction}-{role}-{request["version"]}.png'
    require_absent(source_rel)
    sidecar_rel = source_rel.with_suffix('.geometry.json')
    require_absent(sidecar_rel)
    ordinal = 0
    tracked_requests = git('ls-files','--',(BASE/'request-*.json').as_posix()).decode().splitlines()
    for name_in_git in tracked_requests:
        match = re.fullmatch(r'request-([0-9]+)-.+\.json',Path(name_in_git).name)
        require(match is not None,'Unexpected sparse tracked request filename')
        ordinal = max(ordinal,int(match[1]))
        require(not name_in_git.endswith(f'-{name}-{direction}-{role}-{request["version"]}.json'),'Request version already tracked, including sparse paths')
    for path in (ROOT/BASE).glob('request-*.json'):
        match = re.fullmatch(r'request-([0-9]+)-.+\.json', path.name)
        require(match is not None, 'Unexpected existing request filename')
        ordinal = max(ordinal, int(match[1]))
        previous = strict_json(path)
        require(not all(previous.get(k) == request[k] for k in ('key','direction','role','version')), 'Request version already exists')
    destination = ROOT/BASE/f'request-{ordinal+1:03d}-{name}-{direction}-{role}-{request["version"]}.json'
    require(not destination.exists(), 'Never overwrite request')
    advance_path = ROOT/'tools/advance_pr122_native_locomotion.py'
    tree = ast.parse(advance_path.read_text())
    main = next(node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name == 'main')
    calls = [node for node in ast.walk(main) if isinstance(node,ast.Call) and isinstance(node.func,ast.Attribute) and isinstance(node.func.value,ast.Name) and node.func.value.id == 'binder' and node.func.attr == 'bind']
    require(len(calls) == 1, 'Require single reviewed binder call')
    require(ast.dump(calls[0]) == "Call(func=Attribute(value=Name(id='binder', ctx=Load()), attr='bind', ctx=Load()), args=[Name(id='root', ctx=Load()), Name(id='key', ctx=Load())], keywords=[])", 'Unexpected binder call shape')
    require_absent(destination.relative_to(ROOT))
    check_inputs()
    references_new = {}
    known = {row.get('sha256'):row.get('source') for row in manifest.get('raw_images',[])}
    copies = []
    for reference in refs:
        path = actual_file(reference)
        if path.is_relative_to(ROOT):
            continue
        sha = request['reference_sha256'][reference]
        if sha in known and (ROOT/known[sha]).is_file() and digest(ROOT/known[sha]) == sha:
            request.setdefault('available_repository_reference_sources',{})[sha] = known[sha]
            continue
        data = input_data[str(path)]
        require(len(data) <= 16*1024*1024 and data[:8] == b'\x89PNG\r\n\x1a\n','Bounded PNG authoring reference required')
        relative = BASE/'authoring-references'/('ref-'+sha+'.png')
        target = repo_path(relative)
        if os.path.lexists(target) or git('ls-files','--',relative.as_posix()).strip():
            require(target.is_file() and not target.is_symlink() and digest(target) == sha,'Existing authoring reference differs')
            require(git('ls-files','--',relative.as_posix()).decode().strip() == relative.as_posix(),'Preserve pre-existing untracked reference without claiming it')
            require(hashlib.sha256(git('show',':'+relative.as_posix())).hexdigest() == sha,'Existing reference index differs')
        else:
            require_absent(relative)
            references_new[relative.as_posix()] = data
        copies.append(dict(source=relative.as_posix(),sha256=sha,bytes=len(data),original_reference=reference))
    if copies:
        request['preserved_reference_files'] = copies
    findings.update(source_visual_status='PASS',raw_sha256=raw_sha,raw_bytes=len(input_data[str(raw)]),request_sha256=hashlib.sha256(input_data[str(request_path)]).hexdigest(),review_sha256=args.expected_review_sha256)
    request['private_source_review'] = findings
    request['frozen_author_inputs'] = dict(original_generated_file=str(raw),snapshot_generated_file=str(frozen_raw),sha256=input_pins)
    finite(request)
    frames_rel = candidate_folder/'SpriteFrames.tres'
    profile_rel = candidate_folder/'NativeMotionProfile.tres'
    texture_rel = candidate_folder/f'{direction}-{role}.png'
    for relative in (frames_rel,profile_rel,texture_rel): require_absent(relative)
    new_track = dict(direction=direction,role=role,animation=f'{role}_{advance.staging.importer.DIRECTIONS.index(direction)}',source=source_rel.as_posix(),source_sha256=raw_sha,texture=texture_rel.as_posix(),geometry=geometry)
    if layout is not None:
        new_track['runtime_layout_proof'] = layout_proof
    expected_tracks = sorted([*copy.deepcopy(list(before_tracks.values())),new_track],key=lambda row:KEY+':'+row['direction']+':'+row['role'])
    expected_frames = advance.staging.build_frames(expected_tracks)
    new_frames_path = 'res://'+frames_rel.as_posix()
    expected_profile = current_profile.replace(old_frames_line,('frames_path = "'+new_frames_path+'"').encode())
    require(expected_profile.replace(('frames_path = "'+new_frames_path+'"').encode(),canonical_frames_line) == canonical_profile,'Retained profile literals differ')
    static_bytes = {
        source_rel.as_posix():input_data[str(raw)],
        sidecar_rel.as_posix():encode(base_geometry),
        texture_rel.as_posix():input_data[str(raw)],
        frames_rel.as_posix():expected_frames,
        profile_rel.as_posix():expected_profile,
        **references_new,
    }
    static_sha = {p:hashlib.sha256(data).hexdigest() for p,data in static_bytes.items()}
    request_rel = destination.relative_to(ROOT).as_posix()
    resume_rel = 'docs/remake/TWILIGHT_PR122_RESUME_20261019.md'
    metadata = {REG.as_posix(),MANIFEST.as_posix(),resume_rel,request_rel}
    all_new = set(static_bytes)|{request_rel}
    allowed_changed = metadata|set(static_bytes)
    expected_changed = allowed_changed
    for relative in all_new: require_absent(relative)
    before_metadata = {p:repo_path(p).read_bytes() for p in metadata if p != request_rel}
    require(git('rev-parse','HEAD').decode().strip() == args.expected_head and not git('diff','--name-only').strip() and not git('diff','--cached','--name-only').strip(),'Concurrent HEAD/worktree/index changed before any repository write')
    require(all(digest(ROOT/p) == h for p,h in immutable.items()),'Concurrent protected input changed before writes')
    finite(request);finite(base_geometry);finite(geometry);check_inputs()
    if not args.apply:
        print(json.dumps(dict(status='READONLY_REPOSITORY_PREFLIGHT_READY_NOT_APPLIED',key=KEY,direction=direction,role=role,revision=args.revision,request_destination=request_rel,source_destination=source_rel.as_posix(),review_sha256=args.expected_review_sha256,raw_sha256=raw_sha,retained_profile_sha256=canonical['sha256'],existing_tracks_preserved=len(before_tracks),approved_count_preserved=2,source_pixels_resampled=False,produced_path_count=len(all_new),exact_revision_files=[texture_rel.name,frames_rel.name,profile_rel.name],frozen_input_snapshot=str(txn))))
        return

    log = txn/'integration.log'
    owner_sha = {p:hashlib.sha256(data).hexdigest() for p,data in before_metadata.items()}
    index_sha = {}
    phase = 'setup'
    commit_pins = None
    for relative,data in before_metadata.items():
        backup = txn/'originals'/relative
        backup.parent.mkdir(parents=True,exist_ok=True)
        with backup.open('xb') as handle: handle.write(data)
    def assert_index():
        staged = set(git('diff','--cached','--name-only').decode().splitlines())
        require(staged == set(index_sha),'Concurrent/unexpected staged paths; preserve index')
        require(all(hashlib.sha256(git('show',':'+p)).hexdigest() == h for p,h in index_sha.items()),'Concurrent staged bytes changed')
    def assert_scope():
        changed = set(git('diff','--name-only','HEAD').decode().splitlines())
        require(changed <= allowed_changed,'Unrelated tracked change; preserve before checkpoint')
        for relative,h in owner_sha.items():
            require(digest(actual_file(repo_path(relative))) == h,'Owned output or metadata changed: '+relative)
        for relative in all_new-set(owner_sha):
            require_absent(relative)
        folder = repo_path(candidate_folder)
        if os.path.lexists(folder):
            require(folder.is_dir() and not folder.is_symlink(),'Candidate directory changed type')
            actual = set()
            for child in folder.iterdir():
                require(child.is_file() and not child.is_symlink(),'Unexpected candidate subdirectory/symlink')
                actual.add(child.relative_to(ROOT).as_posix())
            require(actual <= {texture_rel.as_posix(),frames_rel.as_posix(),profile_rel.as_posix()},'Unexpected file in whole-directory checkpoint scope')
    def assert_frozen():
        require(all(digest(actual_file(ROOT/p)) == h for p,h in immutable.items() if p != REG.as_posix()),'Frozen prior asset/catalog/profile changed')
        current = strict_json(ROOT/REG)
        require({k:v for k,v in current['actors'].items() if k != KEY} == frozen_other_actors,'Another actor changed')
        state.assert_preserved(strict_json(ROOT/MANIFEST),current)
        current_tracks = {t['animation']:t for t in current['actors'][KEY]['tracks']}
        require(all(current_tracks.get(k) == v for k,v in before_tracks.items()),'Prior native track geometry/pixels changed')
        contract = frame_contract(ROOT/current['actors'][KEY]['frames'][6:])
        require(all(contract.get(k) == v for k,v in before_frame_contract.items()),'Prior playback texture/region/margin/duration/loop/speed changed')
    def boundary():
        check_inputs()
        require(digest(actual_file(frozen_raw)) == raw_sha,'Frozen review snapshot changed')
        require(git('branch','--show-current').decode().strip() == BRANCH,'Branch changed')
        require(git('rev-parse','HEAD').decode().strip() == args.expected_head,'HEAD changed before reviewed commit')
        assert_index();assert_scope();assert_frozen()
    def relative_path(path):
        path = Path(path)
        if not path.is_absolute(): path = ROOT/path
        relative = path.relative_to(ROOT).as_posix()
        require(repo_path(relative) == path,'Canonical output path required')
        return relative
    def create_static(path,data):
        relative = relative_path(path)
        boundary()
        require(relative in static_bytes and data == static_bytes[relative],'Unexpected output path/bytes')
        if relative in owner_sha:
            require(owner_sha[relative] == static_sha[relative],'Owned static output differs')
            return
        require_absent(relative)
        path = repo_path(relative)
        path.parent.mkdir(parents=True,exist_ok=True)
        require_absent(relative);check_inputs()
        with path.open('xb') as handle: handle.write(data)
        require(digest(path) == static_sha[relative],'Exclusive static output mismatch')
        owner_sha[relative] = static_sha[relative]
    def guarded_preserve_write(path,data):
        relative = relative_path(path)
        if relative in immutable and relative not in metadata:
            boundary()
            require(hashlib.sha256(data).hexdigest() == immutable[relative] and digest(ROOT/relative) == immutable[relative],'Prior immutable texture differs')
            return
        create_static(repo_path(relative),data)
    def write_text_guard(path,text):
        relative = relative_path(path)
        require(isinstance(text,str),'Official text writer shape changed')
        data = text.encode()
        if Path(relative).suffix == '.json': strict_loads(data)
        boundary()
        if relative in static_bytes:
            require(data == static_bytes[relative],'Reviewed sidecar output differs')
            create_static(repo_path(relative),data)
            return len(text)
        require(relative in metadata,'Unexpected metadata path')
        if relative == request_rel:
            candidate = strict_loads(data)
            require(candidate.get('key') == KEY and candidate.get('direction') == direction and candidate.get('role') == role and candidate.get('version') == request['version'],'Request identity changed')
            if 'output_sha256' in candidate:
                require(candidate['output_sha256'] == raw_sha and candidate['output_source'] == source_rel.as_posix() and candidate['output_bytes'] == len(input_data[str(raw)]),'Output request not bound to reviewed raw')
        if relative == REG.as_posix():
            candidate = strict_loads(data)
            require({k:v for k,v in candidate['actors'].items() if k != KEY} == frozen_other_actors,'Other actor metadata write forbidden')
            state.assert_preserved(strict_json(ROOT/MANIFEST),candidate)
        if relative == MANIFEST.as_posix():
            state.assert_preserved(strict_loads(data),strict_json(ROOT/REG))
        path = repo_path(relative)
        if relative not in owner_sha:
            require(relative == request_rel,'Unknown new metadata output')
            require_absent(relative);check_inputs()
            with path.open('xb') as handle: handle.write(data)
        else:
            require(digest(path) == owner_sha[relative],'Metadata changed before write')
            descriptor,temp_name = tempfile.mkstemp(prefix='.pr122-owned-',dir=str(path.parent))
            with os.fdopen(descriptor,'wb') as handle: handle.write(data)
            check_inputs()
            require(digest(path) == owner_sha[relative],'Metadata changed before atomic replacement')
            os.replace(temp_name,path)
        owner_sha[relative] = hashlib.sha256(data).hexdigest()
        require(digest(path) == owner_sha[relative],'Metadata write hash mismatch')
        return len(text)
    def guarded_write_json(path,value):
        finite(value)
        return write_text_guard(path,encode(value).decode())
    def check_adopted():
        boundary()
        require(digest(ROOT/source_rel) == raw_sha and digest(ROOT/sidecar_rel) == static_sha[sidecar_rel.as_posix()],'Adopted PNG/geometry no longer exact reviewed input')
        q = strict_json(destination)
        require(q.get('status') == 'GENERATED_GEOMETRY_PASS_NOT_APPROVED' and q.get('output_source') == source_rel.as_posix() and q.get('output_sha256') == raw_sha and q.get('output_bytes') == len(input_data[str(raw)]) and q.get('original_generated_file') == str(frozen_raw),'Actual adoption is not bound to reviewed raw snapshot')
        current_manifest = strict_json(ROOT/MANIFEST)
        records = [row for row in current_manifest['raw_images'] if row.get('source') == source_rel.as_posix()]
        require(len(records) == 1 and records[0]['sha256'] == raw_sha and records[0]['bytes'] == len(input_data[str(raw)]),'Manifest source binding differs')
        require(current_manifest[selection_table].get(slot) == source_rel.as_posix(),'Selected missing slot binding differs')
    def check_produced():
        check_adopted()
        current = strict_json(ROOT/REG)
        actor = current['actors'][KEY]
        actual_tracks = {t['animation']:t for t in actor['tracks']}
        require(actual_tracks.get(new_track['animation']) == new_track,'Integrated geometry/texture/raw binding differs from exact reviewed proposal')
        require(actor['native_track_count'] == len(before_tracks)+1 and actor['native_pose_count'] == (len(before_tracks)+1)*6,'Exactly one added clip required')
        require(actor['frames'] == new_frames_path and actor['frames_sha256'] == static_sha[frames_rel.as_posix()],'Frames binding differs')
        require(actor['native_profile'] == 'res://'+profile_rel.as_posix() and actor['native_profile_sha256'] == static_sha[profile_rel.as_posix()],'Retained profile binding differs')
        require(actor['native_profile_basis'] == before_actor['native_profile_basis'],'Old physical profile basis changed')
        require(digest(ROOT/texture_rel) == raw_sha,'Compiled texture differs from independently reviewed original PNG')
        require({p.name for p in (ROOT/candidate_folder).iterdir()} == {texture_rel.name,frames_rel.name,profile_rel.name},'Candidate directory must contain exactly new PNG and two TRES')
        require(all(digest(ROOT/p) == h for p,h in static_sha.items()),'Produced exact file pin differs')
    source_stage_set = {source_rel.as_posix(),sidecar_rel.as_posix(),MANIFEST.as_posix(),request_rel}
    def final_commit_guard():
        boundary();check_produced()
        require(set(index_sha) == expected_changed,'Unexpected final staged path set')
        require(set(git('diff','--name-only','HEAD').decode().splitlines()) == expected_changed,'Changed path set differs from exact plan')
        require(not git('diff','--name-only').strip(),'Unstaged tracked edits before commit')
        require(set(owner_sha) == expected_changed,'Not all and only planned outputs are owned')
        require(all(owner_sha[p] == index_sha[p] for p in expected_changed),'Staged bytes differ from produced/metadata pin')
    class ProcessProxy:
        DEVNULL = subprocess.DEVNULL
        STDOUT = subprocess.STDOUT
        PIPE = subprocess.PIPE
        def __init__(self,scope): self.scope = scope
        def check_output(self,argv,*a,**kw):
            require(argv[0] == 'git' or (argv[0] == str(GODOT) and argv[1:] == ['--version']),'Unexpected official read command')
            if argv[0] == 'git': require(argv[1] in ('branch','rev-parse','diff'),'Unexpected Git read')
            return subprocess.check_output(argv,*a,**kw)
        def run(self,argv,*a,**kw):
            nonlocal phase,index_sha,commit_pins
            boundary()
            if argv[0] == 'git' and argv[1] == 'add':
                require(argv[2:4] == ['--sparse','--'],'Unexpected Git add shape')
                names = argv[4:]
                if self.scope == 'advance':
                    require(phase == 'adopt' and not index_sha and set(names) == source_stage_set and len(names) == 4,'Fresh exact source index required')
                    check_adopted()
                    result = subprocess.run(argv,*a,**kw)
                    require(result.returncode == 0,'Original source add failed; preserve partial index')
                    index_sha = {p:owner_sha[p] for p in source_stage_set}
                    assert_index();phase = 'stage'
                    return result
                require(self.scope == 'checkpoint' and phase == 'checkpoint','Unexpected checkpoint index phase')
                check_produced()
                expected_names = {source_rel.as_posix(),sidecar_rel.as_posix(),request_rel,MANIFEST.as_posix(),REG.as_posix(),resume_rel,'tools/checkpoint_pr122_native_clip.py',candidate_folder.as_posix(),*[row['source'] for row in copies]}
                require(set(names) == expected_names and len(names) == len(expected_names),'Official checkpoint names differ from exact plan')
                require(set(index_sha) == source_stage_set,'Concurrent staged data before directory add')
                require(set(owner_sha) == expected_changed,'Unexpected/missing file before directory add')
                result = subprocess.run(argv,*a,**kw)
                require(result.returncode == 0,'Checkpoint add failed; preserve index')
                index_sha = {p:owner_sha[p] for p in expected_changed}
                final_commit_guard()
                return result
            if argv[0] == 'git' and argv[1] == 'commit':
                require(self.scope == 'checkpoint' and argv[2] == '-m' and len(argv) == 4 and '[skip ci]' in argv[3],'Exact original skip-CI local commit required')
                final_commit_guard();commit_pins = dict(index_sha)
                return subprocess.run(argv,*a,**kw)
            if argv[0] == 'git':
                require(argv[1] in ('ls-files','diff'),'Unexpected Git mutation/network command forbidden')
            else:
                require(self.scope == 'advance' and argv[0] == str(GODOT) and '--script' in argv and argv[-1] in ('tests/pr122_native_locomotion_resource_test.gd','tests/pr122_native_player_connection_test.gd','tests/pr122_native_action_test.gd'),'Only unchanged scoped actual Godot test allowed')
                check_produced()
            return subprocess.run(argv,*a,**kw)
    def clone_function(module,name,replacement,scope):
        module_tree = ast.parse(Path(module.__file__).read_text())
        function = next(node for node in module_tree.body if isinstance(node,ast.FunctionDef) and node.name == name)
        patched,count = rewrite_path_writes(function,replacement)
        require(count == (1 if name == 'stage' else 2),'Official metadata write count changed')
        namespace = dict(vars(module),write_text_guard=write_text_guard,preserve_write=guarded_preserve_write,subprocess=ProcessProxy(scope))
        exec(compile(patched,str(module.__file__),'exec'),namespace)
        return namespace[name]
    original_stage = clone_function(advance.staging,'stage','write_text_guard','stage')
    def guarded_stage(root,key,revision=None):
        require(root == ROOT and key == KEY and revision == args.revision,'Exact stage identity required')
        boundary();check_adopted()
        require(phase == 'stage' and set(index_sha) == source_stage_set,'Require fresh exact source index at stage boundary')
        require_absent(candidate_folder)
        original_stage(root,key,revision)
        boundary()
        current = strict_json(ROOT/REG)['actors'][KEY]
        require(current['tracks'] == expected_tracks and current['frames_sha256'] == static_sha[frames_rel.as_posix()],'Actual stage geometry/source/playback binding differs')
    def bind_retained_profile(root,key):
        require(root == ROOT and key == KEY,'Retained compiler limited to this actor')
        boundary()
        current = strict_json(ROOT/REG)
        actor = current['actors'][KEY]
        require(actor['tracks'] == expected_tracks and actor['frames'] == new_frames_path,'Require exact staged tracks before retained clone')
        guarded_preserve_write(ROOT/profile_rel,expected_profile)
        actor['native_profile'] = 'res://'+profile_rel.as_posix()
        actor['native_profile_sha256'] = static_sha[profile_rel.as_posix()]
        actor['native_profile_basis'] = copy.deepcopy(before_actor['native_profile_basis'])
        actor['retained_native_profile_source'] = dict(path=canonical['path'],sha256=canonical['sha256'],literal_changes=['frames_path'],reference_height_remeasured=False,source_pixels_resampled=False)
        guarded_write_json(ROOT/REG,current)
        check_produced()
    with log.open('x') as stream,contextlib.redirect_stdout(stream),contextlib.redirect_stderr(stream):
        boundary()
        for relative,data in references_new.items(): create_static(ROOT/relative,data)
        write_text_guard(destination,encode(request).decode())
        if layout is not None:
            current_manifest = strict_json(ROOT/MANIFEST)
            require(source_rel.as_posix() not in current_manifest.get('reviewed_runtime_layouts',{}),'Runtime layout already registered')
            current_manifest.setdefault('reviewed_runtime_layouts',{})[source_rel.as_posix()] = layout
            guarded_write_json(ROOT/MANIFEST,current_manifest)
        boundary()
        phase = 'adopt'
        advance.write_json = guarded_write_json
        advance.staging.preserve_write = guarded_preserve_write
        advance.staging.stage = guarded_stage
        calls[0].func = ast.Name(id='bind_retained_profile',ctx=ast.Load())
        patched = ast.fix_missing_locations(ast.Module(body=[main],type_ignores=[]))
        namespace = dict(vars(advance),bind_retained_profile=bind_retained_profile,write_json=guarded_write_json,subprocess=ProcessProxy('advance'))
        exec(compile(patched,str(advance_path),'exec'),namespace)
        argv = sys.argv
        try:
            sys.argv = [str(advance_path),'--request',str(destination),'--generated',str(frozen_raw),'--revision',args.revision,'--godot',str(GODOT)]
            namespace['main']()
        finally:
            sys.argv = argv
        check_produced()
        require(set(index_sha) == source_stage_set,'Unexpected index after scoped tests')
        state_after = approvals.load_state(ROOT)
        require(state_after.completed_count == 2 and set(state_after.approved_keys) == {'transform:393','transform:267'},'Frozen completed count changed')
        boundary();phase = 'checkpoint'
        import checkpoint_pr122_native_clip as checkpoint
        checkpoint_main = clone_function(checkpoint,'main','write_text_guard','checkpoint')
        try:
            sys.argv = [str(ROOT/'tools/checkpoint_pr122_native_clip.py'),'--request',request_rel,'--local-only']
            checkpoint_main()
        finally:
            sys.argv = argv
    require(commit_pins is not None,'No reviewed checkpoint commit executed')
    head = git('rev-parse','HEAD').decode().strip()
    require(git('rev-parse','HEAD^').decode().strip() == args.expected_head and git('branch','--show-current').decode().strip() == BRANCH,'Unexpected commit parent/branch')
    committed = set(git('diff-tree','--no-commit-id','--name-only','-r',head).decode().splitlines())
    require(committed == expected_changed == set(commit_pins),'Exact committed path set differs')
    require(all(hashlib.sha256(git('show',head+':'+p)).hexdigest() == h for p,h in commit_pins.items()),'Committed SHA differs from guarded stage')
    require(not git('diff','--cached','--name-only').strip() and not git('diff','--name-only').strip(),'Preserve unexpected remaining index/worktree edits')
    check_inputs();assert_frozen()
    final_state = approvals.load_state(ROOT)
    require(final_state.completed_count == 2 and set(final_state.approved_keys) == {'transform:393','transform:267'},'Postcommit approved count changed')
    report = dict(status='LOCAL_EXACT_COMMITTED_NOT_PUSHED',head=head,key=KEY,direction=direction,role=role,added_clips=1,added_poses=6,approved_count=2,retained_profile_literals=True,raw_sha256=raw_sha,review_sha256=args.expected_review_sha256,committed_path_count=len(committed),request=request_rel,log=str(log),preservation_snapshot=str(txn))
    (txn/'completed.json').write_bytes(encode(report))
    print(json.dumps(report))

if __name__ == '__main__':
    try:
        run()
    except Exception as exc:
        print(json.dumps(dict(status='STOP_PRESERVED_NO_RESET_NO_RETRY',error=str(exc)[:500])))
        raise
