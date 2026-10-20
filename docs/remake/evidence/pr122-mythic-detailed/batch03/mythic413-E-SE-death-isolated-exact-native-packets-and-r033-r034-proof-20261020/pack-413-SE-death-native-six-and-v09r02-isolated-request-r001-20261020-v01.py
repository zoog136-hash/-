from pathlib import Path
import hashlib,json,sys,subprocess,importlib.util,runpy
R=Path('/workspace/twilight');S=Path('/workspace/scratch');P=S/'mythic413-declared-physical-root-canonical-bridge-proposal-20261020-v09r02';old=S/'mythic413-explicit-1536-or-2304-storage-proposal-20261020-v07'
source=S/'mythic413-SE-death-author-20261020-v01/actual-own-SE-DEATH-six-native-v08/own-SE-DEATH-six-actual-native-source-contract-v08.json';sh='a5ca0a93aa964ad161e1432a32a79397cdeaf00e3a59f4daf1558fdba00d62a8'
cert=S/'mythic413-nw-n-walk-independent-qc-20261020/SEdeath-v08-a5ca0a-independent-final-actual-source-held-cycle-PASS-v01.json'
assert hashlib.sha256(cert.read_bytes()).hexdigest()=='905c497089be67b3ff8724997b63b152f52f2b53250d624f79c7cb7b3c240262'
assert hashlib.sha256(source.read_bytes()).hexdigest()==sh;d=json.loads(source.read_text())
C=d['fixed_C'];assert C==2816;root=d['common_unpadded_root'];assert root==[723.7916666666666,1067.2150113422247]
assert d['storage_translation']==[256,256] and d['storage_canvas']==[2304,2304]
frames=[]
for i,e in enumerate(d['frames']):
 p=Path(e['path']);b=p.read_bytes();assert e['phase']==i and len(b)==e['bytes'] and hashlib.sha256(b).hexdigest()==e['sha256']
 frames.append(dict(phase=i,path=str(p),sha256=e['sha256'],storage_translation=[256,256]))
assert len(frames)==6
out=S/'mythic413-SE-death-actual-packed-r001-20261020';out.mkdir()
plan=out/'packing-plan.json';pb=(json.dumps(dict(schema='pr122-authored-six-pose-packing-v1',key='transform:413',role='death',direction='SE',root_basis='PINNED_RIG_ROOT_NOT_ALPHAFOOT',logical_canvas=1024,physical_canvas=int(C),rig_root_in_unpadded_frame=root,tile_size=[2304,2304],source_contract_sha256=sh,frames=frames),indent=2)+'\n').encode()
with plan.open('xb') as f:f.write(pb)
packer=old/'pr122-author-six-pose-atlas-v04.py';assert hashlib.sha256(packer.read_bytes()).hexdigest()=='297cf390779e3e60e65b242335dfab307c106dc421df3bb46250bc929ddc3938'
raw=out/'thunder_female-SE-death-six-actual-poses-r001.png'
with (out/'lossless-packing-v01.log').open('x') as log:r=subprocess.run(['python3','-B',str(packer),'--plan',str(plan),'--expected-plan-sha256',hashlib.sha256(pb).hexdigest(),'--output',str(raw)],stdout=log,stderr=subprocess.STDOUT)
assert r.returncode==0,'PACK_HOLD'
f=P/'v09r02-declared-canonical-bridge-unexecuted-proposal-frozen-allowlist-v01.json';assert hashlib.sha256(f.read_bytes()).hexdigest()=='db238a794e44c10ffcdd278e3df5323c04c7773a1717484f5c4e21da6afdffa6'
for e in json.loads(f.read_text())['files']:
 p=Path(e.get('path',e.get('source','')));b=p.read_bytes();assert len(b)==e['bytes'] and hashlib.sha256(b).hexdigest()==e['sha256']
original={n:hashlib.sha256((R/'tools'/n).read_bytes()).hexdigest() for n in ['pr122_reviewed_runtime_layout.py','stage_pr122_native_locomotion.py','advance_pr122_native_locomotion.py']}
sys.dont_write_bytecode=True;sys.path.insert(0,str(R/'tools'));loaded={}
for name in ['pr122_reviewed_runtime_layout','stage_pr122_native_locomotion','advance_pr122_native_locomotion']:
 p=P/(name+'.py');spec=importlib.util.spec_from_file_location(name,p);mod=importlib.util.module_from_spec(spec);sys.modules[name]=mod;spec.loader.exec_module(mod);loaded[name]=mod
assert loaded['advance_pr122_native_locomotion'].staging is loaded['stage_pr122_native_locomotion'] and loaded['stage_pr122_native_locomotion'].reviewed_layout is loaded['pr122_reviewed_runtime_layout']
assert loaded['pr122_reviewed_runtime_layout'].declared_canonical_preflight_kwargs(None,None,'unused','SE',2048)=={}
with (out/'isolated-three-copy-preload-provenance-v01.json').open('x') as w:json.dump(dict(status='EXACT_REVIEWED_THREE_COPY_ISOLATED_REQUEST_ONLY_NOT_GAME_ADOPTED',original_repository_tools=original,loaded_modules={n:dict(path=m.__file__,sha256=hashlib.sha256(Path(m.__file__).read_bytes()).hexdigest())for n,m in loaded.items()},actor_approvals_added=0),w,indent=2)
packing=raw.with_suffix('.packing.json');req=out/'request-SEdeathSixActualRig01.json';sys.argv=[str(P/'pr122-build-authored-clip-request-v07.py'),'--packing',str(packing),'--expected-packing-sha256',hashlib.sha256(packing.read_bytes()).hexdigest(),'--version','SEdeathSixActualRig01','--output',str(req)]
runpy.run_path(str(P/'pr122-build-authored-clip-request-v07.py'),run_name='__main__')
for n,h in original.items():assert hashlib.sha256((R/'tools'/n).read_bytes()).hexdigest()==h
print(json.dumps(dict(status='LOSSLESS_PACK_AND_ISOLATED_REQUEST_PASS_CORE_ADOPTION_PENDING',files=[dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size) for p in [req,raw,packing]],source_contract_sha256=sh,actor_approvals_added=0)))
