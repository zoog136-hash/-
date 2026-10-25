from pathlib import Path
import hashlib,json,sys,importlib.util,runpy
R=Path('/workspace/twilight');S=Path('/workspace/scratch');P=S/'mythic413-declared-physical-root-canonical-bridge-proposal-20261020-v09r02'
f=P/'v09r02-declared-canonical-bridge-unexecuted-proposal-frozen-allowlist-v01.json'
assert hashlib.sha256(f.read_bytes()).hexdigest()=='db238a794e44c10ffcdd278e3df5323c04c7773a1717484f5c4e21da6afdffa6'
d=json.loads(f.read_text());pins={}
for e in d['files']:
 p=Path(e.get('path',e.get('source','')));b=p.read_bytes();assert len(b)==e['bytes'] and hashlib.sha256(b).hexdigest()==e['sha256'];pins[p.name]=e['sha256']
audit=S/'mythic413-nw-n-walk-independent-qc-20261020/v09r02-declared-canonical-bridge-independent-readonly-code-audit-v01.json'
assert hashlib.sha256(audit.read_bytes()).hexdigest()=='8bd4f1d3d741e8668c0b5589585874ed552a57eafdcd6c5785668a75b4bf584c'
original={n:hashlib.sha256((R/'tools'/n).read_bytes()).hexdigest() for n in ['pr122_reviewed_runtime_layout.py','stage_pr122_native_locomotion.py','advance_pr122_native_locomotion.py']}
sys.dont_write_bytecode=True;sys.path.insert(0,str(R/'tools'))
loaded={}
for name in ['pr122_reviewed_runtime_layout','stage_pr122_native_locomotion','advance_pr122_native_locomotion']:
 p=P/(name+'.py');spec=importlib.util.spec_from_file_location(name,p);mod=importlib.util.module_from_spec(spec);sys.modules[name]=mod;spec.loader.exec_module(mod);loaded[name]=mod
assert loaded['advance_pr122_native_locomotion'].staging is loaded['stage_pr122_native_locomotion']
assert loaded['stage_pr122_native_locomotion'].reviewed_layout is loaded['pr122_reviewed_runtime_layout']
layout=loaded['pr122_reviewed_runtime_layout']
assert layout.declared_canonical_preflight_kwargs(None,None,'unused','E',2048)=={}
sample=json.loads((P/'Edeath-r001-declared-canonical-preflight-example.json').read_text())
rawsha='6e57a8caa9210a46b08a2c4cb1bba2d9e2ec1e08504c58609ab35d8454f4b827'
kwargs=layout.declared_canonical_preflight_kwargs(sample,sample,rawsha,'E',2048)
assert kwargs['source_anchors']==sample['source_anchors']
out=S/'mythic413-E-death-declared-canonical-request-r002-20261020';out.mkdir()
meta=dict(status='ISOLATED_EXACT_THREE_COPY_PRELOAD_BUILDER_ONLY_NO_REPO_WRITES',original_repository_tools=original,loaded_modules={n:dict(path=m.__file__,sha256=hashlib.sha256(Path(m.__file__).read_bytes()).hexdigest())for n,m in loaded.items()},legacy_absent_seed_kwargs_unchanged=True,expected_request='request-EdeathSixActualRig02.json',actor_approvals_added=0)
with (out/'isolated-three-copy-preload-provenance-v01.json').open('x') as w:json.dump(meta,w,indent=2)
packing=S/'mythic413-E-death-actual-packed-r001-20261020/thunder_female-E-death-six-actual-poses-r001.packing.json'
req=out/'request-EdeathSixActualRig02.json';sys.argv=[str(P/'pr122-build-authored-clip-request-v07.py'),'--packing',str(packing),'--expected-packing-sha256',hashlib.sha256(packing.read_bytes()).hexdigest(),'--version','EdeathSixActualRig02','--output',str(req)]
runpy.run_path(str(P/'pr122-build-authored-clip-request-v07.py'),run_name='__main__')
for n,h in original.items():assert hashlib.sha256((R/'tools'/n).read_bytes()).hexdigest()==h
print(json.dumps(dict(status='ISOLATED_BUILDER_PASS_REPO_CORE_UNCHANGED_NOT_GAME_ADOPTED',request=str(req),request_sha256=hashlib.sha256(req.read_bytes()).hexdigest(),request_bytes=req.stat().st_size,raw_sha256=rawsha,loaded_three_exact_reviewed_copies=True)))
