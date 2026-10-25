from pathlib import Path
import ast, hashlib, json, math
R = Path('/workspace/scratch')
OLD = R / 'mythic413-explicit-1536-or-2304-storage-proposal-20261020-v07'
OUT = R / 'mythic413-declared-physical-root-canonical-bridge-proposal-20261020-v09r02'
OUT.mkdir(exist_ok=False)
CORE = Path('/workspace/twilight/tools')
records = []

def sha(b):
    return hashlib.sha256(b).hexdigest()

def emit(name, source, replacements):
    original = source.read_text()
    proposed = original
    for old, new in replacements:
        assert proposed.count(old) == 1, (name, old[:100], proposed.count(old))
        proposed = proposed.replace(old, new, 1)
    inverse = proposed
    for old, new in reversed(replacements):
        assert inverse.count(new) == 1
        inverse = inverse.replace(new, old, 1)
    assert inverse == original
    ast.parse(proposed)
    dest = OUT / name
    dest.write_text(proposed)
    saved = OUT / 'originals' / name
    saved.parent.mkdir(exist_ok=True)
    saved.write_bytes(source.read_bytes())
    records.append(dict(source=str(source), source_sha256=sha(source.read_bytes()), proposed=str(dest), proposed_sha256=sha(dest.read_bytes()), exact_reverse_restores_original=True, replacements=[dict(old=a, new=b) for a, b in replacements]))
    return dest
helper = '\ndef declared_canonical_preflight_kwargs(canvas_review, layout_review, source_sha, direction, canvas):\n    """Optional exact declared-root seed; absent descriptors retain legacy kwargs."""\n    a = (canvas_review or {}).get("canonical_preflight")\n    b = (layout_review or {}).get("canonical_preflight")\n    if a != b:\n        raise ValueError("Canonical preflight must be identical in canvas and layout reviews")\n    if a is None:\n        return {}\n    required = {"status", "source_sha256", "packing_proof_sha256", "direction",\n                "canonical_canvas", "physical_canvases", "root_float", "root_integer",\n                "tile_size", "storage_translations", "atlas_origins", "source_anchors"}\n    if not isinstance(a, dict) or set(a) != required:\n        raise ValueError("Exact complete declared canonical preflight required")\n    if a["status"] != "REVIEWED_FIXED_RIG_CANONICAL_PREFLIGHT_V1" or canvas != 2048 or a["canonical_canvas"] != canvas:\n        raise ValueError("Declared bridge preserves canonical2048")\n    if a["source_sha256"] != source_sha or a["direction"] != direction or direction not in importer.DIRECTIONS:\n        raise ValueError("Declared preflight source/direction mismatch")\n    for field in ("source_sha256", "packing_proof_sha256"):\n        if not isinstance(a[field], str) or len(a[field]) != 64 or any(c not in "0123456789abcdef" for c in a[field]):\n            raise ValueError("Declared preflight exact SHA256 required")\n    pin = _digest(a)\n    if any((r or {}).get("canonical_preflight_sha256") != pin for r in (canvas_review, layout_review)):\n        raise ValueError("Declared canonical preflight pin mismatch")\n    sizes = a["physical_canvases"]\n    if not isinstance(sizes, list) or len(sizes) != 6 or any(type(v) is not int or not 256 <= v <= 4096 or v % 8 for v in sizes) or len(set(sizes)) != 1:\n        raise ValueError("Six identical declared physical body canvases required")\n    if (layout_review or {}).get("authored_pose_canvas_sizes") != sizes:\n        raise ValueError("Canonical bridge physical C differs from final authored C")\n    root = a["root_float"]\n    if not isinstance(root, list) or len(root) != 2 or any(type(v) not in (int,float) or not math.isfinite(v) for v in root):\n        raise ValueError("One finite declared root required")\n    rounded = [math.floor(v + .5) for v in root]\n    if not isinstance(a["root_integer"], list) or len(a["root_integer"]) != 2 or any(type(v) is not int for v in a["root_integer"]) or a["root_integer"] != rounded:\n        raise ValueError("Only one common declared-root rounding allowed")\n    tile = a["tile_size"]\n    if type(tile) is not int or tile not in (1536,2304):\n        raise ValueError("Unchanged explicit storage sizes required")\n    offsets = a["storage_translations"]\n    if not isinstance(offsets, list) or len(offsets) != 6 or any(not isinstance(v,list) or len(v) != 2 or any(type(x) is not int or x < 0 for x in v) for v in offsets):\n        raise ValueError("Explicit six storage-only translations required")\n    origins = [[tile*(i%2), tile*(i//2)] for i in range(6)]\n    if not isinstance(a["atlas_origins"], list) or len(a["atlas_origins"]) != 6 or any(not isinstance(v,list) or len(v) != 2 or any(type(x) is not int for x in v) for v in a["atlas_origins"]) or a["atlas_origins"] != origins:\n        raise ValueError("Fixed phase-grid tile origins required")\n    anchors = [[rounded[j]+offsets[i][j]+origins[i][j] for j in (0,1)] for i in range(6)]\n    if not isinstance(a["source_anchors"], list) or len(a["source_anchors"]) != 6 or any(not isinstance(v,list) or len(v) != 2 or any(type(x) is not int for x in v) for v in a["source_anchors"]) or a["source_anchors"] != anchors or (layout_review or {}).get("source_anchors") != anchors:\n        raise ValueError("Only declared root plus storage plus tile origin may seed canonical geometry")\n    return {"source_anchors": anchors}\n\n'
layout = emit('pr122_reviewed_runtime_layout.py', CORE / 'pr122_reviewed_runtime_layout.py', [('import json\n', 'import json\nimport math\n'), ('def _pose_identity(frame):', helper + 'def _pose_identity(frame):'), ('    sizes = _validated_authored_canvas_sizes(review, canvas)\n', '    sizes = _validated_authored_canvas_sizes(review, canvas)\n    canonical_kwargs = declared_canonical_preflight_kwargs(review, review, source_sha, direction, base_canvas[0])\n    if canonical_kwargs and canonical_kwargs["source_anchors"] != [f.get("source_anchor") for f in frames]:\n        raise ValueError("Declared canonical roots differ from exact base geometry")\n'), ('        canonical = importer.analyze(path, rows_count=6, reference_rows=[0, 3],\n                                     directions_axis="phase_grid2", canvas_size=base_canvas[0],\n                                     directions=[direction])', '        canonical = importer.analyze(path, rows_count=6, reference_rows=[0, 3],\n                                     directions_axis="phase_grid2", canvas_size=base_canvas[0],\n                                     directions=[direction], **canonical_kwargs)')])
bridge_create = "    canonical_preflight = dict(status='REVIEWED_FIXED_RIG_CANONICAL_PREFLIGHT_V1',\n        source_sha256=sha(raw), packing_proof_sha256=sha(packing_bytes), direction=direction,\n        canonical_canvas=2048, physical_canvases=[canvas]*6, root_float=root,\n        root_integer=root_integer, tile_size=tile,\n        storage_translations=[f['storage_translation'] for f in frames],\n        atlas_origins=[f['atlas_origin'] for f in frames], source_anchors=anchors)\n    canonical_pin = regions._digest(canonical_preflight)\n    canonical_seed_review = dict(canonical_preflight=canonical_preflight,\n        canonical_preflight_sha256=canonical_pin, authored_pose_canvas_sizes=[canvas]*6,\n        source_anchors=anchors)\n    canonical_kwargs = declared_canonical_preflight_kwargs(canonical_seed_review,\n        canonical_seed_review, sha(raw), direction, 2048)\n"
builder = emit('pr122-build-authored-clip-request-v07.py', OLD / 'pr122-build-authored-clip-request-v05.py', [('from pr122_reviewed_runtime_layout import apply_reviewed_layout', 'from pr122_reviewed_runtime_layout import apply_reviewed_layout, declared_canonical_preflight_kwargs'), ("    base = advance.staging.importer.analyze(atlas, rows_count=6, reference_rows=[0,3],\n        directions_axis='phase_grid2', canvas_size=2048, directions=[direction])", bridge_create + "    base = advance.staging.importer.analyze(atlas, rows_count=6, reference_rows=[0,3],\n        directions_axis='phase_grid2', canvas_size=2048, directions=[direction], **canonical_kwargs)"), ('        authored_pose_canvas_sizes=[canvas]*6,', '        authored_pose_canvas_sizes=[canvas]*6, canonical_preflight=canonical_preflight,\n        canonical_preflight_sha256=canonical_pin,'), ('source_sha256=sha(raw),\n            canvas_size=2048, review_basis=', 'source_sha256=sha(raw),\n            canonical_preflight=canonical_preflight, canonical_preflight_sha256=canonical_pin,\n            canvas_size=2048, review_basis=')])
advance = emit('advance_pr122_native_locomotion.py', CORE / 'advance_pr122_native_locomotion.py', [('from pr122_reviewed_source_regions import apply_reviewed_regions', 'from pr122_reviewed_source_regions import apply_reviewed_regions\nfrom pr122_reviewed_runtime_layout import declared_canonical_preflight_kwargs'), ("        result = staging.importer.analyze(dest, rows_count=6, reference_rows=[0, 3],\n                                         directions_axis='phase_grid2', canvas_size=canvas,\n                                         directions=[direction])", '        canonical_kwargs = declared_canonical_preflight_kwargs(canvas_review, request.get("reviewed_runtime_layout"), staging.digest(dest), direction, canvas)\n        if canonical_kwargs:\n            assert canvas_review["canonical_preflight"]["packing_proof_sha256"] == request.get("authored_packing_proof_sha256")\n        result = staging.importer.analyze(dest, rows_count=6, reference_rows=[0, 3],\n                                         directions_axis=\'phase_grid2\', canvas_size=canvas,\n                                         directions=[direction], **canonical_kwargs)')])
stage = emit('stage_pr122_native_locomotion.py', CORE / 'stage_pr122_native_locomotion.py', [("        geometry = importer.analyze(path, rows_count=6, reference_rows=[0, 3],\n                                    directions_axis='phase_grid2', canvas_size=canvas,\n                                    directions=[direction])", "        canonical_kwargs = reviewed_layout.declared_canonical_preflight_kwargs(\n            record.get('source_canvas_review'), manifest.get('reviewed_runtime_layouts', {}).get(source),\n            record['sha256'], direction, canvas)\n        geometry = importer.analyze(path, rows_count=6, reference_rows=[0, 3],\n                                    directions_axis='phase_grid2', canvas_size=canvas,\n                                    directions=[direction], **canonical_kwargs)")])
pins = json.loads((OLD / 'canonical-input-pins.json').read_text())
for p in (advance, stage, layout):
    pins['tool_pins'][p.name] = sha(p.read_bytes())
pinfile = OUT / 'canonical-input-pins.json'
pinfile.write_text(json.dumps(pins, ensure_ascii=False, indent=2) + '\n')
integrator = emit('integrate_new_413_clip_retaining_profile_v07.py', OLD / 'integrate_new_413_clip_retaining_profile_v06.py', [('from pr122_reviewed_runtime_layout import apply_reviewed_layout', 'from pr122_reviewed_runtime_layout import apply_reviewed_layout, declared_canonical_preflight_kwargs'), ("    geometry = advance.staging.importer.analyze(frozen_raw, rows_count=6, reference_rows=[0,3], directions_axis='phase_grid2', canvas_size=canvas, directions=[direction])", "    canonical_kwargs = declared_canonical_preflight_kwargs(canvas_review, request.get('reviewed_runtime_layout'), raw_sha, direction, canvas)\n    if canonical_kwargs:\n        require(canvas_review['canonical_preflight']['packing_proof_sha256'] == request.get('authored_packing_proof_sha256'), 'Exact declared canonical packing pin required')\n    geometry = advance.staging.importer.analyze(frozen_raw, rows_count=6, reference_rows=[0,3], directions_axis='phase_grid2', canvas_size=canvas, directions=[direction], **canonical_kwargs)"), ('391013146f0ed6a3328bd07d3c91db04f5efe2dbdba8965db91fd38ab9912db6', sha(pinfile.read_bytes()))])
tree = ast.parse(layout.read_text())
funcs = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in ('_digest', 'declared_canonical_preflight_kwargs')]

class ImporterStub:
    DIRECTIONS = ('S', 'SW', 'W', 'NW', 'N', 'NE', 'E', 'SE')
ns = dict(math=math, json=json, hashlib=hashlib, importer=ImporterStub)
exec(compile(ast.fix_missing_locations(ast.Module(body=funcs, type_ignores=[])), 'static-helper', 'exec'), ns)
helperfn = ns['declared_canonical_preflight_kwargs']
assert helperfn(None, None, 'not-used', 'E', 2048) == {}
P = R / 'mythic413-E-death-actual-packed-r001-20261020'
packing = json.loads((P / 'thunder_female-E-death-six-actual-poses-r001.packing.json').read_text())
plan = json.loads((P / 'packing-plan.json').read_text())
root = plan['rig_root_in_unpadded_frame']
rounded = [math.floor(x + 0.5) for x in root]
poses = packing['authored_poses']
tile = plan['tile_size'][0]
desc = dict(status='REVIEWED_FIXED_RIG_CANONICAL_PREFLIGHT_V1', source_sha256=packing['output_sha256'], packing_proof_sha256=sha((P / 'thunder_female-E-death-six-actual-poses-r001.packing.json').read_bytes()), direction='E', canonical_canvas=2048, physical_canvases=[packing['fixed_physical_canvas']] * 6, root_float=root, root_integer=rounded, tile_size=tile, storage_translations=[p['storage_translation'] for p in poses], atlas_origins=[p['atlas_origin'] for p in poses], source_anchors=[[rounded[j] + p['storage_translation'][j] + p['atlas_origin'][j] for j in (0, 1)] for p in poses])
review = dict(canonical_preflight=desc, canonical_preflight_sha256=ns['_digest'](desc), authored_pose_canvas_sizes=desc['physical_canvases'], source_anchors=desc['source_anchors'])
assert helperfn(review, review, desc['source_sha256'], 'E', 2048) == dict(source_anchors=desc['source_anchors'])
bad = json.loads(json.dumps(review))
bad['canonical_preflight']['source_anchors'][2][1] += 1
try:
    helperfn(bad, bad, desc['source_sha256'], 'E', 2048)
except ValueError:
    pass
else:
    raise AssertionError('tampered canonical pin accepted')
bad['canonical_preflight_sha256'] = ns['_digest'](bad['canonical_preflight'])
try:
    helperfn(bad, bad, desc['source_sha256'], 'E', 2048)
except ValueError:
    pass
else:
    raise AssertionError('per-pose anchor change accepted')
diag = json.loads((R / 'mythic413-nw-n-walk-independent-qc-20261020/Edeath-r001-independent-readonly-235-canonical-fit-diagnosis-v01.json').read_text())
numeric = []
for row, anchor in zip(diag['rows'], desc['source_anchors']):
    x, y, w, h = row['expanded']
    mx = 1024 - (anchor[0] - x)
    my = 1280 - (anchor[1] - y)
    assert min(mx, my, 2048 - mx - w, 2048 - my - h) >= 0
    numeric.append(dict(phase=row['phase'], nominal2048_declared_root_edges=[mx, my, 2048 - mx - w, 2048 - my - h]))
assert numeric[2]['nominal2048_declared_root_edges'][1] == 298
for record in records:
    assert sha(Path(record['source']).read_bytes()) == record['source_sha256']
example = OUT / 'Edeath-r001-declared-canonical-preflight-example.json'
example.write_text(json.dumps(review, indent=2) + '\n')
report = dict(status='UNEXECUTED_V09_OPTIONAL_DECLARED_ROOT_CANONICAL_PIN_BRIDGE_PROPOSAL', files=records, canonical_pins=dict(path=str(pinfile), sha256=sha(pinfile.read_bytes())), example=dict(path=str(example), sha256=sha(example.read_bytes())), static_checks=dict(all_AST_valid=True, all_exact_reverse_restore=True, legacy_absent_descriptor_kwargs_unchanged=True, tampered_pin_rejected=True, rehashed_perpose_anchor_change_rejected=True, Edeath_six_math_fits=numeric), unchanged=['import_original_based_motion.py', 'pr122_reviewed_source_regions.py', 'packer', 'nominal canonical2048', 'physical body C/root', 'region/ownership/alpha/RGBA/unique6 guards', 'profile literals', 'all existing tests and actual runtime files'], required_adoption_scope=['review and apply three core tool copies: runtime_layout, advance, stage', 'use matching new builder/integrator and canonical-input-pins together', 'persist identical descriptor+digest in canvas review and runtime layout review; recompute canonical geometry, region base hash, ownership pin, expanded geometry, layout review/proof and selected-source saved geometry consistently', 'run existing default tests unchanged plus scoped actual request/runtime validation before integration; not run in this prototype'], repository_changes=0, existing_scratch_changes=0, apply_or_pipeline_retry=0, images=0, actor_approvals_added=0)
reportfile = OUT / 'v09-declared-root-canonical-bridge-static-proposal-and-pin-audit-v01.json'
reportfile.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(dict(proposal_dir=str(OUT), report=str(reportfile), report_sha256=sha(reportfile.read_bytes()), core_files=3, builder_integrator_files=2, pins_sha256=sha(pinfile.read_bytes()), phase2_top_margin=298, images=0)))
